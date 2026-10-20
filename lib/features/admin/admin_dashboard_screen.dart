import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/websocket_client.dart';
import '../../core/theme/app_theme.dart';
import '../../providers.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminState();
}

class _AdminState extends ConsumerState<AdminDashboardScreen> {
  final List<RealtimeEvent> _feed = [];
  int _volume = 12850000, _txCount = 342;
  final List<String> _pending = ['Kopi Gayo 250g · Kopi Kupang', 'Tenun Ikat Sumba · Warung Sari', 'Keripik Pisang · Toko Hawu Jaya'];

  @override
  void initState() {
    super.initState();
    ref.read(wsProvider).events.listen((e) {
      if (!mounted) return;
      setState(() {
        _feed.insert(0, e);
        if (_feed.length > 20) _feed.removeLast();
        if (e.type == 'transaction.created') {
          _txCount++;
          _volume += (e.data['total'] as num).toInt();
        }
      });
    });
  }

  Widget _stat(String label, String value, IconData icon, Color c) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: c),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: const TextStyle(color: TW.slate500, fontSize: 12)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Admin', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: () async {
              await ref.read(authRepoProvider).logout();
              ref.read(userProvider.notifier).state = null;
            }),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            _stat('UMKM Aktif', '58', Icons.store, TW.indigo),
            const SizedBox(width: 12),
            _stat('Transaksi', '$_txCount', Icons.receipt_long, TW.emerald),
          ]),
          const SizedBox(height: 12),
          Row(children: [_stat('Volume Global', _rp.format(_volume), Icons.payments, TW.amber)]),
          const SizedBox(height: 20),
          Text('Persetujuan Produk (${_pending.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          if (_pending.isEmpty) const Text('Tidak ada pengajuan.', style: TextStyle(color: TW.slate500)),
          for (final p in List.of(_pending))
            Card(
              child: ListTile(
                title: Text(p, style: const TextStyle(fontSize: 14)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _pending.remove(p))),
                  IconButton(icon: const Icon(Icons.check_circle, color: TW.emerald), onPressed: () => setState(() => _pending.remove(p))), // TODO: PATCH /api/products/{id}/approve
                ]),
              ),
            ),
          const SizedBox(height: 20),
          const Row(children: [
            Text('Monitoring Real-time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            SizedBox(width: 8),
            Icon(Icons.circle, size: 10, color: TW.emerald),
          ]),
          const SizedBox(height: 8),
          if (_feed.isEmpty) const Text('Menunggu event...', style: TextStyle(color: TW.slate500)),
          for (final e in _feed)
            Card(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.bolt, color: TW.indigo),
                title: Text(e.type == 'transaction.created' ? '${e.data['store']} · ${_rp.format(e.data['total'])}' : e.type),
                subtitle: Text(e.data['method']?.toString() ?? ''),
              ),
            ),
        ]),
      );
}
