import '../../core/config/api_constants.dart';
import '../../core/network/api_client.dart';
import 'package:dio/dio.dart';

class AppUser {
  AppUser(this.name, this.email, this.role, {this.id, this.umkmId});
  final String name, email, role; // role: 'admin' | 'umkm'
  final String? id;
  final String? umkmId;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        json['name']?.toString() ?? '',
        json['email']?.toString() ?? '',
        json['role']?.toString() ?? 'umkm',
        id: json['id']?.toString(),
        umkmId: json['umkm_id']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'umkm_id': umkmId,
      };
}

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  // Akun demo (aktif saat DEMO=true, tanpa backend)
  static const demoAccounts = {
    'admin@hawupay.id': {
      'pw': 'Admin123!',
      'role': 'admin',
      'name': 'Admin HawuPay'
    },
    'kasir@hawupay.id': {
      'pw': 'Kasir123!',
      'role': 'umkm',
      'name': 'Toko Hawu Jaya'
    },
  };

  Future<AppUser> login(String email, String password) async {
    if (ApiConstants.useDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final a = demoAccounts[email.trim().toLowerCase()];
      if (a == null || a['pw'] != password) {
        throw Exception('Email atau password salah');
      }
      await _api.tokens.save('demo-token');
      final user = AppUser(a['name']!, email, a['role']!);
      await _api.tokens.saveUser(user.toJson());
      return user;
    }
    final r = await _api.dio
        .post('/auth/login', data: {'email': email, 'password': password});
    final token = (r.data['token'] ?? r.data['access_token'])?.toString();
    if (token == null) {
      throw Exception('Server tidak mengembalikan token masuk');
    }
    await _api.tokens.save(token);
    final u = r.data['user'] as Map<String, dynamic>;
    final user = AppUser.fromJson({...u, 'name': u['name'] ?? email});
    await _api.tokens.saveUser(user.toJson());
    return user;
  }

  Future<void> logout() async {
    try {
      if (!ApiConstants.useDemoMode && await _api.tokens.read() != null) {
        await _api.dio.post('/auth/logout');
      }
    } finally {
      await _api.tokens.clear();
    }
  }

  Future<AppUser?> restoreSession() async {
    final token = await _api.tokens.read();
    if (token == null) return null;
    if (ApiConstants.useDemoMode) {
      final saved = await _api.tokens.readUser();
      return saved == null ? null : AppUser.fromJson(saved);
    }
    try {
      final response = await _api.dio.get('/auth/me');
      final user = AppUser.fromJson(response.data as Map<String, dynamic>);
      await _api.tokens.saveUser(user.toJson());
      return user;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) return null;
      final saved = await _api.tokens.readUser();
      return saved == null ? null : AppUser.fromJson(saved);
    }
  }
}
