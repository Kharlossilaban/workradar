enum UserType { regular, vip }

enum AuthProvider { local, google }

class User {
  final String id;
  final String gmail;
  final String username;
  final String? profilePicture;
  final AuthProvider authProvider;
  final bool isVip;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.gmail,
    this.profilePicture,
    this.authProvider = AuthProvider.local,
    required this.isVip,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      gmail: json['gmail'] as String,
      profilePicture: json['profilePicture'] as String?,
      isVip: json['isVip'] as bool,
      authProvider: json['authProvider'] == 'google'
          ? AuthProvider.google
          : AuthProvider.local,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'gmail': gmail,
      'profilePicture': profilePicture,
      'isVip': isVip,
      'authProvider': authProvider == AuthProvider.google ? 'google' : 'local',
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? gmail,
    String? username,
    String? profilePicture,
    AuthProvider? authProvider,
    bool? isVip,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      gmail: gmail ?? this.gmail,
      username: username ?? this.username,
      profilePicture: profilePicture ?? this.profilePicture,
      authProvider: authProvider ?? this.authProvider,
      isVip: isVip ?? this.isVip,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
