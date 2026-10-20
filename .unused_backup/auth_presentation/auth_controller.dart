import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState(booting: true)) {
    _restore();
  }
  final AuthRepository _repo;

  Future<void> _restore() async => state = AuthState(user: await _repo.restore());

  Future<bool> login(String email, String password) async {
    state = const AuthState(loading: true);
    try {
      state = AuthState(user: await _repo.login(email, password));
      return true;
    } catch (e) {
      state = AuthState(error: ApiClient.message(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}
