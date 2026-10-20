import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/workspace/mobile_workspace_screen.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await Hive.initFlutter();
  final container = ProviderContainer();
  container.read(apiClientProvider).onUnauthorized = () {
    container.read(userProvider.notifier).state = null;
  };
  await container.read(syncProvider).init();
  final restoredUser = await container.read(authRepoProvider).restoreSession();
  container.read(userProvider.notifier).state = restoredUser;
  runApp(UncontrolledProviderScope(
      container: container, child: const HawuPayApp()));
}

class HawuPayApp extends ConsumerWidget {
  const HawuPayApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    return MaterialApp(
      title: 'HawuPay',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: user == null ? const LoginScreen() : const MobileWorkspaceScreen(),
    );
  }
}
