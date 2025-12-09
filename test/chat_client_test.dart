import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('acs_flutter_sdk');
  final List<MethodCall> log = <MethodCall>[];
  const endpoint = 'https://example.communication.azure.com';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'initializeChat':
          return {'status': 'initialized'};
        case 'createChatThread':
          return {
            'id': 'thread-123',
            'topic': 'Test Thread',
          };
        case 'joinChatThread':
          return {
            'id': 'thread-456',
            'topic': 'Existing Thread',
          };
        case 'sendMessage':
          return 'msg-123';
        case 'getMessages':
          return [
            {
              'id': 'msg-1',
              'content': 'Message 1',
              'senderId': 'user-1',
              'sentOn': DateTime.now().toIso8601String(),
            },
            {
              'id': 'msg-2',
              'content': 'Message 2',
              'senderId': 'user-2',
              'sentOn': DateTime.now().toIso8601String(),
            },
          ];
        case 'sendTypingNotification':
          return null;
        default:
          throw PlatformException(code: 'NOT_IMPLEMENTED');
      }
    });
  });

  tearDown(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AcsChatClient', () {
    late AcsChatClient client;

    setUp(() {
      final sdk = AcsFlutterSdk();
      client = sdk.createChatClient();
      log.clear();
    });

    test('initialize calls platform method with token', () async {
      await client.initialize(
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        endpoint: endpoint,
      );

      expect(log, hasLength(1));
      expect(log[0].method, 'initializeChat');
      expect(log[0].arguments['accessToken'],
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
      expect(log[0].arguments['endpoint'], endpoint);
    });

    test('initialize throws AcsChatException on platform error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
            code: 'INIT_ERROR', message: 'Failed to initialize');
      });

      expect(
        () => client.initialize('invalid', endpoint: endpoint),
        throwsA(isA<AcsChatException>()
            .having((e) => e.code, 'code', 'INIT_ERROR')),
      );
    });

    test('createChatThread calls platform method with topic and participants',
        () async {
      final thread =
          await client.createChatThread('Test Thread', ['user-1', 'user-2']);

      expect(log, hasLength(1));
      expect(log[0].method, 'createChatThread');
      expect(log[0].arguments['topic'], 'Test Thread');
      expect(log[0].arguments['participants'], ['user-1', 'user-2']);
      expect(thread, isA<ChatThread>());
      expect(thread.id, 'thread-123');
      expect(thread.topic, 'Test Thread');
    });

    test('createChatThread throws AcsChatException on platform error',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
            code: 'CREATE_ERROR', message: 'Failed to create thread');
      });

      expect(
        () => client.createChatThread('Test', ['user-1']),
        throwsA(isA<AcsChatException>()
            .having((e) => e.code, 'code', 'CREATE_ERROR')),
      );
    });

    test('joinChatThread calls platform method with threadId', () async {
      final thread = await client.joinChatThread('thread-456');

      expect(log, hasLength(1));
      expect(log[0].method, 'joinChatThread');
      expect(log[0].arguments['threadId'], 'thread-456');
      expect(thread, isA<ChatThread>());
      expect(thread.id, 'thread-456');
    });

    test('sendMessage calls platform method with threadId and content',
        () async {
      final messageFuture =
          client.messageStream.first.timeout(const Duration(milliseconds: 100));
      final messageId = await client.sendMessage('thread-123', 'Hello, World!',
          senderId: 'user-1');

      expect(log, hasLength(1));
      expect(log[0].method, 'sendMessage');
      expect(log[0].arguments['threadId'], 'thread-123');
      expect(log[0].arguments['content'], 'Hello, World!');
      expect(messageId, isA<String>());
      expect(messageId, 'msg-123');

      final emitted = await messageFuture;
      expect(emitted.id, 'msg-123');
      expect(emitted.senderId, 'user-1');
      expect(emitted.content, 'Hello, World!');
    });

    test('getMessages calls platform method with threadId', () async {
      final messages = await client.getMessages('thread-123');

      expect(log, hasLength(1));
      expect(log[0].method, 'getMessages');
      expect(log[0].arguments['threadId'], 'thread-123');
      expect(messages, hasLength(2));
      expect(messages[0], isA<ChatMessage>());
      expect(messages[0].id, 'msg-1');
      expect(messages[1].id, 'msg-2');
    });

    test('getMessages with maxMessages parameter', () async {
      final messages = await client.getMessages('thread-123', maxMessages: 10);

      expect(log, hasLength(1));
      expect(log[0].arguments['maxMessages'], 10);
      expect(messages, hasLength(2));
    });

    test('sendTypingNotification calls platform method with threadId',
        () async {
      final typingFuture = client.typingIndicatorStream.first
          .timeout(const Duration(milliseconds: 100));
      await client.sendTypingNotification('thread-123', senderId: 'user-1');

      expect(log, hasLength(1));
      expect(log[0].method, 'sendTypingNotification');
      expect(log[0].arguments['threadId'], 'thread-123');

      final indicator = await typingFuture;
      expect(indicator.threadId, 'thread-123');
      expect(indicator.userId, 'user-1');
    });
  });

  group('ChatThread', () {
    test('creates instance with id and topic', () {
      const thread = ChatThread(id: 'thread-123', topic: 'Test Thread');
      expect(thread.id, 'thread-123');
      expect(thread.topic, 'Test Thread');
    });

    test('fromMap creates instance from map', () {
      final thread =
          ChatThread.fromMap({'id': 'thread-456', 'topic': 'Another Thread'});
      expect(thread.id, 'thread-456');
      expect(thread.topic, 'Another Thread');
    });

    test('toMap converts to map', () {
      const thread = ChatThread(id: 'thread-123', topic: 'Test Thread');
      final map = thread.toMap();
      expect(map['id'], 'thread-123');
      expect(map['topic'], 'Test Thread');
    });
  });

  group('ChatMessage', () {
    test('creates instance with all fields', () {
      final sentOn = DateTime.now();
      final message = ChatMessage(
        id: 'msg-123',
        content: 'Hello',
        senderId: 'user-1',
        sentOn: sentOn,
      );
      expect(message.id, 'msg-123');
      expect(message.content, 'Hello');
      expect(message.senderId, 'user-1');
      expect(message.sentOn, sentOn);
    });

    test('fromMap creates instance from map', () {
      final sentOn = DateTime.now();
      final message = ChatMessage.fromMap({
        'id': 'msg-456',
        'content': 'Hi there',
        'senderId': 'user-2',
        'sentOn': sentOn.toIso8601String(),
      });
      expect(message.id, 'msg-456');
      expect(message.content, 'Hi there');
      expect(message.senderId, 'user-2');
    });

    test('toMap converts to map', () {
      final sentOn = DateTime.now();
      final message = ChatMessage(
        id: 'msg-123',
        content: 'Hello',
        senderId: 'user-1',
        sentOn: sentOn,
      );
      final map = message.toMap();
      expect(map['id'], 'msg-123');
      expect(map['content'], 'Hello');
      expect(map['senderId'], 'user-1');
      expect(map['sentOn'], sentOn.toIso8601String());
    });
  });

  group('TypingIndicator', () {
    test('creates instance with threadId and userId', () {
      const indicator = TypingIndicator(threadId: 'thread-1', userId: 'user-1');
      expect(indicator.threadId, 'thread-1');
      expect(indicator.userId, 'user-1');
    });

    test('toString includes threadId and userId', () {
      const indicator = TypingIndicator(threadId: 'thread-1', userId: 'user-1');
      expect(indicator.toString(), contains('thread-1'));
      expect(indicator.toString(), contains('user-1'));
    });
  });

  group('AcsChatException', () {
    test('creates exception with code and message', () {
      const exception =
          AcsChatException(code: 'CHAT_ERROR', message: 'Chat failed');
      expect(exception.code, 'CHAT_ERROR');
      expect(exception.message, 'Chat failed');
      expect(exception.details, isNull);
    });

    test('toString includes code and message', () {
      const exception =
          AcsChatException(code: 'CHAT_ERROR', message: 'Chat failed');
      expect(exception.toString(), contains('CHAT_ERROR'));
      expect(exception.toString(), contains('Chat failed'));
    });
  });
}
