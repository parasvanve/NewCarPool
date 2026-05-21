class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.rating,
    required this.isAdmin,
    required this.isActive,
    this.profileImagePath,
  });

  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? profileImagePath;
  final double rating;
  final bool isAdmin;
  final bool isActive;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phoneNumber: json['phoneNumber']?.toString() ?? '',
        profileImagePath: json['profileImagePath']?.toString(),
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        isAdmin: json['isAdmin'] == true,
        isActive: json['isActive'] == true,
      );
}
