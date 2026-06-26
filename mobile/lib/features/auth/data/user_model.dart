/// User model — mirrors backend UserResource.
class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.tenantId,
    this.tenantName,
    this.tenantLogoUrl,
    this.lastLoginAt,
  });

  final int id;
  final String name;
  final String email;
  final String role; // super_admin | owner | operator
  final bool isActive;
  final int? tenantId;
  final String? tenantName;
  final String? tenantLogoUrl;
  final DateTime? lastLoginAt;

  bool get isOwner => role == 'owner';
  bool get isOperator => role == 'operator';
  bool get isSuperAdmin => role == 'super_admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'];
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
      tenantId: json['tenant_id'] as int?,
      tenantName: tenant is Map ? tenant['name'] as String? : null,
      tenantLogoUrl: tenant is Map ? tenant['logo_url'] as String? : null,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'] as String)
          : null,
    );
  }
}
