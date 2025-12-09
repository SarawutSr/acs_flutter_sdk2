import 'dart:async';
import 'package:flutter/services.dart';

/// Client for managing Azure Communication Services chat operations
///
/// This client provides methods for creating and managing chat threads,
/// sending and receiving messages, and handling chat notifications.
class AcsChatClient {
  final MethodChannel _channel;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<TypingIndicator> _typingController =
      StreamController<TypingIndicator>.broadcast();

  /// Creates a new [AcsChatClient] instance
  ///
  /// [channel] is the method channel for communicating with native code
  AcsChatClient(this._channel);

  /// Stream of incoming chat messages.
  ///
  /// Remote ACS notifications require additional configuration on native
  /// platforms; the current release emits messages produced locally.
  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// Stream of typing indicators.
  ///
  /// Remote ACS notifications require additional configuration on native
  /// platforms; the current release emits indicators triggered locally.
  Stream<TypingIndicator> get typingIndicatorStream => _typingController.stream;

  /// Initializes the chat client with an access token
  ///
  /// [accessToken] is the Azure Communication Services access token
  /// [endpoint] is the Azure Communication Services endpoint, e.g. `https://<RESOURCE>.communication.azure.com`
  ///
  /// Throws an [AcsChatException] if initialization fails
  Future<void> initialize(String accessToken,
      {required String endpoint}) async {
    try {
      await _channel.invokeMethod('initializeChat', {
        'accessToken': accessToken,
        'endpoint': endpoint,
      });
    } on PlatformException catch (e) {
      throw AcsChatException(
        code: e.code,
        message: e.message ?? 'Failed to initialize chat client',
        details: e.details,
      );
    }
  }

  /// Creates a new chat thread
  ///
  /// [topic] is the topic/title of the chat thread
  /// [participants] is a list of user IDs to add to the thread
  ///
  /// Returns a [ChatThread] object representing the created thread
  ///
  /// Throws an [AcsChatException] if thread creation fails
  Future<ChatThread> createChatThread(
      String topic, List<String> participants) async {
    try {
      final result = await _channel.invokeMethod('createChatThread', {
        'topic': topic,
        'participants': participants,
      });
      return ChatThread.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw AcsChatException(
        code: e.code,
        message: e.message ?? 'Failed to create chat thread',
        details: e.details,
      );
    }
  }

  /// Joins an existing chat thread
  ///
  /// [threadId] is the ID of the thread to join
  ///
  /// Returns a [ChatThread] object representing the joined thread
  ///
  /// Throws an [AcsChatException] if joining fails
  Future<ChatThread> joinChatThread(String threadId) async {
    try {
      final result = await _channel.invokeMethod('joinChatThread', {
        'threadId': threadId,
      });
      return ChatThread.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw AcsChatException(
        code: e.code,
        message: e.message ?? 'Failed to join chat thread',
        details: e.details,
      );
    }
  }

  /// Sends a message to a chat thread
  ///
  /// [threadId] is the ID of the thread to send the message to
  /// [content] is the message content
  /// [senderId] optionally identifies the local user emitting the message for stream consumers
  ///
  /// Returns the ID of the sent message
  ///
  /// Throws an [AcsChatException] if sending fails
  Future<String> sendMessage(String threadId, String content,
      {String? senderId}) async {
    try {
      final result = await _channel.invokeMethod('sendMessage', {
        'threadId': threadId,
        'content': content,
      });
      final messageId = result as String;
      _messageController.add(
        ChatMessage(
          id: messageId,
          content: content,
          senderId: senderId ?? '',
          sentOn: DateTime.now().toUtc(),
        ),
      );
      return messageId;
    } on PlatformException catch (e) {
      throw AcsChatException(
        code: e.code,
        message: e.message ?? 'Failed to send message',
        details: e.details,
      );
    }
  }

