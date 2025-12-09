package com.burhanrabbani.acs_flutter_sdk

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.azure.android.communication.calling.*
import com.azure.android.communication.calling.TeamsMeetingLinkLocator
import com.azure.android.communication.chat.ChatClient
import com.azure.android.communication.chat.ChatClientBuilder
import com.azure.android.communication.chat.ChatThreadClient
import com.azure.android.communication.chat.models.CreateChatThreadOptions
import com.azure.android.communication.chat.models.SendChatMessageOptions
import com.azure.android.communication.chat.models.ListChatMessagesOptions
import com.azure.android.communication.chat.models.ChatParticipant
import com.azure.android.communication.common.CommunicationIdentifier
import com.azure.android.communication.common.CommunicationTokenCredential
import com.azure.android.communication.common.CommunicationUserIdentifier
import com.azure.android.communication.common.PhoneNumberIdentifier
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors

/**
 * Azure Communication Services Flutter plugin implementation.
 */
class AcsFlutterSdkPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var context: Context
    private lateinit var channel: MethodChannel

    private var activity: Activity? = null
    private var viewManager: VideoViewManager? = null
    private var videoRegistry: VideoStreamRegistry? = null

    // Azure Communication Services instances
    private var tokenCredential: CommunicationTokenCredential? = null
    private var callClient: CallClient? = null
    private var deviceManager: DeviceManager? = null
    private var callAgent: CallAgent? = null
    private var call: Call? = null
    private var localVideoStream: LocalVideoStream? = null
    private var currentCamera: VideoDeviceInfo? = null
    private var incomingCall: IncomingCall? = null
    private var remoteParticipantListener: ParticipantsUpdatedListener? = null
    private var callStateListener: PropertyChangedListener? = null
    private var chatClient: ChatClient? = null
    private var chatThreadClient: ChatThreadClient? = null

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "acs_flutter_sdk")
        channel.setMethodCallHandler(this)

        viewManager = VideoViewManager(context)
        videoRegistry = VideoStreamRegistry(context)
        binding.platformViewRegistry.registerViewFactory(
            PLATFORM_VIEW_TYPE,
            VideoPlatformViewFactory(viewManager!!)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        cleanupCallResources()
        executor.shutdown()
        viewManager = null
        videoRegistry = null
        callClient = null
        callAgent = null
        tokenCredential = null
    }

    // region ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
    // endregion

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // Platform info
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")

            // Identity methods
            "initializeIdentity" -> initializeIdentity(call, result)
            "createUser" -> result.error(
                "NOT_IMPLEMENTED",
                "User creation should be done server-side for security. Use your backend API.",
                null
            )
            "getToken" -> result.error(
                "NOT_IMPLEMENTED",
                "Token generation should be done server-side for security. Use your backend API.",
                null
            )
            "revokeToken" -> result.error(
                "NOT_IMPLEMENTED",
                "Token revocation should be done server-side. Use your backend API.",
                null
            )

            // Calling methods
            "initializeCalling" -> initializeCalling(call, result)
            "requestPermissions" -> requestPermissions(result)
            "startCall" -> startCall(call, result)
            "joinCall" -> joinCall(call, result)
            "joinTeamsMeeting" -> joinTeamsMeeting(call, result)
            "endCall" -> endCall(result)
            "muteAudio" -> muteAudio(result)
            "unmuteAudio" -> unmuteAudio(result)
            "startVideo" -> startVideo(result)
            "stopVideo" -> stopVideo(result)
            "switchCamera" -> switchCamera(result)
            "addParticipants" -> addParticipants(call, result)
            "removeParticipants" -> removeParticipants(call, result)

            // Chat methods
            "initializeChat" -> initializeChat(call, result)
            "createChatThread" -> createChatThread(call, result)
            "joinChatThread" -> joinChatThread(call, result)
            "sendMessage" -> sendMessage(call, result)
            "getMessages" -> getMessages(call, result)
            "sendTypingNotification" -> sendTypingNotification(result)

            else -> result.notImplemented()
        }
    }

    // region Identity
    private fun initializeIdentity(call: MethodCall, result: Result) {
        val connectionString = call.argument<String>("connectionString")
        if (connectionString.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Connection string is required", null)
            return
        }
        result.success(mapOf("status" to "initialized"))
    }
    // endregion

    // region Calling
    private fun initializeCalling(call: MethodCall, result: Result) {
        val accessToken = call.argument<String>("accessToken")
        if (accessToken.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Access token is required", null)
            return
        }

        executor.execute {
            try {
                tokenCredential = CommunicationTokenCredential(accessToken)
                callClient = callClient ?: CallClient()
                val agentFuture = callClient!!.createCallAgent(context, tokenCredential!!)
                agentFuture.whenComplete { agent, error ->
                    if (error != null) {
                        runOnMainThread {
                            result.error("INITIALIZATION_ERROR", error.message, null)
                        }
                        return@whenComplete
                    }
                    callAgent = agent
                    try {
                        deviceManager = callClient!!.getDeviceManager(context).get()
                    } catch (e: Exception) {
                        // Device manager acquisition failure is non-fatal for audio-only scenarios.
                    }
                    callAgent?.addOnIncomingCallListener { incoming ->
                        incomingCall = incoming
                        executor.execute { answerIncomingCall() }
                    }
                    runOnMainThread { result.success(mapOf("status" to "initialized")) }
                }
            } catch (e: Exception) {
                runOnMainThread {
                    result.error("INITIALIZATION_ERROR", e.message, null)
                }
            }
        }
    }

    private fun requestPermissions(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Permission requests require an attached activity", null)
            return
        }
        val required = arrayOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO
        )
        val missing = required.filter {
            ContextCompat.checkSelfPermission(currentActivity, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        ActivityCompat.requestPermissions(
            currentActivity,
            missing.toTypedArray(),
            PERMISSIONS_REQUEST_CODE
        )
        result.success(true)
    }

    private fun startCall(call: MethodCall, result: Result) {
        val participants = call.argument<List<String>>("participants")
        if (participants.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Participants list is required", null)
            return
        }
        if (callAgent == null) {
            result.error("NOT_INITIALIZED", "Call agent not initialized. Call initializeCalling first.", null)
            return
        }

        val withVideo = call.argument<Boolean>("withVideo") ?: false
        executor.execute {
            try {
                val options = StartCallOptions()
                if (withVideo) {
                    ensureLocalVideoStream()?.let { stream ->
                        options.videoOptions = VideoOptions(arrayOf(stream))
                        viewManager?.showLocalPreview(context, stream)
                    }
                }
                val callees = participants.map { CommunicationUserIdentifier(it) }
                val newCall = callAgent!!.startCall(context, callees, options)
                attachCall(newCall)
                runOnMainThread {
                    result.success(
                        mapOf(
                            "id" to newCall.id,
                            "state" to callStateToString(newCall.state)
                        )
                    )
                }
            } catch (e: Exception) {
                runOnMainThread { result.error("CALL_START_FAILED", e.message, null) }
            }
        }
    }

    private fun joinCall(call: MethodCall, result: Result) {
        val groupCallId = call.argument<String>("groupCallId")
        if (groupCallId.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Group call ID is required", null)
            return
        }
        if (callAgent == null) {
            result.error("NOT_INITIALIZED", "Call agent not initialized. Call initializeCalling first.", null)
            return
        }
        val withVideo = call.argument<Boolean>("withVideo") ?: false

        executor.execute {
            try {
                val options = JoinCallOptions()
                if (withVideo) {
                    ensureLocalVideoStream()?.let { stream ->
                        options.videoOptions = VideoOptions(arrayOf(stream))
                        viewManager?.showLocalPreview(context, stream)
                    }
                }
                val locator = GroupCallLocator(UUID.fromString(groupCallId))
                val joinedCall = callAgent!!.join(context, locator, options)
                attachCall(joinedCall)
                runOnMainThread {
                    result.success(
                        mapOf(
                            "id" to joinedCall.id,
                            "state" to callStateToString(joinedCall.state)
                        )
                    )
                }
            } catch (e: Exception) {
                runOnMainThread { result.error("CALL_JOIN_FAILED", e.message, null) }
            }
        }
    }

    private fun endCall(result: Result) {
        val activeCall = call
        if (activeCall == null) {
            result.error("NO_ACTIVE_CALL", "No active call to end", null)
            return
        }
        executor.execute {
            try {
                activeCall.hangUp(HangUpOptions()).whenComplete { _, error ->
                    if (error != null) {
                        runOnMainThread { result.error("HANGUP_FAILED", error.message, null) }
                    } else {
                        cleanupCallResources()
                        runOnMainThread { result.success(null) }
                    }
                }
            } catch (e: Exception) {
                runOnMainThread { result.error("HANGUP_FAILED", e.message, null) }
            }
        }
    }

    private fun muteAudio(result: Result) {
        val activeCall = call
        if (activeCall == null) {
            result.error("NO_ACTIVE_CALL", "No active call", null)
            return
        }
        executor.execute {
            try {
                activeCall.muteOutgoingAudio(context).whenComplete { _, error ->
                    if (error != null) {
                        runOnMainThread { result.error("MUTE_FAILED", error.message, null) }
                    } else {
                        runOnMainThread { result.success(null) }
                    }
                }
            } catch (e: Exception) {
                runOnMainThread { result.error("MUTE_FAILED", e.message, null) }
            }
        }
    }

    private fun unmuteAudio(result: Result) {
        val activeCall = call
        if (activeCall == null) {
            result.error("NO_ACTIVE_CALL", "No active call", null)
            return
        }
        executor.execute {
            try {
                activeCall.unmuteOutgoingAudio(context).whenComplete { _, error ->
                    if (error != null) {
                        runOnMainThread { result.error("UNMUTE_FAILED", error.message, null) }
                    } else {
                        runOnMainThread { result.success(null) }
                    }
                }
            } catch (e: Exception) {
                runOnMainThread { result.error("UNMUTE_FAILED", e.message, null) }
            }
        }
    }

    private fun startVideo(result: Result) {
        executor.execute {
            try {
                val stream = ensureLocalVideoStream()
                if (stream == null) {
                    runOnMainThread {
                        result.error("VIDEO_UNAVAILABLE", "Unable to access camera", null)
                    }
                    return@execute
                }
                viewManager?.showLocalPreview(context, stream)
                val activeCall = call
                if (activeCall != null) {
                    activeCall.startVideo(context, stream).whenComplete { _, error ->
                        if (error != null) {
                            runOnMainThread { result.error("VIDEO_START_FAILED", error.message, null) }
                        } else {
                            runOnMainThread { result.success(null) }
                        }
                    }
                } else {
                    runOnMainThread { result.success(null) }
                }
            } catch (e: Exception) {
                runOnMainThread { result.error("VIDEO_START_FAILED", e.message, null) }
            }
        }
    }

    private fun stopVideo(result: Result) {
        executor.execute {
            try {
                val stream = localVideoStream
                val activeCall = call
                if (stream != null && activeCall != null) {
                    activeCall.stopVideo(context, stream).whenComplete { _, error ->
                        if (error != null) {
                            runOnMainThread { result.error("VIDEO_STOP_FAILED", error.message, null) }
                        } else {
                            viewManager?.clearLocalPreview()
                            runOnMainThread { result.success(null) }
                        }
                    }
                } else {
                    viewManager?.clearLocalPreview()
                    runOnMainThread { result.success(null) }
                }
            } catch (e: Exception) {
                runOnMainThread { result.error("VIDEO_STOP_FAILED", e.message, null) }
            }
        }
    }

    private fun switchCamera(result: Result) {
        executor.execute {
            try {
                val dm = ensureDeviceManager()
                val stream = ensureLocalVideoStream()
                if (dm == null || stream == null) {
                    runOnMainThread { result.error("VIDEO_UNAVAILABLE", "No cameras detected", null) }
                    return@execute
                }
                val cameras = dm.cameras
                if (cameras.isNullOrEmpty()) {
                    runOnMainThread { result.error("VIDEO_UNAVAILABLE", "No cameras detected", null) }
                    return@execute
                }
                val current = currentCamera
                val currentIndex = cameras.indexOfFirst { it.id == current?.id }.coerceAtLeast(0)
                val nextIndex = (currentIndex + 1) % cameras.size
                val nextCamera = cameras[nextIndex]
                stream.switchSource(nextCamera).get()
                currentCamera = nextCamera
                runOnMainThread { result.success(null) }
            } catch (e: Exception) {
                runOnMainThread { result.error("SWITCH_CAMERA_FAILED", e.message, null) }
            }
        }
    }

    private fun joinTeamsMeeting(call: MethodCall, result: Result) {
        val meetingLink = call.argument<String>("meetingLink")
        if (meetingLink.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Teams meeting link is required", null)
            return
        }
        if (callAgent == null) {
            result.error("NOT_INITIALIZED", "Call agent not initialized. Call initializeCalling first.", null)
            return
        }

        val withVideo = call.argument<Boolean>("withVideo") ?: false

        executor.execute {
            try {
                val options = JoinCallOptions()
                if (withVideo) {
                    ensureLocalVideoStream()?.let { stream ->
                        options.videoOptions = VideoOptions(arrayOf(stream))
                        viewManager?.showLocalPreview(context, stream)
                    }
                }
                val locator = TeamsMeetingLinkLocator(meetingLink)
                val joinedCall = callAgent!!.join(context, locator, options)
                attachCall(joinedCall)
                runOnMainThread {
                    result.success(
                        mapOf(
                            "id" to joinedCall.id,
                            "state" to callStateToString(joinedCall.state)
                        )
                    )
                }
            } catch (e: Exception) {
                runOnMainThread { result.error("CALL_JOIN_FAILED", e.message, null) }
            }
        }
    }

    private fun addParticipants(call: MethodCall, result: Result) {
        val participantIds = call.argument<List<String>>("participants")
        if (participantIds.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Participants list is required", null)
            return
        }
        val activeCall = this.call
        if (activeCall == null) {
            result.error("NO_ACTIVE_CALL", "No active call", null)
            return
        }

        executor.execute {
            try {
                participantIds.forEach { rawId ->
                    val identifier = buildIdentifier(rawId)
                    activeCall.addParticipant(identifier)
                }
                runOnMainThread { result.success(mapOf("added" to participantIds.size)) }
            } catch (e: Exception) {
                runOnMainThread { result.error("ADD_PARTICIPANT_FAILED", e.message, null) }
            }
        }
    }

    private fun removeParticipants(call: MethodCall, result: Result) {
        val participantIds = call.argument<List<String>>("participants")
        if (participantIds.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Participants list is required", null)
            return
        }
        val activeCall = this.call
        if (activeCall == null) {
            result.error("NO_ACTIVE_CALL", "No active call", null)
            return
        }

        executor.execute {
            try {
                val remoteParticipants = activeCall.remoteParticipants
                val participantsToRemove = mutableListOf<Pair<String, RemoteParticipant>>()
                val missing = mutableListOf<String>()

                participantIds.forEach { rawId ->
                    val participant = remoteParticipants.firstOrNull { it.identifier?.rawId == rawId }
                    if (participant != null) {
                        participantsToRemove.add(rawId to participant)
                    } else {
                        missing.add(rawId)
                    }
                }

                if (participantsToRemove.isEmpty()) {
                    runOnMainThread { result.success(mapOf("removed" to 0, "missing" to missing)) }
                    return@execute
                }

                // Remove participants sequentially
                var removedCount = 0
                var lastError: Throwable? = null

                for ((_, participant) in participantsToRemove) {
                    try {
                        activeCall.removeParticipant(participant).get()
                        removedCount++
                    } catch (e: Exception) {
                        lastError = e
                    }
                }

                if (lastError != null && removedCount == 0) {
                    runOnMainThread { result.error("REMOVE_PARTICIPANT_FAILED", lastError.message, null) }
                } else {
                    runOnMainThread {
                        result.success(
                            mapOf(
                                "removed" to removedCount,
                                "missing" to missing
                            )
                        )
                    }
                }
            } catch (e: Exception) {
                runOnMainThread { result.error("REMOVE_PARTICIPANT_FAILED", e.message, null) }
            }
        }
    }

    private fun attachCall(newCall: Call) {
        cleanupCallResources()
        call = newCall
        remoteParticipantListener = ParticipantsUpdatedListener { event ->
            handleAddedParticipants(event.addedParticipants)
            handleRemovedParticipants(event.removedParticipants)
        }
        callStateListener = PropertyChangedListener {
            if (newCall.state == CallState.DISCONNECTED) {
                cleanupCallResources()
            }
        }
        newCall.addOnRemoteParticipantsUpdatedListener(remoteParticipantListener)
        newCall.addOnStateChangedListener(callStateListener)
        handleAddedParticipants(newCall.remoteParticipants)
    }

    private fun handleAddedParticipants(participants: List<RemoteParticipant>) {
        participants.forEach { participant ->
            participant.videoStreams.forEach { subscribeRemoteStream(it) }
            participant.addOnVideoStreamsUpdatedListener { event ->
                event.addedRemoteVideoStreams.forEach { subscribeRemoteStream(it) }
                event.removedRemoteVideoStreams.forEach { removeRemoteStream(it.id) }
            }
        }
    }

    private fun handleRemovedParticipants(participants: List<RemoteParticipant>) {
        participants.forEach { participant ->
            participant.videoStreams.forEach { removeRemoteStream(it.id) }
        }
    }

    private fun subscribeRemoteStream(stream: RemoteVideoStream) {
        val view = videoRegistry?.start(stream) ?: return
        viewManager?.addRemoteView(activity, stream.id, view)
    }

    private fun removeRemoteStream(streamId: Int) {
        viewManager?.removeRemoteView(activity, streamId)
        videoRegistry?.stop(streamId)
    }

    private fun cleanupCallResources() {
        call?.removeOnRemoteParticipantsUpdatedListener(remoteParticipantListener)
        call?.removeOnStateChangedListener(callStateListener)
        call = null
        remoteParticipantListener = null
        callStateListener = null
        incomingCall = null
        videoRegistry?.clear()
        viewManager?.remoteContainer?.removeAllViews()
        viewManager?.clearLocalPreview()
        localVideoStream = null
    }

    private fun answerIncomingCall() {
        val incoming = incomingCall ?: return
        try {
            val options = AcceptCallOptions()
            ensureLocalVideoStream()?.let { stream ->
                options.videoOptions = VideoOptions(arrayOf(stream))
                viewManager?.showLocalPreview(context, stream)
            }
            val acceptedCall = incoming.accept(context, options).get()
            attachCall(acceptedCall)
        } catch (e: Exception) {
            // Ignore accept errors; the caller can start a new call.
        } finally {
            incomingCall = null
        }
    }

    private fun ensureLocalVideoStream(): LocalVideoStream? {
        localVideoStream?.let { return it }
        val dm = ensureDeviceManager() ?: return null
        val cameras = dm.cameras
        if (cameras.isNullOrEmpty()) {
            return null
        }
        if (currentCamera == null) {
            currentCamera = cameras.first()
        }
        return LocalVideoStream(currentCamera, context).also { localVideoStream = it }
    }

    private fun ensureDeviceManager(): DeviceManager? {
        if (deviceManager != null) return deviceManager
        return try {
            val dm = callClient?.getDeviceManager(context)?.get()
            deviceManager = dm
            dm
        } catch (e: Exception) {
            null
        }
    }
    // endregion

    // region Chat
    private fun initializeChat(call: MethodCall, result: Result) {
        val accessToken = call.argument<String>("accessToken")
        val endpoint = call.argument<String>("endpoint")
        if (accessToken.isNullOrBlank() || endpoint.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Access token and endpoint are required", null)
            return
        }
        try {
            tokenCredential = CommunicationTokenCredential(accessToken)
            chatClient = ChatClientBuilder()
                .endpoint(endpoint)
                .credential(tokenCredential!!)
                .buildClient()
            result.success(mapOf("status" to "initialized"))
        } catch (e: Exception) {
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun createChatThread(call: MethodCall, result: Result) {
        val topic = call.argument<String>("topic")
        if (topic.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Topic is required", null)
            return
        }
        val client = chatClient
        if (client == null) {
            result.error("NOT_INITIALIZED", "Chat client not initialized. Call initializeChat first.", null)
            return
        }
        val participants = call.argument<List<String>>("participants") ?: emptyList()
        try {
            // Azure Chat SDK 2.0.3 API with models package
            val options = CreateChatThreadOptions()
                .setTopic(topic)
            if (participants.isNotEmpty()) {
                val chatParticipants = participants.map { id ->
                    ChatParticipant()
                        .setCommunicationIdentifier(CommunicationUserIdentifier(id))
                }
                options.setParticipants(chatParticipants)
            }
            val response = client.createChatThread(options)
            if (response != null) {
                result.success(
                    mapOf(
                        "id" to (response.chatThreadProperties?.id ?: ""),
                        "topic" to (response.chatThreadProperties?.topic ?: topic)
                    )
                )
            } else {
                result.error("CREATE_THREAD_FAILED", "Failed to create chat thread", null)
            }
        } catch (e: Exception) {
            result.error("CREATE_THREAD_FAILED", e.message, null)
        }
    }

    private fun joinChatThread(call: MethodCall, result: Result) {
        val threadId = call.argument<String>("threadId")
        if (threadId.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Thread ID is required", null)
            return
        }
        val client = chatClient
        if (client == null) {
            result.error("NOT_INITIALIZED", "Chat client not initialized. Call initializeChat first.", null)
            return
        }
        try {
            chatThreadClient = client.getChatThreadClient(threadId)
            result.success(mapOf("id" to threadId, "topic" to ""))
        } catch (e: Exception) {
            result.error("JOIN_THREAD_FAILED", e.message, null)
        }
    }

    private fun sendMessage(call: MethodCall, result: Result) {
        val threadId = call.argument<String>("threadId")
        val content = call.argument<String>("content")
        if (threadId.isNullOrBlank() || content.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Thread ID and content are required", null)
            return
        }
        val client = chatClient
        if (client == null) {
            result.error("NOT_INITIALIZED", "Chat client not initialized", null)
            return
        }
        try {
            val threadClient = client.getChatThreadClient(threadId)
            // Azure Chat SDK 2.0.3 API with models package
            val options = SendChatMessageOptions()
                .setContent(content)
            val response = threadClient.sendMessage(options)
            if (response != null) {
                result.success(response.id ?: "")
            } else {
                result.error("SEND_MESSAGE_FAILED", "Failed to send message", null)
            }
        } catch (e: Exception) {
            result.error("SEND_MESSAGE_FAILED", e.message, null)
        }
    }

    private fun getMessages(call: MethodCall, result: Result) {
        val threadId = call.argument<String>("threadId")
        if (threadId.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Thread ID is required", null)
            return
        }
        val client = chatClient
        if (client == null) {
            result.error("NOT_INITIALIZED", "Chat client not initialized", null)
            return
        }
        try {
            val threadClient = client.getChatThreadClient(threadId)
            val maxMessages = call.argument<Int>("maxMessages") ?: 20
            // Azure Chat SDK 2.0.3 API with models package
            val options = ListChatMessagesOptions()
                .setMaxPageSize(maxMessages)
            val paged = threadClient.listMessages(options, null)
            val messages = mutableListOf<Map<String, Any>>()
            // Iterate through the paged results
            for (message in paged) {
                messages.add(
                    mapOf(
                        "id" to (message.id ?: ""),
                        "content" to (message.content?.message ?: ""),
                        "senderId" to (message.senderCommunicationIdentifier?.rawId ?: ""),
                        "sentOn" to (message.createdOn?.toString() ?: "")
                    )
                )
                if (messages.size >= maxMessages) break
            }
            result.success(messages)
        } catch (e: Exception) {
            result.error("GET_MESSAGES_FAILED", e.message, null)
        }
    }

    private fun sendTypingNotification(result: Result) {
        val threadClient = chatThreadClient
        if (threadClient == null) {
            result.error(
                "NOT_INITIALIZED",
                "Chat thread client not initialized. Join a thread first.",
                null
            )
            return
        }
        try {
            threadClient.sendTypingNotification()
            result.success(null)
        } catch (e: Exception) {
            result.error("TYPING_NOTIFICATION_FAILED", e.message, null)
        }
    }
    // endregion

    private fun callStateToString(state: CallState): String =
        when (state) {
            CallState.NONE -> "none"
            CallState.CONNECTING -> "connecting"
            CallState.RINGING -> "ringing"
            CallState.CONNECTED -> "connected"
            CallState.LOCAL_HOLD -> "onHold"
            CallState.DISCONNECTING -> "disconnecting"
            CallState.DISCONNECTED -> "disconnected"
            CallState.EARLY_MEDIA -> "earlyMedia"
            CallState.REMOTE_HOLD -> "remoteHold"
            else -> "unknown"
        }

    private fun runOnMainThread(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post(action)
        }
    }

    private fun buildIdentifier(rawId: String): CommunicationIdentifier {
        return if (rawId.startsWith("+")) {
            PhoneNumberIdentifier(rawId)
        } else {
            CommunicationIdentifier.fromRawId(rawId)
        }
    }

    companion object {
        private const val PERMISSIONS_REQUEST_CODE = 9001
        private const val PLATFORM_VIEW_TYPE = "acs_video_view"
    }
}
