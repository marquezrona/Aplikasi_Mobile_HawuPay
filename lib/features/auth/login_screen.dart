import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/config/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_widgets.dart';
import '../../providers.dart';
import 'auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(), _pw = TextEditingController();
  bool _loading = false, _hide = true;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await ref.read(authRepoProvider).login(_email.text, _pw.text);
      ref.read(userProvider.notifier).state = u;
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _apiError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.response == null) {
        return 'Tidak dapat terhubung ke server HawuPay.';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _forgotPassword() async {
    final email = TextEditingController(text: _email.text);
    final code = TextEditingController();
    final token = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    var step = 0;
    var busy = false;
    String? errorText;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, updateDialog) {
            Future<void> sendCode() async {
              if (email.text.trim().isEmpty) {
                updateDialog(
                    () => errorText = 'Masukkan email yang terdaftar.');
                return;
              }
              updateDialog(() {
                busy = true;
                errorText = null;
              });
              try {
                await ref.read(apiClientProvider).dio.post(
                  '/auth/password-reset/request',
                  data: {'email': email.text.trim()},
                );
                updateDialog(() => step = 1);
              } catch (error) {
                updateDialog(() => errorText = _apiError(error));
              } finally {
                updateDialog(() => busy = false);
              }
            }

            Future<void> verifyCode() async {
              if (code.text.trim().length != 6) {
                updateDialog(
                    () => errorText = 'Masukkan kode verifikasi 6 digit.');
                return;
              }
              updateDialog(() {
                busy = true;
                errorText = null;
              });
              try {
                await ref.read(apiClientProvider).dio.post(
                  '/auth/password-reset/verify-email',
                  data: {'email': email.text.trim(), 'code': code.text.trim()},
                );
                updateDialog(() => step = 2);
              } catch (error) {
                updateDialog(() => errorText = _apiError(error));
              } finally {
                updateDialog(() => busy = false);
              }
            }

            Future<void> completeReset() async {
              final entered = token.text.trim();
              final resetToken =
                  Uri.tryParse(entered)?.queryParameters['token'] ?? entered;
              if (password.text.length < 8) {
                updateDialog(() => errorText = 'Password minimal 8 karakter.');
                return;
              }
              if (password.text != confirmation.text) {
                updateDialog(
                    () => errorText = 'Konfirmasi password tidak sama.');
                return;
              }
              updateDialog(() {
                busy = true;
                errorText = null;
              });
              var completed = false;
              try {
                final response = await ref.read(apiClientProvider).dio.post(
                  '/auth/password-reset/complete',
                  data: {'token': resetToken, 'password': password.text},
                );
                if (!dialogContext.mounted) return;
                completed = true;
                Navigator.pop(dialogContext);
                _showResetResult(response.data['message']?.toString() ??
                    'Password berhasil diubah.');
              } catch (error) {
                updateDialog(() => errorText = _apiError(error));
              } finally {
                if (!completed && dialogContext.mounted) {
                  updateDialog(() => busy = false);
                }
              }
            }

            final fields = switch (step) {
              0 => <Widget>[
                  const Text(
                      'Masukkan email akun UMKM untuk meminta kode verifikasi.'),
                  TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email')),
                ],
              1 => <Widget>[
                  Text('Masukkan kode 6 digit yang dikirim ke ${email.text}.'),
                  TextField(
                      controller: code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration:
                          const InputDecoration(labelText: 'Kode verifikasi')),
                  TextButton(
                    onPressed: busy ? null : sendCode,
                    child: const Text('Kirim ulang kode'),
                  ),
                ],
              2 => <Widget>[
                  Text(
                      'Email sudah diverifikasi. Permintaan menunggu persetujuan admin. Setelah disetujui, tautan reset akan dikirim ke ${email.text}.'),
                  const SizedBox(height: 12),
                  const Text(
                      'Jika sudah menerima tautan reset, lanjutkan untuk memasukkan token dan password baru.'),
                ],
              _ => <Widget>[
                  const Text(
                      'Tempel tautan reset dari email atau tokennya, lalu buat password baru.'),
                  TextField(
                      controller: token,
                      decoration: const InputDecoration(
                          labelText: 'Tautan atau token reset')),
                  TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Password baru (min. 8 karakter)')),
                  TextField(
                      controller: confirmation,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Ulangi password')),
                ],
            };

            return AlertDialog(
              title: Text(switch (step) {
                0 => 'Lupa Password',
                1 => 'Verifikasi Email',
                2 => 'Menunggu Persetujuan',
                _ => 'Buat Password Baru',
              }),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...fields,
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(errorText!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Tutup'),
                ),
                if (step == 0)
                  FilledButton(
                    onPressed: busy ? null : sendCode,
                    child: Text(busy ? 'Mengirim...' : 'Kirim Kode'),
                  ),
                if (step == 1)
                  FilledButton(
                    onPressed: busy ? null : verifyCode,
                    child: Text(busy ? 'Memverifikasi...' : 'Verifikasi'),
                  ),
                if (step == 2)
                  FilledButton(
                    onPressed: () => updateDialog(() => step = 3),
                    child: const Text('Saya sudah menerima tautan'),
                  ),
                if (step == 3)
                  FilledButton(
                    onPressed: busy ? null : completeReset,
                    child: Text(busy ? 'Menyimpan...' : 'Simpan Password'),
                  ),
              ],
            );
          },
        ),
      );
    } finally {
      email.dispose();
      code.dispose();
      token.dispose();
      password.dispose();
      confirmation.dispose();
    }
  }

  void _showResetResult(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _fill(String email) {
    _email.text = email;
    _pw.text = AuthRepository.demoAccounts[email]!['pw']!;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            const TenunBrandBorder(),
            Expanded(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: HawuPayLogo(size: 88)),
                            const SizedBox(height: 14),
                            const Text('HawuPay',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: TW.navyDark,
                                    letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            const Text('Kasir digital untuk UMKM Sabu Raijua',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: TW.slate500)),
                            const SizedBox(height: 30),
                            TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration:
                                    const InputDecoration(labelText: 'Email')),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pw,
                              obscureText: _hide,
                              decoration: InputDecoration(
                                  labelText: 'Password',
                                  suffixIcon: IconButton(
                                      icon: Icon(_hide
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () =>
                                          setState(() => _hide = !_hide))),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                child: const Text('Lupa password?'),
                              ),
                            ),
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(_error!,
                                      style:
                                          const TextStyle(color: Colors.red))),
                            FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('Masuk')),
                            TextButton(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Pendaftaran Akun'),
                                  content: const Text(
                                    'Pendaftaran akun UMKM dikelola oleh administrator HawuPay. Silakan hubungi administrator untuk mendapatkan akun.',
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text('Tutup')),
                                  ],
                                ),
                              ),
                              child: const Text('Belum punya akun? Daftar'),
                            ),
                            if (ApiConstants.useDemoMode) ...[
                              const SizedBox(height: 16),
                              const Text(
                                  'Akun demo (ketuk untuk isi otomatis):',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: TW.slate500, fontSize: 12)),
                              Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  children: [
                                    ActionChip(
                                        label: const Text('Admin'),
                                        onPressed: () =>
                                            _fill('admin@hawupay.id')),
                                    ActionChip(
                                        label: const Text('Kasir UMKM'),
                                        onPressed: () =>
                                            _fill('kasir@hawupay.id')),
                                  ]),
                            ],
                          ]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
