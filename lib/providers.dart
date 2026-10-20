import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/api_client.dart';
import 'core/network/websocket_client.dart';
import 'core/sync/offline_sync_service.dart';
import 'features/auth/auth_repository.dart';

final tokenStoreProvider = Provider((_) => TokenStore());
final apiClientProvider = Provider((r) => ApiClient(r.read(tokenStoreProvider)));
final authRepoProvider = Provider((r) => AuthRepository(r.read(apiClientProvider)));
final syncProvider = Provider((r) {
  final s = OfflineSyncService(r.read(apiClientProvider));
  r.onDispose(s.dispose);
  return s;
});
final wsProvider = Provider((r) {
  final c = WebSocketClient(r.read(tokenStoreProvider));
  r.onDispose(c.dispose);
  return c;
});
final userProvider = StateProvider<AppUser?>((_) => null);
