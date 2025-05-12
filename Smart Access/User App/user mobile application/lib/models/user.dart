// lib/models/user.dart
class User {
  final int id;
  final String username;
  final String email;
  final String phoneNumber;
  final String fullName;
  final bool isAdmin;
  final bool isFrozen;
  final String? frozenAt;
  final int? company;
  final String? companyName;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.fullName,
    this.isAdmin = false,
    this.isFrozen = false,
    this.frozenAt,
    this.company,
    this.companyName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      fullName: json['full_name'],
      isAdmin: json['is_admin'] ?? false,
      isFrozen: json['is_frozen'] ?? false,
      frozenAt: json['frozen_at'],
      company: json['company'],
      companyName: json['company_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'is_admin': isAdmin,
      'is_frozen': isFrozen,
      'frozen_at': frozenAt,
      'company': company,
      'company_name': companyName,
    };
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, fullName: $fullName, company: $companyName)';
  }
}