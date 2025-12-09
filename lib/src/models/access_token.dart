/// Represents an access token for Azure Communication Services
class AccessToken {
  /// The token string
  final String token;

  /// The expiration time of the token
  final DateTime expiresOn;

  /// Creates a new [AccessToken] instance
  const AccessToken({
    required this.token,
    required this.expiresOn,
  });

  /// Creates an [AccessToken] from a map
  factory AccessToken.fromMap(Map<String, dynamic> map) {
    return AccessToken(
      token: map['token'] as String,
      expiresOn: DateTime.parse(map['expiresOn'] as String),
    );
  }

  /// Converts this [AccessToken] to a map
  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'expiresOn': expiresOn.toIso8601String(),
    };
  }

  /// Checks if the token is expired
  bool get isExpired => DateTime.now().isAfter(expiresOn);

  /// Checks if the token is valid (not expired)
  bool get isValid => !isExpired;

  @override
  String toString() =>
      'AccessToken(token: ${token.length > 10 ? token.substring(0, 10) : token}..., expiresOn: $expiresOn)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccessToken &&
        other.token == token &&
        other.expiresOn == expiresOn;
  }

  @override
  int get hashCode => token.hashCode ^ expiresOn.hashCode;
}
