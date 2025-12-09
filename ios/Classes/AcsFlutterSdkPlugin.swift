import AVFoundation
import Flutter
import UIKit
import AzureCommunicationCommon
import AzureCommunicationCalling
import AzureCommunicationChat

public class AcsFlutterSdkPlugin: NSObject, FlutterPlugin, CallDelegate, RemoteParticipantDelegate, CallAgentDelegate {
    private var channel: FlutterMethodChannel?

    private let callClient = CallClient()
    private let viewManager = VideoViewManager()
    private let remoteVideoRegistry = RemoteVideoRegistry()

    private var tokenCredential: CommunicationTokenCredential?
    private var callAgent: CallAgent?
    private var deviceManager: DeviceManager?
    private var call: Call?
    private var localVideoStream: LocalVideoStream?
    private var currentCamera: VideoDeviceInfo?
    private var incomingCall: IncomingCall?

    private var chatClient: ChatClient?
    private var chatThreadClient: ChatThreadClient?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "acs_flutter_sdk", binaryMessenger: registrar.messenger())
        let instance = AcsFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(AcsVideoViewFactory(viewManager: instance.viewManager), withId: "acs_video_view")
        instance.channel = channel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "getPlatformVersion":
            result("iOS \(UIDevice.current.systemVersion)")

        case "initializeIdentity":
            initializeIdentity(args: args, result: result)

        case "initializeCalling":
            initializeCalling(args: args, result: result)
        case "requestPermissions":
            requestPermissions(result: result)
        case "startCall":
            startCall(args: args, result: result)
        case "joinCall":
            joinCall(args: args, result: result)
        case "endCall":
            endCall(result: result)
        case "muteAudio":
            muteAudio(result: result)
        case "unmuteAudio":
            unmuteAudio(result: result)
        case "startVideo":
            startVideo(result: result)
        case "stopVideo":
            stopVideo(result: result)
        case "switchCamera":
            switchCamera(result: result)
        case "joinTeamsMeeting":
            joinTeamsMeeting(args: args, result: result)
        case "addParticipants":
            addParticipants(args: args, result: result)
        case "removeParticipants":
            removeParticipants(args: args, result: result)

        case "createUser", "getToken", "revokeToken":
            result(FlutterError(
                code: "NOT_IMPLEMENTED",
                message: "Identity management should be implemented on your backend.",
                details: nil
            ))

        case "initializeChat":
            initializeChat(args: args, result: result)
        case "createChatThread":
            createChatThread(args: args, result: result)
        case "joinChatThread":
            joinChatThread(args: args, result: result)
        case "sendMessage":
            sendMessage(args: args, result: result)
        case "getMessages":
            getMessages(args: args, result: result)
        case "sendTypingNotification":
            sendTypingNotification(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Identity

    private func initializeIdentity(args: [String: Any], result: FlutterResult) {
        guard let connection = args["connectionString"] as? String, !connection.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Connection string is required", details: nil))
            return
        }
        result(["status": "initialized"])
    }

    // MARK: - Calling

    private func initializeCalling(args: [String: Any], result: @escaping FlutterResult) {
        guard let accessToken = args["accessToken"] as? String, !accessToken.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Access token is required", details: nil))
            return
        }

        do {
            tokenCredential = try CommunicationTokenCredential(token: accessToken)
        } catch {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
            return
        }

        callClient.createCallAgent(userCredential: tokenCredential!, completionHandler: { [weak self] agent, error in
            guard let self = self else { return }
            if let error = error {
                result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
                return
            }

            self.callAgent = agent
            self.callAgent?.delegate = self
            self.callClient.getDeviceManager(completionHandler: { manager, _ in
                if let manager = manager {
                    self.deviceManager = manager
                }
                result(["status": "initialized"])
            })
        })
    }

    private func requestPermissions(result: @escaping FlutterResult) {
        let group = DispatchGroup()
        var cameraGranted = false
        var audioGranted = false

        group.enter()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            cameraGranted = granted
            group.leave()
        }

        group.enter()
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            audioGranted = granted
            group.leave()
        }

        group.notify(queue: .main) {
            result(cameraGranted && audioGranted)
        }
    }

    private func startCall(args: [String: Any], result: @escaping FlutterResult) {
        guard let participants = args["participants"] as? [String], !participants.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Participants list is required", details: nil))
            return
        }
        guard let agent = callAgent else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call agent not initialized", details: nil))
            return
        }

        let withVideo = args["withVideo"] as? Bool ?? false

        let callees = participants.map { CommunicationUserIdentifier($0) }

        let beginCall: (LocalVideoStream?) -> Void = { stream in
            let options = StartCallOptions()
            if let stream = stream {
                options.videoOptions = VideoOptions(localVideoStreams: [stream])
            }

            agent.startCall(participants: callees, options: options, completionHandler: { call, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(code: "CALL_START_FAILED", message: error.localizedDescription, details: nil))
                        return
                    }
                    guard let call = call else {
                        result(FlutterError(code: "CALL_START_FAILED", message: "Failed to start call", details: nil))
                        return
                    }
                    self.attachCall(call)
                    result(["id": call.id, "state": self.callStateToString(call.state)])
                }
            })
        }

        if withVideo {
            ensureLocalVideoStream { stream, error in
                if let error = error {
                    result(FlutterError(code: "VIDEO_UNAVAILABLE", message: error.localizedDescription, details: nil))
                    return
                }
                guard let stream = stream else {
                    result(FlutterError(code: "VIDEO_UNAVAILABLE", message: "Unable to access camera", details: nil))
                    return
                }
                DispatchQueue.main.async {
                    do {
                        try self.viewManager.showLocalPreview(stream: stream)
                    } catch {
                        result(FlutterError(code: "VIDEO_START_FAILED", message: error.localizedDescription, details: nil))
                        return
                    }
                    beginCall(stream)
                }
            }
        } else {
            beginCall(nil)
        }
    }

    private func joinCall(args: [String: Any], result: @escaping FlutterResult) {
        guard let groupIdString = args["groupCallId"] as? String,
              let uuid = UUID(uuidString: groupIdString) else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Valid group call ID is required", details: nil))
            return
        }
        guard let agent = callAgent else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call agent not initialized", details: nil))
            return
        }

        let withVideo = args["withVideo"] as? Bool ?? false

        let locator = GroupCallLocator(groupId: uuid)

        let beginJoin: (LocalVideoStream?) -> Void = { stream in
            let options = JoinCallOptions()
            if let stream = stream {
                options.videoOptions = VideoOptions(localVideoStreams: [stream])
            }

            agent.join(with: locator, joinCallOptions: options, completionHandler: { call, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(code: "CALL_JOIN_FAILED", message: error.localizedDescription, details: nil))
                        return
                    }
                    guard let call = call else {
                        result(FlutterError(code: "CALL_JOIN_FAILED", message: "Failed to join call", details: nil))
                        return
                    }
                    self.attachCall(call)
                    result(["id": call.id, "state": self.callStateToString(call.state)])
                }
            })
        }

        if withVideo {
            ensureLocalVideoStream { stream, error in
                if let error = error {
                    result(FlutterError(code: "VIDEO_UNAVAILABLE", message: error.localizedDescription, details: nil))
                    return
                }
                guard let stream = stream else {
                    result(FlutterError(code: "VIDEO_UNAVAILABLE", message: "Unable to access camera", details: nil))
                    return
                }
                DispatchQueue.main.async {
                    do {
                        try self.viewManager.showLocalPreview(stream: stream)
                    } catch {
                        result(FlutterError(code: "VIDEO_START_FAILED", message: error.localizedDescription, details: nil))
                        return
                    }
                    beginJoin(stream)
                }
            }
        } else {
            beginJoin(nil)
        }
    }

    private func joinTeamsMeeting(args: [String: Any], result: @escaping FlutterResult) {
        guard let meetingLink = args["meetingLink"] as? String, !meetingLink.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Valid Teams meeting link is required", details: nil))
            return
        }
        guard let agent = callAgent else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call agent not initialized", details: nil))
            return
        }

        let withVideo = args["withVideo"] as? Bool ?? false
        let locator = TeamsMeetingLinkLocator(meetingLink: meetingLink)

        let beginJoin: (LocalVideoStream?) -> Void = { stream in
            let options = JoinCallOptions()
            if let stream = stream {
                options.videoOptions = VideoOptions(localVideoStreams: [stream])
            }

            agent.join(with: locator, joinCallOptions: options, completionHandler: { call, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(code: "CALL_JOIN_FAILED", message: error.localizedDescription, details: nil))
                        return
                    }
                    guard let call = call else {
                        result(FlutterError(code: "CALL_JOIN_FAILED", message: "Failed to join call", details: nil))
                        return
                    }
                    self.attachCall(call)
                    result(["id": call.id, "state": self.callStateToString(call.state)])
                }
            })
        }

        if withVideo {
            ensureLocalVideoStream { stream, error in
                if let error = error {
                    result(FlutterError(code: "VIDEO_UNAVAILABLE", message: error.localizedDescription, details: nil))
                    return
                }
                guard let stream = stream else {
                    result(FlutterError(code: "VIDEO_UNAVAILABLE", message: "Unable to access camera", details: nil))
                    return
                }
                DispatchQueue.main.async {
                    do {
                        try self.viewManager.showLocalPreview(stream: stream)
                    } catch {
                        result(FlutterError(code: "VIDEO_START_FAILED", message: error.localizedDescription, details: nil))
                        return
                    }
                    beginJoin(stream)
                }
            }
        } else {
            beginJoin(nil)
        }
    }

    private func endCall(result: @escaping FlutterResult) {
        guard let activeCall = call else {
            result(FlutterError(code: "NO_ACTIVE_CALL", message: "No active call to end", details: nil))
            return
        }

        activeCall.hangUp(options: HangUpOptions(), completionHandler: { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "HANGUP_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    self?.cleanupCallResources()
                    result(nil)
                }
            }
        })
    }

    private func muteAudio(result: @escaping FlutterResult) {
        guard let activeCall = call else {
            result(FlutterError(code: "NO_ACTIVE_CALL", message: "No active call", details: nil))
            return
        }

        activeCall.muteOutgoingAudio(completionHandler: { error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "MUTE_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    result(nil)
                }
            }
        })
    }

    private func unmuteAudio(result: @escaping FlutterResult) {
        guard let activeCall = call else {
            result(FlutterError(code: "NO_ACTIVE_CALL", message: "No active call", details: nil))
            return
        }

        activeCall.unmuteOutgoingAudio(completionHandler: { error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "UNMUTE_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    result(nil)
                }
            }
        })
    }

    private func startVideo(result: @escaping FlutterResult) {
        ensureLocalVideoStream { stream, error in
            if let error = error {
                result(FlutterError(code: "VIDEO_START_FAILED", message: error.localizedDescription, details: nil))
                return
            }
            guard let stream = stream else {
                result(FlutterError(code: "VIDEO_UNAVAILABLE", message: "Camera not available", details: nil))
                return
            }

            DispatchQueue.main.async {
                do {
                    try self.viewManager.showLocalPreview(stream: stream)
                } catch {
                    result(FlutterError(code: "VIDEO_START_FAILED", message: error.localizedDescription, details: nil))
                    return
                }

                guard let activeCall = self.call else {
                    result(nil)
                    return
                }

                activeCall.startVideo(stream: stream, completionHandler: { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            result(FlutterError(code: "VIDEO_START_FAILED", message: error.localizedDescription, details: nil))
                        } else {
                            result(nil)
                        }
                    }
                })
            }
        }
    }

    private func stopVideo(result: @escaping FlutterResult) {
        guard let stream = localVideoStream else {
            DispatchQueue.main.async {
                self.viewManager.clearLocalPreview()
                result(nil)
            }
            return
        }

        guard let activeCall = call else {
            DispatchQueue.main.async {
                self.viewManager.clearLocalPreview()
                result(nil)
            }
            return
        }

        activeCall.stopVideo(stream: stream, completionHandler: { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "VIDEO_STOP_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    self?.viewManager.clearLocalPreview()
                    result(nil)
                }
            }
        })
    }

    private func switchCamera(result: @escaping FlutterResult) {
        ensureDeviceManager { manager in
            guard let manager = manager, let stream = self.localVideoStream else {
                result(FlutterError(code: "VIDEO_UNAVAILABLE", message: "No active camera stream", details: nil))
                return
            }

            let cameras = manager.cameras
            guard !cameras.isEmpty else {
                result(FlutterError(code: "VIDEO_UNAVAILABLE", message: "No cameras detected", details: nil))
                return
            }

            let current = self.currentCamera ?? cameras.first!
            let currentIndex = cameras.firstIndex { $0.id == current.id } ?? 0
            let nextCamera = cameras[(currentIndex + 1) % cameras.count]
            stream.switchSource(camera: nextCamera, completionHandler: { error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(code: "SWITCH_CAMERA_FAILED", message: error.localizedDescription, details: nil))
                    } else {
                        self.currentCamera = nextCamera
                        result(nil)
                    }
                }
            })
        }
    }

    private func addParticipants(args: [String: Any], result: @escaping FlutterResult) {
        guard let participantIds = args["participants"] as? [String], !participantIds.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Participants list is required", details: nil))
            return
        }
        guard let activeCall = call else {
            result(FlutterError(code: "NO_ACTIVE_CALL", message: "No active call", details: nil))
            return
        }

        do {
            for rawId in participantIds {
                let identifier = createCommunicationIdentifier(fromRawId: rawId)
                _ = try activeCall.add(participant: identifier)
            }
            result(["added": participantIds.count])
        } catch {
            result(FlutterError(code: "ADD_PARTICIPANT_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func removeParticipants(args: [String: Any], result: @escaping FlutterResult) {
        guard let participantIds = args["participants"] as? [String], !participantIds.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Participants list is required", details: nil))
            return
        }
        guard let activeCall = call else {
            result(FlutterError(code: "NO_ACTIVE_CALL", message: "No active call", details: nil))
            return
        }

        var participantsToRemove: [(String, RemoteParticipant)] = []
        var missing: [String] = []

        for rawId in participantIds {
            if let participant = activeCall.remoteParticipants.first(where: { $0.identifier.rawId == rawId }) {
                participantsToRemove.append((rawId, participant))
            } else {
                missing.append(rawId)
            }
        }

        guard !participantsToRemove.isEmpty else {
            result(["removed": 0, "missing": missing])
            return
        }

        let group = DispatchGroup()
        var removalError: FlutterError?

        for (_, participant) in participantsToRemove {
            group.enter()
            activeCall.remove(participant: participant) { error in
                if let error = error, removalError == nil {
                    removalError = FlutterError(code: "REMOVE_PARTICIPANT_FAILED", message: error.localizedDescription, details: participant.identifier.rawId)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let error = removalError {
                result(error)
            } else {
                result([
                    "removed": participantsToRemove.count,
                    "missing": missing,
                ])
            }
        }
    }

    private func attachCall(_ newCall: Call) {
        cleanupCallResources()
        call = newCall
        newCall.delegate = self
        handleAddedParticipants(newCall.remoteParticipants)
    }

    private func cleanupCallResources() {
        call?.delegate = nil
        call = nil
        incomingCall = nil

        DispatchQueue.main.async {
            self.remoteVideoRegistry.clear()
            self.viewManager.clearLocalPreview()
            self.viewManager.removeAllRemote()
        }

        localVideoStream = nil
        currentCamera = nil
    }

    private func handleAddedParticipants(_ participants: [RemoteParticipant]) {
        participants.forEach { participant in
            participant.delegate = self
            participant.videoStreams.forEach { subscribeRemoteStream($0) }
        }
    }

    private func handleRemovedParticipants(_ participants: [RemoteParticipant]) {
        participants.forEach { participant in
            participant.videoStreams.forEach { stream in
                removeRemoteStream(streamId: Int(stream.id))
            }
            participant.delegate = nil
        }
    }

    private func subscribeRemoteStream(_ stream: RemoteVideoStream) {
        DispatchQueue.main.async {
            do {
                let view = try self.remoteVideoRegistry.start(stream: stream)
                self.viewManager.addRemote(view: view, streamId: Int(stream.id))
            } catch {
                // Ignore renderer errors for remote streams.
            }
        }
    }

    private func removeRemoteStream(streamId: Int) {
        DispatchQueue.main.async {
            self.remoteVideoRegistry.stop(streamId: streamId)
            self.viewManager.removeRemote(streamId: streamId)
        }
    }

    private func answerIncomingCall() {
        guard let incoming = incomingCall else { return }

        ensureLocalVideoStream { stream, _ in
            let options = AcceptCallOptions()
            if let stream = stream {
                options.videoOptions = VideoOptions(localVideoStreams: [stream])
                DispatchQueue.main.async {
                    try? self.viewManager.showLocalPreview(stream: stream)
                }
            }

            incoming.accept(options: options, completionHandler: { [weak self] call, _ in
                guard let self = self else { return }
                if let call = call {
                    self.attachCall(call)
                }
                self.incomingCall = nil
            })
        }
    }

    private func ensureDeviceManager(completion: @escaping (DeviceManager?) -> Void) {
        if let manager = deviceManager {
            completion(manager)
            return
        }
        callClient.getDeviceManager(completionHandler: { [weak self] manager, _ in
            if let manager = manager {
                self?.deviceManager = manager
            }
            completion(manager)
        })
    }

    private func ensureLocalVideoStream(completion: @escaping (LocalVideoStream?, Error?) -> Void) {
        if let stream = localVideoStream {
            completion(stream, nil)
            return
        }
        ensureDeviceManager { manager in
            guard let manager = manager, let camera = manager.cameras.first else {
                completion(nil, NSError(domain: "acs_flutter_sdk", code: -1, userInfo: [NSLocalizedDescriptionKey: "No camera available"]))
                return
            }
            do {
                let stream = try LocalVideoStream(camera: camera)
                self.localVideoStream = stream
                self.currentCamera = camera
                completion(stream, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    private func callStateToString(_ state: CallState) -> String {
        switch state {
        case .none: return "none"
        case .connecting: return "connecting"
        case .ringing: return "ringing"
        case .connected: return "connected"
        case .localHold: return "onHold"
        case .disconnecting: return "disconnecting"
        case .disconnected: return "disconnected"
        case .earlyMedia: return "earlyMedia"
        case .remoteHold: return "remoteHold"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Chat

    private func initializeChat(args: [String: Any], result: @escaping FlutterResult) {
        guard let token = args["accessToken"] as? String, !token.isEmpty,
              let endpoint = args["endpoint"] as? String, !endpoint.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Access token and endpoint are required", details: nil))
            return
        }

        do {
            tokenCredential = try CommunicationTokenCredential(token: token)
            let options = AzureCommunicationChatClientOptions()
            chatClient = try ChatClient(endpoint: endpoint, credential: tokenCredential!, withOptions: options)
            result(["status": "initialized"])
        } catch {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func createChatThread(args: [String: Any], result: @escaping FlutterResult) {
        guard let topic = args["topic"] as? String, !topic.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Topic is required", details: nil))
            return
        }
        guard let client = chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Chat client not initialized", details: nil))
            return
        }

        let participants = (args["participants"] as? [String] ?? []).map { id -> ChatParticipant in
            ChatParticipant(
                id: CommunicationUserIdentifier(id),
                displayName: nil,
                shareHistoryTime: nil
            )
        }

        let request = CreateChatThreadRequest(topic: topic, participants: participants)

        client.create(thread: request) { createResult, _ in
            switch createResult {
            case .failure(let error):
                result(FlutterError(code: "CREATE_THREAD_FAILED", message: error.localizedDescription, details: nil))
            case .success(let response):
                guard let thread = response.chatThread else {
                    result(FlutterError(code: "CREATE_THREAD_FAILED", message: "Failed to create chat thread", details: nil))
                    return
                }
                result(["id": thread.id, "topic": thread.topic ?? ""])
            }
        }
    }

    private func joinChatThread(args: [String: Any], result: @escaping FlutterResult) {
        guard let threadId = args["threadId"] as? String, !threadId.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Thread ID is required", details: nil))
            return
        }
        guard let client = chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Chat client not initialized", details: nil))
            return
        }

        do {
            chatThreadClient = try client.createClient(forThread: threadId)
            result(["id": threadId, "topic": ""])
        } catch {
            result(FlutterError(code: "JOIN_THREAD_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func sendMessage(args: [String: Any], result: @escaping FlutterResult) {
        guard let threadId = args["threadId"] as? String, !threadId.isEmpty,
              let content = args["content"] as? String, !content.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Thread ID and content are required", details: nil))
            return
        }
        guard let client = chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Chat client not initialized", details: nil))
            return
        }

        do {
            let threadClient = try client.createClient(forThread: threadId)
            let request = SendChatMessageRequest(
                content: content,
                senderDisplayName: nil,
                type: .text,
                metadata: nil
            )

            threadClient.send(message: request) { sendResult, _ in
                switch sendResult {
                case .failure(let error):
                    result(FlutterError(code: "SEND_MESSAGE_FAILED", message: error.localizedDescription, details: nil))
                case .success(let response):
                    result(response.id)
                }
            }
        } catch {
            result(FlutterError(code: "SEND_MESSAGE_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func getMessages(args: [String: Any], result: @escaping FlutterResult) {
        guard let threadId = args["threadId"] as? String, !threadId.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Thread ID is required", details: nil))
            return
        }
        guard let client = chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Chat client not initialized", details: nil))
            return
        }

        do {
            let threadClient = try client.createClient(forThread: threadId)
            let maxMessages = args["maxMessages"] as? Int ?? 20
            let options = ListChatMessagesOptions(maxPageSize: Int32(maxMessages))

            threadClient.listMessages(withOptions: options) { [weak self] listResult, _ in
                guard let self = self else { return }
                switch listResult {
                case .failure(let error):
                    result(FlutterError(code: "GET_MESSAGES_FAILED", message: error.localizedDescription, details: nil))
                case .success(let response):
                    let items = response.items ?? []
                    let messages: [[String: Any]] = items.map { chatMessage in
                        [
                            "id": chatMessage.id,
                            "content": chatMessage.content?.message ?? "",
                            "senderId": self.identifierString(from: chatMessage.sender),
                            "sentOn": chatMessage.createdOn.value.iso8601String()
                        ]
                    }
                    result(messages)
                }
            }
        } catch {
            result(FlutterError(code: "GET_MESSAGES_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func sendTypingNotification(result: @escaping FlutterResult) {
        guard let threadClient = chatThreadClient else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Chat thread client not initialized. Join a thread first.",
                details: nil
            ))
            return
        }

        threadClient.sendTypingNotification { sendResult, _ in
            DispatchQueue.main.async {
                switch sendResult {
                case .failure(let error):
                    result(FlutterError(code: "TYPING_NOTIFICATION_FAILED", message: error.localizedDescription, details: nil))
                case .success:
                    result(nil)
                }
            }
        }
    }

    private func identifierString(from identifier: CommunicationIdentifier?) -> String {
        guard let identifier = identifier else { return "" }
        return identifier.rawId
    }

    // MARK: - CallDelegate

    public func call(_ call: Call, didUpdateState args: PropertyChangedEventArgs) {
        if call.state == .disconnected {
            cleanupCallResources()
        }
    }

    public func call(_ call: Call, didUpdateRemoteParticipants args: ParticipantsUpdatedEventArgs) {
        handleAddedParticipants(args.addedParticipants)
        handleRemovedParticipants(args.removedParticipants)
    }

    // MARK: - RemoteParticipantDelegate

    public func remoteParticipant(_ remoteParticipant: RemoteParticipant, didUpdateVideoStreams args: RemoteVideoStreamsEventArgs) {
        args.addedRemoteVideoStreams.forEach { subscribeRemoteStream($0) }
        args.removedRemoteVideoStreams.forEach { removeRemoteStream(streamId: Int($0.id)) }
    }

    // MARK: - CallAgentDelegate

    public func callAgent(_ callAgent: CallAgent, didReceiveIncomingCall incomingCall: IncomingCall) {
        self.incomingCall = incomingCall
        answerIncomingCall()
    }
}

private let isoDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private extension Date {
    func iso8601String() -> String {
        isoDateFormatter.string(from: self)
    }
}
