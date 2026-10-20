enum UserRole { admin, umkm }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.storeName,
  });

  final String id, name, email;
  final UserRole role;
  final String? storeName;

  bool get isDemo => id.startsWith('demo-');

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: '${j['id']}',
        name: '${j['name'] ?? j['full_name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        role: '${j['role']}'.toLowerCase() == 'admin' ? UserRole.admin : UserRole.umkm,
        storeName: (j['store_name'] ?? j['storeName']) as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'store_name': storeName,
      };
}

class AuthState {
  const AuthState({this.user, this.loading = false, this.booting = false, this.error});
  final AuthUser? user;
  final bool loading, booting;
  final String? error;
}
