class AuthSession {
  AuthSession({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String fullName;
  final String email;
  final String accessToken;
  final String refreshToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        userId: json['userId'],
        fullName: json['fullName'],
        email: json['email'],
        accessToken: json['accessToken'],
        refreshToken: json['refreshToken'],
      );
}
