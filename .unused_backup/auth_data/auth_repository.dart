import 'dart:convert';
import '../../../core/config/api_constants.dart';
import '../../../core/demo/demo_data.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_models.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);
  final ApiClient _api;
  final TokenStorage _tokens;

  Future<AuthUser?> restore() async {
    final t = await _tokens.read();
    final u = await _tokens.readUser();
    if (t == null || u == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(u) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<AuthUser> login(String email, String password) async {
    // 1) Akun demo (tanpa backend)
    final demo = ApiConstants.demoMode ? DemoData.match(email, password) : null;
    if (demo != null) {
      final user = AuthUser(
        id: 'demo-${demo.role.name}',
        name: demo.name,
        email: demo.email,
        role: demo.role,
        storeName: demo.storeName,
      );
      await _tokens.save('demo-${demo.role.name}', jsonEncode(user.toJson()));
      return user;
    }

    // 2) Backend FastAPI. Respons yang diharapkan:
    //    {"access_token": "<jwt>", "user": {"id","name","email","role","store_name"}}
    //    Jika backend memakai OAuth2PasswordRequestForm, ubah menjadi form-urlencoded
    //    dengan field `username` & `password`.
    final res = await _api.post(ApiEndpoints.login, data: {'email': email.trim(), 'password': password});
    final data = Map<String, dynamic>.from(res.data as Map);
    final token = (data['access_token'] ?? data['token'])?.toString();
    if (token == null) throw Exception('Respons login tidak berisi token.');
    final user = AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    await _tokens.save(token, jsonEncode(user.toJson()));
    return user;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String storeName,
  }) async {
    await _api.post(ApiEndpoints.register, data: {
      'name': name,
      'email': email.trim(),
      'password': password,
      'store_name': storeName,
      'role': 'umkm',
    });
  }

  Future<void> forgotPassword(String email) =>
      _api.post(ApiEndpoints.forgotPassword, data: {'email': email.trim()});

  Future<void> logout() => _tokens.clear();
}
