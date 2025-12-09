import 'dart:async';
import 'package:flutter/services.dart';

/// Client for managing Azure Communication Services calling operations
///
/// This client provides methods for making and receiving voice and video calls.
class AcsCallClient {
  final MethodChannel _channel;
  final StreamController<CallState> _callStateController =
      StreamController<CallState>.broadcast();

  /// Creates a new [AcsCallClient] instance
  ///
  /// [channel] is the method channel for communicating with native code
  AcsCallClient(this._channel);

  /// Stream of call state changes
  Stream<CallState> get callStateStream => _callStateController.stream;

  /// Requests microphone and camera permissions on the host platform.
  Future<void> requestPermissions() async {
    try {
      await _channel.invokeMethod('requestPermissions');
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to request permissions',
        details: e.details,
      );
    }
  }

  /// Initializes the calling client with an access token
  ///
  /// [accessToken] is the Azure Communication Services access token
  ///
  /// Throws an [AcsCallingException] if initialization fails
  Future<void> initialize(String accessToken) async {
    try {
      await _channel.invokeMethod('initializeCalling', {
        'accessToken': accessToken,
      });
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to initialize calling client',
        details: e.details,
      );
    }
  }

  /// Adds one or more participants to the active call.
  Future<void> addParticipants(List<String> participants) async {
    try {
      await _channel.invokeMethod('addParticipants', {
        'participants': participants,
      });
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to add participant(s)',
        details: e.details,
      );
    }
  }

  /// Removes one or more participants from the active call.
  Future<void> removeParticipants(List<String> participants) async {
    try {
      await _channel.invokeMethod('removeParticipants', {
        'participants': participants,
      });
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to remove participant(s)',
        details: e.details,
      );
    }
  }

  /// Starts a new call to the specified participants
  ///
  /// [participants] is a list of user IDs to call
  /// [withVideo] indicates whether to start with video enabled
  ///
  /// Returns a [Call] object representing the active call
  ///
  /// Throws an [AcsCallingException] if the call fails to start
  Future<Call> startCall(List<String> participants,
      {bool withVideo = false}) async {
    try {
      final result = await _channel.invokeMethod('startCall', {
        'participants': participants,
        'withVideo': withVideo,
      });
      return Call.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to start call',
        details: e.details,
      );
    }
  }

  /// Joins an existing call using a group call ID
  ///
  /// [groupCallId] is the ID of the group call to join
  /// [withVideo] indicates whether to join with video enabled
  ///
  /// Returns a [Call] object representing the active call
  ///
  /// Throws an [AcsCallingException] if joining fails
  Future<Call> joinCall(String groupCallId, {bool withVideo = false}) async {
    try {
      final result = await _channel.invokeMethod('joinCall', {
        'groupCallId': groupCallId,
        'withVideo': withVideo,
      });
      return Call.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to join call',
        details: e.details,
      );
    }
  }

  /// Joins a Teams meeting using the full meeting link.
  Future<Call> joinTeamsMeeting(String meetingLink,
      {bool withVideo = false}) async {
    try {
      final result = await _channel.invokeMethod('joinTeamsMeeting', {
        'meetingLink': meetingLink,
        'withVideo': withVideo,
      });
      return Call.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to join Teams meeting',
        details: e.details,
      );
    }
  }

  /// Ends the current call
  ///
  /// Throws an [AcsCallingException] if ending the call fails
  Future<void> endCall() async {
    try {
      await _channel.invokeMethod('endCall');
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to end call',
        details: e.details,
      );
    }
  }

  /// Mutes the local audio
  ///
  /// Throws an [AcsCallingException] if muting fails
  Future<void> muteAudio() async {
    try {
      await _channel.invokeMethod('muteAudio');
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to mute audio',
        details: e.details,
      );
    }
  }

  /// Unmutes the local audio
  ///
  /// Throws an [AcsCallingException] if unmuting fails
  Future<void> unmuteAudio() async {
    try {
      await _channel.invokeMethod('unmuteAudio');
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to unmute audio',
        details: e.details,
      );
    }
  }

  /// Starts the local video
  ///
  /// Throws an [AcsCallingException] if starting video fails. The current
  /// release returns a `NOT_IMPLEMENTED` error until local video support is added.
  Future<void> startVideo() async {
    try {
      await _channel.invokeMethod('startVideo');
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to start video',
        details: e.details,
      );
    }
  }

  /// Stops the local video
  ///
  /// Throws an [AcsCallingException] if stopping video fails. The current
  /// release returns a `NOT_IMPLEMENTED` error until local video support is added.
  Future<void> stopVideo() async {
    try {
      await _channel.invokeMethod('stopVideo');
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to stop video',
        details: e.details,
      );
    }
  }

  /// Switches the active camera source when local video is enabled.
  Future<void> switchCamera() async {
    try {
      await _channel.invokeMethod('switchCamera');
    } on PlatformException catch (e) {
      throw AcsCallingException(
        code: e.code,
        message: e.message ?? 'Failed to switch camera',
        details: e.details,
      );
    }
  }

  /// Disposes of resources
  void dispose() {
    _callStateController.close();
  }
}

/// Represents an active call
class Call {
  /// The unique identifier for the call
  final String id;

  /// The current state of the call
  final CallState state;

  /// Creates a new [Call] instance
  const Call({
    required this.id,
    required this.state,
  });

  /// Creates a [Call] from a map
  factory Call.fromMap(Map<String, dynamic> map) {
    return Call(
      id: map['id'] as String,
      state: CallState.values.firstWhere(
        (e) => e.toString() == 'CallState.${map['state']}',
        orElse: () => CallState.disconnected,
      ),
    );
  }

  /// Converts this [Call] to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'state': state.toString().split('.').last,
    };
  }

  @override
  String toString() => 'Call(id: $id, state: $state)';
}

/// Represents the state of a call
enum CallState {
  /// Call is being connected
  connecting,

  /// Call is connected and active
  connected,

  /// Call is on hold
  onHold,

  /// Call is disconnecting
  disconnecting,

  /// Call is disconnected
  disconnected,

  /// Call is ringing
  ringing,
}

/// Exception thrown by calling operations
class AcsCallingException implements Exception {
  /// Error code
  final String code;

  /// Error message
  final String message;

  /// Additional error details
  final dynamic details;

  /// Creates a new [AcsCallingException]
  const AcsCallingException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() =>
      'AcsCallingException($code): $message${details != null ? ' - $details' : ''}';
}
