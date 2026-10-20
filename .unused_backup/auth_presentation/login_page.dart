import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/demo/demo_data.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authProvider.notifier).login(_email.text, _pass.text);
  }

  void _fillDemo(DemoAccount a) {
    _email.text = a.email;
    _pass.text = a.password;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 34),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('HawuPay', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.text)),
                  const SizedBox(height: 4),
                  const Text('Kasir digital untuk UMKM', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: _hide,
                    decoration: InputDecoration(
                      labelText: 'Kata sandi',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                      child: const Text('Lupa kata sandi?'),
                    ),
                  ),
                  if (auth.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECDD3))),
                      child: Text(auth.error!, style: const TextStyle(color: Color(0xFFBE123C))),
                    ),
                  FilledButton(
                    onPressed: auth.loading ? null : _submit,
                    child: auth.loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Masuk'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                    child: const Text('Daftar toko baru'),
                  ),
                  if (ApiConstants.demoMode) ...[
                    const SizedBox(height: 28),
                    Row(children: const [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('AKUN DEMO', style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.muted))),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 12),
                    _DemoCard(icon: Icons.admin_panel_settings_outlined, title: 'Admin (Pengelola Sistem)', account: DemoData.admin, onTap: () => _fillDemo(DemoData.admin)),
                    const SizedBox(height: 10),
                    _DemoCard(icon: Icons.storefront_outlined, title: 'UMKM (Kasir & Toko)', account: DemoData.umkm, onTap: () => _fillDemo(DemoData.umkm)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.icon, required this.title, required this.account, required this.onTap});
  final IconData icon;
  final String title;
  final DemoAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                SelectableText('${account.email}  •  ${account.password}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}
