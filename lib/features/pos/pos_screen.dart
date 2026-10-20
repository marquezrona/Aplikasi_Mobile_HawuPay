import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosState();
}

class _PosState extends ConsumerState<PosScreen> {
  static const products = [
    {'id': 'p1', 'name': 'Kopi Susu', 'price': 15000},
    {'id': 'p2', 'name': 'Es Teh Manis', 'price': 6000},
    {'id': 'p3', 'name': 'Nasi Goreng', 'price': 22000},
    {'id': 'p4', 'name': 'Mie Ayam', 'price': 18000},
    {'id': 'p5', 'name': 'Roti Bakar', 'price': 12000},
    {'id': 'p6', 'name': 'Jeruk Peras', 'price': 10000},
  ];
  String _q = '';
  final Map<String, int> _cart = {};

  Map<String, Object> _p(String id) => products.firstWhere((p) => p['id'] == id);
  int get _total => _cart.entries.fold(0, (s, e) => s + (_p(e.key)['price'] as int) * e.value);

  Future<void> _pay(String method) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Bayar via $method'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(method == 'QRIS' ? Icons.qr_code_2 : Icons.nfc, size: 140, color: TW.indigo),
          Text(method == 'QRIS' ? 'Scan QR untuk membayar' : 'Tempelkan kartu / HP ke perangkat', style: const TextStyle(color: TW.slate500)),
          const SizedBox(height: 8),
          Text(_rp.format(_total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(120, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('Simulasi Sukses')),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await ref.read(syncProvider).submit({
      'method': method,
      'total': _total,
      'items': _cart.entries.map((e) => {'product_id': e.key, 'qty': e.value}).toList(),
      'created_at': DateTime.now().toIso8601String(),
    });
    setState(() => _cart.clear());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sent ? 'Transaksi berhasil' : 'Offline: transaksi masuk antrean, akan disinkronkan otomatis')));
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    final user = ref.watch(userProvider)!;
    final list = products.where((p) => (p['name'] as String).toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          ValueListenableBuilder2(
            a: sync.online, b: sync.pending,
            builder: (on, n) => Chip(
              avatar: Icon(on ? Icons.wifi : Icons.wifi_off, size: 16, color: on ? TW.emerald : TW.amber),
              label: Text(on ? (n > 0 ? 'Sinkron $n...' : 'Online') : 'Offline · $n antre'),
            ),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await ref.read(authRepoProvider).logout();
            ref.read(userProvider.notifier).state = null;
          }),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Cari produk...', prefixIcon: Icon(Icons.search))),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              final qty = _cart[p['id']] ?? 0;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _cart[p['id'] as String] = qty + 1),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Icon(Icons.fastfood, color: TW.indigo),
                        if (qty > 0) CircleAvatar(radius: 12, backgroundColor: TW.indigo, child: Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 12))),
                      ]),
                      const Spacer(),
                      Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(_rp.format(p['price']), style: const TextStyle(color: TW.slate500)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: TW.slate200))),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total (${_cart.values.fold(0, (a, b) => a + b)} item)', style: const TextStyle(color: TW.slate500)),
                Text(_rp.format(_total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: _total == 0 ? null : () => _pay('QRIS'), icon: const Icon(Icons.qr_code_2), label: const Text('QRIS'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: TW.slate900), onPressed: _total == 0 ? null : () => _pay('NFC'), icon: const Icon(Icons.nfc), label: const Text('NFC'))),
              ]),
              if (_cart.isNotEmpty) TextButton(onPressed: () => setState(_cart.clear), child: const Text('Kosongkan keranjang')),
            ]),
          ),
        ),
      ]),
    );
  }
}

class ValueListenableBuilder2 extends StatelessWidget {
  const ValueListenableBuilder2({super.key, required this.a, required this.b, required this.builder});
  final ValueNotifier<bool> a;
  final ValueNotifier<int> b;
  final Widget Function(bool, int) builder;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
      valueListenable: a, builder: (_, on, __) => ValueListenableBuilder<int>(valueListenable: b, builder: (_, n, __) => builder(on, n)));
}
