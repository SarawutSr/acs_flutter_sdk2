import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('acs_flutter_sdk');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'getPlatformVersion':
          return 'Android 14';
        case 'initializeIdentity':
          return {'status': 'initialized'};
        case 'initializeCalling':
          return {'status': 'initialized'};
        case 'initializeChat':
          return {'status': 'initialized'};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AcsFlutterSdk', () {
    test('getPlatformVersion returns platform version', () async {
      final sdk = AcsFlutterSdk();
      final version = await sdk.getPlatformVersion();
      expect(version, 'Android 14');
      expect(log, <Matcher>[
        isMethodCall('getPlatformVersion', arguments: null),
      ]);
    });

    test('createIdentityClient returns AcsIdentityClient instance', () {
      final sdk = AcsFlutterSdk();
      final client = sdk.createIdentityClient();
      expect(client, isA<AcsIdentityClient>());
    });

    test('createCallClient returns AcsCallClient instance', () {
      final sdk = AcsFlutterSdk();
      final client = sdk.createCallClient();
      expect(client, isA<AcsCallClient>());
    });

    test('createChatClient returns AcsChatClient instance', () {
      final sdk = AcsFlutterSdk();
      final client = sdk.createChatClient();
      expect(client, isA<AcsChatClient>());
    });
  });

  group('Models', () {
    group('CommunicationUser', () {
      test('creates instance with id', () {
        const user = CommunicationUser(id: 'user-123');
        expect(user.id, 'user-123');
      });

      test('fromMap creates instance from map', () {
        final user = CommunicationUser.fromMap({'id': 'user-456'});
        expect(user.id, 'user-456');
      });

      test('toMap converts to map', () {
        const user = CommunicationUser(id: 'user-789');
        final map = user.toMap();
        expect(map, {'id': 'user-789'});
      });

      test('equality works correctly', () {
        const user1 = CommunicationUser(id: 'user-1');
        const user2 = CommunicationUser(id: 'user-1');
        const user3 = CommunicationUser(id: 'user-2');
        expect(user1, equals(user2));
        expect(user1, isNot(equals(user3)));
      });

      test('hashCode works correctly', () {
        const user1 = CommunicationUser(id: 'user-1');
        const user2 = CommunicationUser(id: 'user-1');
        expect(user1.hashCode, equals(user2.hashCode));
      });
    });

    group('AccessToken', () {
      test('creates instance with token and expiry', () {
        final expiresOn = DateTime.now().add(const Duration(hours: 1));
        final token = AccessToken(token: 'abc123', expiresOn: expiresOn);
        expect(token.token, 'abc123');
        expect(token.expiresOn, expiresOn);
      });

      test('fromMap creates instance from map', () {
        final expiresOn = DateTime.now().add(const Duration(hours: 1));
        final token = AccessToken.fromMap({
          'token': 'xyz789',
          'expiresOn': expiresOn.toIso8601String(),
        });
        expect(token.token, 'xyz789');
        expect(token.expiresOn.toIso8601String(), expiresOn.toIso8601String());
      });

      test('toMap converts to map', () {
        final expiresOn = DateTime.now().add(const Duration(hours: 1));
        final token = AccessToken(token: 'token123', expiresOn: expiresOn);
        final map = token.toMap();
        expect(map['token'], 'token123');
        expect(map['expiresOn'], expiresOn.toIso8601String());
      });

      test('isExpired returns true for expired token', () {
        final expiresOn = DateTime.now().subtract(const Duration(hours: 1));
        final token = AccessToken(token: 'expired', expiresOn: expiresOn);
        expect(token.isExpired, isTrue);
      });

      test('isExpired returns false for valid token', () {
        final expiresOn = DateTime.now().add(const Duration(hours: 1));
        final token = AccessToken(token: 'valid', expiresOn: expiresOn);
        expect(token.isExpired, isFalse);
      });

      test('isValid returns true for valid token', () {
        final expiresOn = DateTime.now().add(const Duration(hours: 1));
        final token = AccessToken(token: 'valid', expiresOn: expiresOn);
        expect(token.isValid, isTrue);
      });

      test('isValid returns false for expired token', () {
        final expiresOn = DateTime.now().subtract(const Duration(hours: 1));
        final token = AccessToken(token: 'expired', expiresOn: expiresOn);
        expect(token.isValid, isFalse);
      });
    });
  });
}
