import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('acs_flutter_sdk');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'initializeIdentity':
          return {'status': 'initialized'};
        case 'createUser':
          return {'id': 'user-123'};
        case 'getToken':
          return {
            'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
            'expiresOn':
                DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
          };
        case 'revokeToken':
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

  group('AcsIdentityClient', () {
    late AcsIdentityClient client;

    setUp(() {
      final sdk = AcsFlutterSdk();
      client = sdk.createIdentityClient();
      log.clear();
    });

    test('initialize calls platform method with connection string', () async {
      await client.initialize(
          'endpoint=https://test.communication.azure.com/;accesskey=test123');

      expect(log, hasLength(1));
      expect(log[0].method, 'initializeIdentity');
      expect(log[0].arguments['connectionString'],
          'endpoint=https://test.communication.azure.com/;accesskey=test123');
    });

    test('initialize throws AcsException on platform error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
            code: 'INIT_ERROR', message: 'Failed to initialize');
      });

      expect(
        () => client.initialize('invalid'),
        throwsA(
            isA<AcsException>().having((e) => e.code, 'code', 'INIT_ERROR')),
      );
    });

    test('createUser calls platform method', () async {
      final user = await client.createUser();

      expect(log, hasLength(1));
      expect(log[0].method, 'createUser');
      expect(user, isA<CommunicationUser>());
      expect(user.id, 'user-123');
    });

    test('createUser throws AcsException on platform error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
            code: 'CREATE_ERROR', message: 'Failed to create user');
      });

      expect(
        () => client.createUser(),
        throwsA(
            isA<AcsException>().having((e) => e.code, 'code', 'CREATE_ERROR')),
      );
    });

    test('getToken calls platform method with userId and scopes', () async {
      final token = await client.getToken('user-123', ['voip', 'chat']);

      expect(log, hasLength(1));
      expect(log[0].method, 'getToken');
      expect(log[0].arguments['userId'], 'user-123');
      expect(log[0].arguments['scopes'], ['voip', 'chat']);
      expect(token, isA<AccessToken>());
      expect(token.token, startsWith('eyJ'));
    });

    test('getToken throws AcsException on platform error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
            code: 'TOKEN_ERROR', message: 'Failed to get token');
      });

      expect(
        () => client.getToken('user-123', ['voip']),
        throwsA(
            isA<AcsException>().having((e) => e.code, 'code', 'TOKEN_ERROR')),
      );
    });

    test('revokeToken calls platform method with userId', () async {
      await client.revokeToken('user-123');

      expect(log, hasLength(1));
      expect(log[0].method, 'revokeToken');
      expect(log[0].arguments['userId'], 'user-123');
    });

    test('revokeToken throws AcsException on platform error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
            code: 'REVOKE_ERROR', message: 'Failed to revoke token');
      });

      expect(
        () => client.revokeToken('user-123'),
        throwsA(
            isA<AcsException>().having((e) => e.code, 'code', 'REVOKE_ERROR')),
      );
    });
  });

  group('AcsException', () {
    test('creates exception with code and message', () {
      const exception =
          AcsException(code: 'TEST_ERROR', message: 'Test error message');
      expect(exception.code, 'TEST_ERROR');
      expect(exception.message, 'Test error message');
      expect(exception.details, isNull);
    });

    test('creates exception with details', () {
      const exception = AcsException(
        code: 'TEST_ERROR',
        message: 'Test error message',
        details: {'key': 'value'},
      );
      expect(exception.details, {'key': 'value'});
    });

    test('toString includes code and message', () {
      const exception =
          AcsException(code: 'TEST_ERROR', message: 'Test error message');
      expect(exception.toString(), contains('TEST_ERROR'));
      expect(exception.toString(), contains('Test error message'));
    });

    test('toString includes details when present', () {
      const exception = AcsException(
        code: 'TEST_ERROR',
        message: 'Test error message',
        details: 'Additional info',
      );
      expect(exception.toString(), contains('Additional info'));
    });
  });
}