  /// Gets messages from a chat thread
  ///
  /// [threadId] is the ID of the thread to get messages from
  /// [maxMessages] is the maximum number of messages to retrieve
  ///
  /// Returns a list of [ChatMessage] objects
  ///
  /// Throws an [AcsChatException] if retrieval fails
  Future<List<ChatMessage>> getMessages(String threadId,
      {int maxMessages = 50}) async {
    try {
      final result = await _channel.invokeMethod('getMessages', {
        'threadId': threadId,
        'maxMessages': maxMessages,
      });
      final List<dynamic> messageList = result as List<dynamic>;
      return messageList
          .map((m) => ChatMessage.fromMapSafe(Map<String, dynamic>.from(m)))
          .toList();
    } on PlatformException catch (e) {
      throw AcsChatException(
        code: e.code,
        message: e.message ?? 'Failed to get messages',
        details: e.details,
      );
    }
  }

  /// Sends a typing indicator notification
  ///
  /// [threadId] is the ID of the thread to send the typing indicator to
  /// [senderId] optionally identifies the local user emitting the indicator
  ///
  /// Throws an [AcsChatException] if sending fails
  Future<void> sendTypingNotification(String threadId,
      {String? senderId}) async {
    try {
      await _channel.invokeMethod('sendTypingNotification', {
        'threadId': threadId,
      });
      _typingController.add(
        TypingIndicator(
          threadId: threadId,
          userId: senderId ?? '',
        ),
      );
    } on PlatformException catch (e) {
      throw AcsChatException(
        code: e.code,
        message: e.message ?? 'Failed to send typing notification',
        details: e.details,
      );
    }
  }

  /// Disposes of resources
  void dispose() {
    _messageController.close();
    _typingController.close();
  }
}

/// Represents a chat thread
class ChatThread {
  /// The unique identifier for the thread
  final String id;

  /// The topic/title of the thread
  final String topic;

  /// Creates a new [ChatThread] instance
  const ChatThread({
    required this.id,
    required this.topic,
  });

  /// Creates a [ChatThread] from a map
  factory ChatThread.fromMap(Map<String, dynamic> map) {
    return ChatThread(
      id: map['id'] as String,
      topic: map['topic'] as String,
    );
  }

  /// Converts this [ChatThread] to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic': topic,
    };
  }

  @override
  String toString() => 'ChatThread(id: $id, topic: $topic)';
}

/// Represents a chat message
class ChatMessage {
  /// The unique identifier for the message
  final String id;

  /// The content of the message
  final String content;

  /// The sender's user ID
  final String senderId;

  /// The timestamp when the message was sent
  final DateTime sentOn;

  /// Creates a new [ChatMessage] instance
  const ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.sentOn,
  });

  /// Creates a [ChatMessage] from a map
  factory ChatMessage.fromMap(Map<String, dynamic> map) =>
      ChatMessage.fromMapSafe(map);

  /// Creates a [ChatMessage] from a map while tolerating missing timestamps.
  factory ChatMessage.fromMapSafe(Map<String, dynamic> map) {
    final sentOnValue = map['sentOn'];
    DateTime? sentOn;
    if (sentOnValue is String && sentOnValue.isNotEmpty) {
      sentOn = DateTime.tryParse(sentOnValue);
    }

    return ChatMessage(
      id: map['id'] as String? ?? '',
      content: map['content'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      sentOn: sentOn ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Converts this [ChatMessage] to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'senderId': senderId,
      'sentOn': sentOn.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'ChatMessage(id: $id, senderId: $senderId, content: $content)';
}

/// Represents a typing indicator notification
class TypingIndicator {
  /// The thread ID where typing is occurring
  final String threadId;

  /// The user ID of the person typing
  final String userId;

  /// Creates a new [TypingIndicator] instance
  const TypingIndicator({
    required this.threadId,
    required this.userId,
  });

  @override
  String toString() => 'TypingIndicator(threadId: $threadId, userId: $userId)';
}

/// Exception thrown by chat operations
class AcsChatException implements Exception {
  /// Error code
  final String code;

  /// Error message
  final String message;

  /// Additional error details
  final dynamic details;

  /// Creates a new [AcsChatException]
  const AcsChatException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() =>
      'AcsChatException($code): $message${details != null ? ' - $details' : ''}';
}
