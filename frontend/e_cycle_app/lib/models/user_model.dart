class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final int rewardPoints;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    this.rewardPoints = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? 'user').toString(),
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
    );
  }
}
