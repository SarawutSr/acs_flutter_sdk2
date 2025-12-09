import 'package:flutter/services.dart';
import '../models/communication_user.dart';
import '../models/access_token.dart';

/// Client for managing Azure Communication Services identity operations
///
/// This client provides methods for creating users and managing access tokens.
/// Note: In production applications, identity operations should be performed
/// server-side for security reasons.
class AcsIdentityClient {
  final MethodChannel _channel;

  /// Creates a new [AcsIdentityClient] instance
  ///
  /// [channel] is the method channel for communicating with native code
  AcsIdentityClient(this._channel);

  /// Initializes the identity client with a connection string
  ///
  /// [connectionString] is the Azure Communication Services connection string
  ///
  /// Note: This should only be used for development/testing. In production,
  /// use server-side identity management.
  ///
  /// Throws a [PlatformException] if initialization fails
  Future<void> initialize(String connectionString) async {
    try {
      await _channel.invokeMethod('initializeIdentity', {
        'connectionString': connectionString,
      });
    } on PlatformException catch (e) {
      throw AcsException(
        code: e.code,
        message: e.message ?? 'Failed to initialize identity client',
        details: e.details,
      );
    }
  }

  /// Creates a new communication user
  ///
  /// Returns a [CommunicationUser] representing the newly created user
  ///
  /// Note: This should be done server-side in production for security.
  /// Use your backend API to create users and return the user ID to your app.
  ///
  /// Throws an [AcsException] if user creation fails
  Future<CommunicationUser> createUser() async {
    try {
      final result = await _channel.invokeMethod('createUser');
      return CommunicationUser.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw AcsException(
        code: e.code,
        message: e.message ?? 'Failed to create user',
        details: e.details,
      );
    }
  }

  /// Gets an access token for a user
  ///
  /// [userId] is the ID of the user to get a token for
  /// [scopes] is a list of scopes to request for the token (e.g., ['voip', 'chat'])
  ///
  /// Returns an [AccessToken] that can be used to authenticate with ACS services
  ///
  /// Note: This should be done server-side in production for security.
  /// Use your backend API to generate tokens and return them to your app.
  ///
  /// Throws an [AcsException] if token generation fails
  Future<AccessToken> getToken(String userId, List<String> scopes) async {
    try {
      final result = await _channel.invokeMethod('getToken', {
        'userId': userId,
        'scopes': scopes,
      });
      return AccessToken.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw AcsException(
        code: e.code,
        message: e.message ?? 'Failed to get token',
        details: e.details,
      );
    }
  }

  /// Revokes an access token
  ///
  /// [userId] is the ID of the user whose token should be revoked
  ///
  /// Note: This should be done server-side in production.
  /// Use your backend API to revoke tokens.
  ///
  /// Throws an [AcsException] if token revocation fails
  Future<void> revokeToken(String userId) async {
    try {
      await _channel.invokeMethod('revokeToken', {
        'userId': userId,
      });
    } on PlatformException catch (e) {
      throw AcsException(
        code: e.code,
        message: e.message ?? 'Failed to revoke token',
        details: e.details,
      );
    }
  }
}

/// Exception thrown by Azure Communication Services operations
class AcsException implements Exception {
  /// Error code
  final String code;

  /// Error message
  final String message;

  /// Additional error details
  final dynamic details;

  /// Creates a new [AcsException]
  const AcsException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() =>
      'AcsException($code): $message${details != null ? ' - $details' : ''}';
}
