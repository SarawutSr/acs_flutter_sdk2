/// Represents a user in Azure Communication Services
class CommunicationUser {
  /// The unique identifier for the user
  final String id;

  /// Creates a new [CommunicationUser] instance
  const CommunicationUser({required this.id});

  /// Creates a [CommunicationUser] from a map
  factory CommunicationUser.fromMap(Map<String, dynamic> map) {
    return CommunicationUser(
      id: map['id'] as String,
    );
  }

  /// Converts this [CommunicationUser] to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }

  @override
  String toString() => 'CommunicationUser(id: $id)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommunicationUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
