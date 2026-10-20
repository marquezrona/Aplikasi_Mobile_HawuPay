import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';

import '../config/api_constants.dart';

class TokenStore {
  static const _key = 'jwt';
  static const _userKey = 'user';
  static const _deviceIdKey = 'device_id';
  final _s = const FlutterSecureStorage();
  Future<String?> read() => _s.read(key: _key);
  Future<void> save(String t) => _s.write(key: _key, value: t);

  Future<void> saveUser(Map<String, dynamic> user) =>
      _s.write(key: _userKey, value: jsonEncode(user));

  Future<Map<String, dynamic>?> readUser() async {
    final value = await _s.read(key: _userKey);
    if (value == null) return null;
    return jsonDecode(value) as Map<String, dynamic>;
  }

  Future<String> deviceId() async {
    final existing = await _s.read(key: _deviceIdKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final id =
        List.generate(20, (_) => random.nextInt(16).toRadixString(16)).join();
    final created = 'DEV-$id';
    await _s.write(key: _deviceIdKey, value: created);
    return created;
  }

  Future<void> clear() async {
    await _s.delete(key: _key);
    await _s.delete(key: _userKey);
  }
}

class ApiClient {
  ApiClient(this.tokens) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ))
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) async {
          final t = await tokens.read();
          if (t != null) o.headers['Authorization'] = 'Bearer $t';
          h.next(o);
        },
        onError: (e, h) async {
          if (e.response?.statusCode == 401) {
            await tokens.clear();
            onUnauthorized?.call();
          }
          h.next(e);
        },
      ));
  }

  final TokenStore tokens;
  late final Dio dio;
  void Function()? onUnauthorized;
}
