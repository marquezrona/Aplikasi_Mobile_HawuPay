import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  Future<String?> read() => _s.read(key: _kToken);
  Future<String?> readUser() => _s.read(key: _kUser);

  Future<void> save(String token, String userJson) async {
    await _s.write(key: _kToken, value: token);
    await _s.write(key: _kUser, value: userJson);
  }

  Future<void> clear() async {
    await _s.delete(key: _kToken);
    await _s.delete(key: _kUser);
  }
}
