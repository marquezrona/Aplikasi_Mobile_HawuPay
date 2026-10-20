import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_widgets.dart';
import '../../providers.dart';
import '../auth/auth_repository.dart';

enum _Page {
  dashboard,
  pos,
  products,
  customers,
  transactions,
  reports,
  storeSettings,
  admins,
  umkms,
  umkmProducts,
  approvals,
  passwordResets,
  settlement,
  audit,
  adminSettings,
}

class _MenuItem {
  const _MenuItem(this.page, this.label, this.icon);
  final _Page page;
  final String label;
  final IconData icon;
}

class _FormField {
  const _FormField(this.key, this.label,
      {this.number = false, this.password = false});
  final String key;
  final String label;
  final bool number;
  final bool password;
}

class MobileWorkspaceScreen extends ConsumerStatefulWidget {
  const MobileWorkspaceScreen({super.key});

  @override
  ConsumerState<MobileWorkspaceScreen> createState() => _MobileWorkspaceState();
}

class _MobileWorkspaceState extends ConsumerState<MobileWorkspaceScreen> {
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static const _umkmMenu = [
    _MenuItem(_Page.dashboard, 'Dashboard', Icons.dashboard_outlined),
    _MenuItem(_Page.pos, 'Kasir', Icons.point_of_sale_outlined),
    _MenuItem(_Page.products, 'Produk', Icons.inventory_2_outlined),
    _MenuItem(_Page.customers, 'Pelanggan', Icons.people_outline),
    _MenuItem(_Page.transactions, 'Transaksi', Icons.receipt_long_outlined),
    _MenuItem(_Page.reports, 'Laporan', Icons.bar_chart_outlined),
    _MenuItem(
        _Page.storeSettings, 'Pengaturan Toko', Icons.storefront_outlined),
  ];
  static const _adminMenu = [
    _MenuItem(_Page.dashboard, 'Dashboard', Icons.dashboard_outlined),
    _MenuItem(_Page.admins, 'Akun Admin', Icons.admin_panel_settings_outlined),
    _MenuItem(_Page.umkms, 'UMKM', Icons.store_outlined),
    _MenuItem(_Page.approvals, 'Persetujuan Produk', Icons.fact_check_outlined),
    _MenuItem(_Page.passwordResets, 'Reset Password', Icons.password_outlined),
    _MenuItem(_Page.transactions, 'Transaksi', Icons.receipt_long_outlined),
    _MenuItem(_Page.settlement, 'Settlement', Icons.account_balance_outlined),
    _MenuItem(_Page.audit, 'Audit Log', Icons.history_outlined),
    _MenuItem(_Page.adminSettings, 'Pengaturan Admin', Icons.settings_outlined),
  ];

  _Page _page = _Page.dashboard;
  dynamic _data;
  String? _error;
  bool _loading = false;
  bool _submitting = false;
  String _query = '';
  String _period = 'daily';
  String? _umkmId;
  String? _umkmName;
  StreamSubscription? _eventSubscription;
  final Map<String, int> _cart = {};

  AppUser get _user => ref.read(userProvider)!;
  bool get _isAdmin => _user.role == 'admin';
  List<_MenuItem> get _menu => _isAdmin ? _adminMenu : _umkmMenu;
  String get _title => _page == _Page.umkmProducts
      ? 'Produk · ${_umkmName ?? 'UMKM'}'
      : _menu
          .firstWhere((item) => item.page == _page,
              orElse: () => _adminMenu.first)
          .label;

  List<_MenuItem> get _bottomMenuItems => _isAdmin
      ? const [
          _MenuItem(_Page.dashboard, 'Dashboard', Icons.dashboard_outlined),
          _MenuItem(
              _Page.admins, 'Akun Admin', Icons.admin_panel_settings_outlined),
          _MenuItem(_Page.umkms, 'UMKM', Icons.store_outlined),
          _MenuItem(_Page.approvals, 'Persetujuan', Icons.fact_check_outlined),
        ]
      : const [
          _MenuItem(_Page.dashboard, 'Dashboard', Icons.dashboard_outlined),
          _MenuItem(_Page.customers, 'Pelanggan', Icons.people_outline),
          _MenuItem(_Page.products, 'Produk', Icons.inventory_2_outlined),
          _MenuItem(
              _Page.transactions, 'Transaksi', Icons.receipt_long_outlined),
        ];

  @override
  void initState() {
    super.initState();
    final websocket = ref.read(wsProvider);
    websocket.connect();
    _eventSubscription = websocket.events.listen((event) {
      if (!mounted) return;
      if (event.type == 'transaction' ||
          event.type == 'transaction.created' ||
          event.type == 'stock.updated') {
        _load();
      }
    });
    ref.read(syncProvider).flush();
    _load();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final detail = error.response?.data;
      if (detail is Map && detail['detail'] != null) {
        return detail['detail'].toString();
      }
      if (error.response == null) {
        return 'Tidak dapat terhubung ke server HawuPay. Periksa jaringan dan alamat API.';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    final response =
        await ref.read(apiClientProvider).dio.get(path, queryParameters: query);
    return response.data;
  }

  Future<dynamic> _post(String path, {Object? data}) async =>
      (await ref.read(apiClientProvider).dio.post(path, data: data)).data;

  Future<dynamic> _put(String path, {Object? data}) async =>
      (await ref.read(apiClientProvider).dio.put(path, data: data)).data;

  Future<dynamic> _patch(String path, {Object? data}) async =>
      (await ref.read(apiClientProvider).dio.patch(path, data: data)).data;

  Future<void> _delete(String path) async {
    await ref.read(apiClientProvider).dio.delete(path);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      dynamic result;
      switch (_page) {
        case _Page.dashboard:
          result =
              await _get(_isAdmin ? '/admin/dashboard' : '/umkm/dashboard');
        case _Page.pos:
          result = await _loadPosProducts();
        case _Page.products:
          result = await _get('/umkm/products');
        case _Page.customers:
          result = await _get('/umkm/customers');
        case _Page.transactions:
          result = await _get(
              _isAdmin ? '/admin/transactions' : '/umkm/transactions');
        case _Page.reports:
          result = await _get('/umkm/reports', query: {'period': _period});
        case _Page.storeSettings:
          result = await _get('/umkm/settings');
        case _Page.admins:
          result = await _get('/admin/admins');
        case _Page.umkms:
          result = await _get('/admin/umkms');
        case _Page.umkmProducts:
          result = await _get('/admin/umkms/$_umkmId/products');
        case _Page.approvals:
          result = await _get('/admin/products', query: {'status': 'PENDING'});
        case _Page.passwordResets:
          result = await _get('/admin/password-reset-requests');
        case _Page.settlement:
          result = await _get('/admin/settlement');
        case _Page.audit:
          result = await _get('/admin/audit-logs');
        case _Page.adminSettings:
          result = _user.toJson();
      }
      if (mounted) setState(() => _data = result);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<dynamic>> _loadPosProducts() async {
    try {
      final result =
          await _get('/umkm/products', query: {'approved_only': true}) as List;
      final box = await Hive.openBox<String>('mobile_cache');
      await box.put('approved_products', jsonEncode(result));
      return result;
    } on DioException {
      final box = await Hive.openBox<String>('mobile_cache');
      final cached = box.get('approved_products');
      if (cached == null) rethrow;
      return jsonDecode(cached) as List<dynamic>;
    }
  }

  Future<void> _selectPage(_Page page) async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _page = page;
      _query = '';
      _cart.clear();
      _data = null;
    });
    await _load();
  }

  Future<void> _logout() async {
    try {
      await ref.read(authRepoProvider).logout();
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    } finally {
      ref.read(userProvider.notifier).state = null;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade700 : null,
    ));
  }

  Future<Map<String, dynamic>?> _editForm(
    String title,
    List<_FormField> fields, {
    Map<String, dynamic> initial = const {},
  }) async {
    final controllers = <String, TextEditingController>{
      for (final field in fields)
        field.key:
            TextEditingController(text: initial[field.key]?.toString() ?? ''),
    };
    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[field.key],
                      obscureText: field.password,
                      keyboardType: field.number
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: field.label),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final values = <String, dynamic>{};
                for (final field in fields) {
                  final text = controllers[field.key]!.text.trim();
                  if (field.number) {
                    values[field.key] = num.tryParse(text) ?? 0;
                  } else {
                    values[field.key] = text;
                  }
                }
                Navigator.pop(dialogContext, values);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Lanjutkan')),
          ],
        ),
      ) ==
      true;

  Future<void> _runAction(Future<void> Function() action,
      {String? success}) async {
    try {
      await action();
      if (success != null && mounted) _showMessage(success);
      await _load();
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    }
  }

  Future<void> _createProduct([Map<String, dynamic>? product]) async {
    final fields = [
      const _FormField('name', 'Nama produk'),
      const _FormField('category', 'Kategori'),
      const _FormField('price', 'Harga', number: true),
      const _FormField('stock', 'Stok', number: true),
      const _FormField('description', 'Deskripsi'),
    ];
    final values = await _editForm(
      product == null ? 'Tambah Produk' : 'Edit Produk',
      fields,
      initial: product ?? {'category': 'Umum', 'stock': 0},
    );
    if (values == null) return;
    final body = {...values, 'image': product?['image']};
    await _runAction(
      () async {
        if (product == null) {
          await _post('/umkm/products', data: body);
        } else {
          await _put('/umkm/products/${product['id']}', data: body);
        }
      },
      success:
          product == null ? 'Pengajuan produk dikirim' : 'Produk diperbarui',
    );
  }

  Future<void> _createCustomer([Map<String, dynamic>? customer]) async {
    final values = await _editForm(
      customer == null ? 'Tambah Pelanggan' : 'Edit Pelanggan',
      const [
        _FormField('name', 'Nama'),
        _FormField('phone', 'Telepon'),
        _FormField('nfc_card_id', 'ID Kartu NFC'),
        _FormField('balance', 'Saldo (Rp)', number: true),
      ],
      initial: customer ?? {'balance': 0},
    );
    if (values == null) return;
    if ((values['nfc_card_id'] as String).isEmpty) values['nfc_card_id'] = null;
    await _runAction(
      () async {
        if (customer == null) {
          await _post('/umkm/customers', data: values);
        } else {
          await _put('/umkm/customers/${customer['id']}', data: values);
        }
      },
      success: 'Data pelanggan disimpan',
    );
  }

  Future<void> _createUmkm() async {
    final values = await _editForm('Tambah UMKM', const [
      _FormField('store_name', 'Nama toko'),
      _FormField('email', 'Email login'),
      _FormField('password', 'Password awal', password: true),
      _FormField('address', 'Alamat'),
      _FormField('phone', 'Telepon'),
      _FormField('bank_name', 'Bank (BRI / Bank NTT / DANA)'),
      _FormField('bank_account_number', 'Nomor rekening / HP'),
      _FormField('bank_account_name', 'Nama pemilik rekening'),
    ]);
    if (values == null) return;
    for (final key in [
      'bank_name',
      'bank_account_number',
      'bank_account_name'
    ]) {
      if ((values[key] as String).isEmpty) values[key] = null;
    }
    await _runAction(
      () async => _post('/admin/umkms', data: values),
      success: 'UMKM berhasil ditambahkan',
    );
  }

  Future<void> _createAdmin() async {
    final values = await _editForm('Tambah Admin', const [
      _FormField('name', 'Nama'),
      _FormField('email', 'Email'),
      _FormField('password', 'Password (min. 8 karakter)', password: true),
    ]);
    if (values == null) return;
    await _runAction(
      () async => _post('/admin/admins', data: values),
      success: 'Akun admin ditambahkan',
    );
  }

  Future<void> _submitCheckout(String paymentMethod) async {
    final products = (_data as List).cast<Map<String, dynamic>>();
    final selected = products.where((p) => (_cart[p['id']] ?? 0) > 0).toList();
    if (selected.isEmpty) return;
    String? cardId;
    String? customerId;
    if (paymentMethod == 'NFC') {
      final input = await _editForm('Pembayaran NFC', const [
        _FormField('card_id', 'ID kartu pelanggan'),
      ]);
      if (input == null || (input['card_id'] as String).isEmpty) return;
      try {
        final customer = await _get(
          '/umkm/customers/by-card/${Uri.encodeComponent(input['card_id'] as String)}',
        ) as Map<String, dynamic>;
        if ((customer['balance'] as num) < _cartTotal(products)) {
          _showMessage('Saldo kartu tidak cukup.', isError: true);
          return;
        }
        cardId = input['card_id'] as String;
        customerId = customer['id'] as String;
        final accepted = await _confirm(
          'Konfirmasi pembayaran NFC',
          '${customer['name']} · saldo ${_money(customer['balance'])}. Potong ${_money(_cartTotal(products))} dari saldo kartu?',
        );
        if (!accepted) return;
      } catch (error) {
        _showMessage(_errorMessage(error), isError: true);
        return;
      }
    } else {
      final accepted = await _confirm(
        'Pembayaran QRIS (simulasi)',
        'Website saat ini menggunakan simulasi QRIS, bukan QRIS dari penyedia pembayaran. Tandai transaksi ${_money(_cartTotal(products))} sebagai dibayar?',
      );
      if (!accepted) return;
    }

    setState(() => _submitting = true);
    try {
      final total = _cartTotal(products);
      final online = ref.read(syncProvider).online.value;
      final transaction = <String, dynamic>{
        'client_txn_id': 'tx-${DateTime.now().microsecondsSinceEpoch}',
        'items': selected
            .map((product) => {
                  'product_id': product['id'],
                  'name': product['name'],
                  'price': product['price'],
                  'qty': _cart[product['id']],
                })
            .toList(),
        'subtotal': total,
        'discount': 0,
        'total': total,
        'payment_method': paymentMethod,
        'customer_id': customerId,
        'nfc_card_id': cardId,
        'created_at_client': DateTime.now().toUtc().toIso8601String(),
        'offline': !online,
      };
      final sent = await ref.read(syncProvider).submit(transaction);
      if (!mounted) return;
      setState(_cart.clear);
      _showMessage(sent
          ? 'Transaksi tersimpan di HawuPay.'
          : 'Transaksi tersimpan offline dan akan disinkronkan saat terhubung.');
      await _load();
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  int _cartTotal(List<Map<String, dynamic>> products) =>
      products.fold<int>(0, (sum, product) {
        final qty = _cart[product['id']] ?? 0;
        return sum + ((product['price'] as num).toInt() * qty);
      });

  String _money(Object? value) => _currency.format(value is num ? value : 0);

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const HawuPayLogo(size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'HawuPay',
                    style: TextStyle(
                      color: TW.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TW.navyDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(6),
          child: TenunBrandBorder(),
        ),
        actions: [
          ValueListenableBuilder2(
            online: sync.online,
            pending: sync.pending,
            builder: (online, pending) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: Chip(
                  avatar: Icon(
                    online
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    size: 16,
                    color: online ? TW.emerald : TW.amber,
                  ),
                  label: Text(pending > 0
                      ? '$pending antre'
                      : online
                          ? 'Online'
                          : 'Offline'),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: _drawer(),
      body: _body(),
      bottomNavigationBar: _bottomNavigationBar(),
    );
  }

  Widget _bottomNavigationBar() {
    final items = _bottomMenuItems;
    final selectedIndex = items.indexWhere((item) => item.page == _page);
    return BottomNavigationBar(
      currentIndex: selectedIndex < 0 ? items.length : selectedIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: TW.navy,
      unselectedItemColor: TW.slate500,
      selectedFontSize: 10,
      unselectedFontSize: 9,
      iconSize: 20,
      items: [
        for (final item in items)
          BottomNavigationBarItem(
            icon: Icon(item.icon),
            label: item.label,
          ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          label: 'Lainnya',
        ),
      ],
      onTap: (index) {
        if (index == items.length) {
          _showMoreMenu();
        } else {
          _selectPage(items[index].page);
        }
      },
    );
  }

  Future<void> _showMoreMenu() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          final primaryPages =
              _bottomMenuItems.map((item) => item.page).toSet();
          final moreItems =
              _menu.where((item) => !primaryPages.contains(item.page)).toList();
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Menu lainnya',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final item in moreItems)
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    selected: item.page == _page,
                    onTap: () => _selectPage(item.page),
                  ),
                ListTile(
                  leading: const Icon(Icons.logout, color: TW.terracotta),
                  title: const Text('Keluar'),
                  onTap: _logout,
                ),
              ],
            ),
          );
        },
      );

  Widget _drawer() => Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                color: TW.navy,
                child: Row(
                  children: [
                    const HawuPayLogo(size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HawuPay',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            _isAdmin
                                ? 'Sabu Raijua · Admin'
                                : 'Sabu Raijua · UMKM',
                            style: const TextStyle(color: Color(0xFFE8EDF3)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const TenunBrandBorder(height: 5),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE7EEF5),
                  foregroundColor: TW.navy,
                  child: Icon(Icons.person_outline),
                ),
                title: Text(_user.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_user.email,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in _menu)
                      ListTile(
                        selected: item.page == _page,
                        selectedTileColor: const Color(0xFFE7EEF5),
                        iconColor: TW.slate500,
                        selectedColor: TW.navy,
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        onTap: () => _selectPage(item.page),
                      ),
                    if (_page == _Page.umkmProducts)
                      ListTile(
                        leading: const Icon(Icons.arrow_back),
                        title: const Text('Kembali ke UMKM'),
                        onTap: () => _selectPage(_Page.umkms),
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Keluar'),
                onTap: _logout,
              ),
            ],
          ),
        ),
      );

  Widget _body() {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 48, color: TW.slate500),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }
    if (_data == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child:
                    Text(_error!, style: TextStyle(color: Colors.red.shade900)),
              ),
            ),
          if (ref.watch(syncProvider).lastError.value != null)
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Sinkronisasi tertunda: ${ref.watch(syncProvider).lastError.value}',
                  style: TextStyle(color: Colors.brown.shade800),
                ),
              ),
            ),
          _pageBody(),
        ],
      ),
    );
  }

  Widget _pageBody() {
    switch (_page) {
      case _Page.dashboard:
        return _dashboard();
      case _Page.pos:
        return _pos();
      case _Page.products:
        return _products();
      case _Page.customers:
        return _customers();
      case _Page.transactions:
        return _transactions();
      case _Page.reports:
        return _reports();
      case _Page.storeSettings:
        return _storeSettings();
      case _Page.admins:
        return _admins();
      case _Page.umkms:
        return _umkms();
      case _Page.umkmProducts:
        return _umkmProducts();
      case _Page.approvals:
        return _approvals();
      case _Page.passwordResets:
        return _passwordResets();
      case _Page.settlement:
        return _settlement();
      case _Page.audit:
        return _audit();
      case _Page.adminSettings:
        return _adminSettings();
    }
  }

  Widget _dashboard() {
    final data = _data as Map<String, dynamic>;
    final stats = _isAdmin
        ? <(String, Object?, IconData)>[
            ('Total UMKM', data['total_umkms'], Icons.store_outlined),
            ('UMKM aktif', data['active_umkms'], Icons.storefront_outlined),
            (
              'Transaksi hari ini',
              data['txn_count_today'],
              Icons.receipt_long_outlined
            ),
            (
              'Nilai hari ini',
              _money(data['txn_total_today']),
              Icons.payments_outlined
            ),
            (
              'Saldo toko',
              _money(data['total_balance']),
              Icons.account_balance_wallet_outlined
            ),
            ('Transaksi QRIS', data['qris_count'], Icons.qr_code_2),
            ('Transaksi NFC', data['nfc_count'], Icons.nfc),
          ]
        : <(String, Object?, IconData)>[
            (
              'Penjualan hari ini',
              _money(data['txn_total_today']),
              Icons.trending_up
            ),
            (
              'Transaksi hari ini',
              data['txn_count_today'],
              Icons.receipt_long_outlined
            ),
            (
              'Saldo toko',
              _money(data['balance']),
              Icons.account_balance_wallet_outlined
            ),
            (
              'Menunggu sinkron',
              data['pending_sync'],
              Icons.cloud_upload_outlined
            ),
            ('Transaksi QRIS', data['qris_count'], Icons.qr_code_2),
            ('Transaksi NFC', data['nfc_count'], Icons.nfc),
          ];
    final statsGrid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stat.$1.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.5,
                          color: TW.slate500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${stat.$2 ?? 0}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE7EEF5),
                  foregroundColor: TW.navy,
                  child: Icon(stat.$3, size: 19),
                ),
              ],
            ),
          ),
        );
      },
    );
    final series = (data['series'] as List? ?? []).cast<Map<String, dynamic>>();
    final recent = (data['recent_transactions'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final top = (data[_isAdmin ? 'top_umkms' : 'top_products'] as List? ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isAdmin)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              data['store_name']?.toString() ?? _user.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        statsGrid,
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeading('Grafik Transaksi 7 Hari'),
                if (series.isEmpty)
                  const SizedBox(
                    height: 180,
                    child: Center(child: Text('Belum ada data transaksi.')),
                  )
                else
                  SizedBox(
                    height: 210,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _DashboardChartPainter(series),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!_isAdmin) ...[
          const SizedBox(height: 12),
          _topRankingSection('Produk Terlaris Hari Ini', top),
        ],
        if (_isAdmin) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeading('Transaksi Terbaru (Real-time)'),
                  if (recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Belum ada transaksi terbaru.'),
                    )
                  else
                    SizedBox(
                      height: 280,
                      child: Scrollbar(
                        child: ListView.separated(
                          itemCount: recent.length,
                          itemBuilder: (context, index) =>
                              _recentTransactionTile(recent[index]),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _topRankingSection('UMKM Terbaik Hari Ini', top),
        ],
      ],
    );
  }

  Widget _topRankingSection(String title, List<dynamic> entries) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(title),
          if (entries.isEmpty) const ListTile(title: Text('Belum ada data.')),
          for (final entry in entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_outline, color: TW.amber),
              title:
                  Text((entry['store_name'] ?? entry['name'] ?? '').toString()),
              trailing: Text(entry['total'] != null
                  ? _money(entry['total'])
                  : '${entry['qty'] ?? 0}x'),
            ),
        ],
      );

  Widget _recentTransactionTile(Map<String, dynamic> txn) => InkWell(
        onTap: () => _showTransaction(txn),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn['id']?.toString() ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: TW.slate500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      txn['store_name']?.toString() ??
                          txn['umkm_name']?.toString() ??
                          txn['customer_name']?.toString() ??
                          '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _date(txn['created_at']),
                      style: const TextStyle(fontSize: 11, color: TW.slate500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(txn['total']),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(txn['payment_method']?.toString() ?? '-'),
                    padding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _pos() {
    final products = (_data as List).cast<Map<String, dynamic>>();
    final visible = products.where((product) {
      final term = _query.toLowerCase();
      return term.isEmpty ||
          (product['name'] ?? '').toString().toLowerCase().contains(term) ||
          (product['category'] ?? '').toString().toLowerCase().contains(term);
    }).toList();
    final total = _cartTotal(products);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), hintText: 'Cari produk...'),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Belum ada produk yang disetujui.')))
        else
          for (final product in visible)
            Card(
              child: ListTile(
                title: Text(product['name']?.toString() ?? ''),
                subtitle: Text(
                    '${product['category'] ?? 'Umum'} · Stok ${product['stock'] ?? 0}'),
                leading:
                    const CircleAvatar(child: Icon(Icons.fastfood_outlined)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_money(product['price']),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Di keranjang: ${_cart[product['id']] ?? 0}'),
                  ],
                ),
                onTap: () {
                  final id = product['id'].toString();
                  final quantity = _cart[id] ?? 0;
                  if (quantity >= (product['stock'] as num? ?? 0)) {
                    _showMessage('Stok tidak cukup.', isError: true);
                    return;
                  }
                  setState(() => _cart[id] = quantity + 1);
                },
              ),
            ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_cart.values.fold<int>(0, (a, b) => a + b)} item'),
                    Text(_money(total),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: total == 0 || _submitting
                            ? null
                            : () => _submitCheckout('QRIS'),
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('QRIS'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: total == 0 ||
                                _submitting ||
                                !ref.read(syncProvider).online.value
                            ? null
                            : () => _submitCheckout('NFC'),
                        icon: const Icon(Icons.nfc),
                        label: const Text('NFC'),
                      ),
                    ),
                  ],
                ),
                if (_cart.isNotEmpty)
                  TextButton(
                      onPressed: () => setState(_cart.clear),
                      child: const Text('Kosongkan keranjang')),
                if (!ref.read(syncProvider).online.value)
                  const Text(
                      'NFC perlu koneksi untuk memeriksa saldo pelanggan.'),
                if (_submitting) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Catatan: QRIS pada website masih berupa simulasi; belum terhubung ke penyedia pembayaran.',
          style: TextStyle(color: TW.slate500, fontSize: 12),
        ),
      ],
    );
  }

  Widget _products() {
    final products = (_data as List).cast<Map<String, dynamic>>();
    final visible = products
        .where((product) => (product['name'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();
    return Column(
      children: [
        FilledButton.icon(
          onPressed: _createProduct,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Produk'),
        ),
        const SizedBox(height: 10),
        TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Cari produk')),
        for (final product in visible)
          Card(
            child: ListTile(
              title: Text(product['name']?.toString() ?? ''),
              subtitle: Text(
                  '${product['category'] ?? 'Umum'} · ${_money(product['price'])} · Stok ${product['stock'] ?? 0} · ${product['approval_status'] ?? 'APPROVED'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'edit') {
                    await _createProduct(product);
                  } else if (await _confirm(
                      'Hapus produk?', '${product['name']} akan dihapus.')) {
                    await _runAction(
                        () => _delete('/umkm/products/${product['id']}'),
                        success: 'Produk dihapus');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _customers() {
    final customers = (_data as List).cast<Map<String, dynamic>>();
    final visible = customers
        .where((customer) =>
            '${customer['name']} ${customer['phone']} ${customer['nfc_card_masked'] ?? customer['nfc_card_id']}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    return Column(
      children: [
        FilledButton.icon(
            onPressed: _createCustomer,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Tambah Pelanggan')),
        const SizedBox(height: 10),
        const Text(
            'Pelanggan dan saldo NFC berasal dari basis data bersama HawuPay.'),
        TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Cari pelanggan')),
        for (final customer in visible)
          Card(
            child: ListTile(
              title: Text(customer['name']?.toString() ?? ''),
              subtitle: Text(
                  '${customer['phone'] ?? '-'} · ${customer['nfc_card_masked'] ?? 'Tanpa kartu'} · Saldo ${_money(customer['balance'])}'),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'edit') {
                    await _createCustomer(customer);
                  } else if (await _confirm('Hapus pelanggan?',
                      'Data ${customer['name']} akan dihapus.')) {
                    await _runAction(
                        () => _delete('/umkm/customers/${customer['id']}'),
                        success: 'Pelanggan dihapus');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _transactions() {
    final transactions = (_data as List).cast<Map<String, dynamic>>();
    final visible = transactions
        .where((txn) =>
            '${txn['id']} ${txn['payment_method']} ${txn['status']} ${txn['store_name']}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    return Column(
      children: [
        TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari ID, metode, status...')),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const Card(child: ListTile(title: Text('Belum ada transaksi.'))),
        for (final txn in visible) _transactionTile(txn),
      ],
    );
  }

  Widget _transactionTile(Map<String, dynamic> txn) => Card(
        child: ListTile(
          title: Text(_money(txn['total']),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${txn['id'] ?? '-'} · ${txn['payment_method'] ?? '-'} · ${_date(txn['created_at'])}'),
          trailing: Text(txn['status']?.toString() ?? ''),
          onTap: () => _showTransaction(txn),
        ),
      );

  Future<void> _showTransaction(Map<String, dynamic> txn) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(txn['id']?.toString() ?? 'Transaksi'),
          content: SingleChildScrollView(
              child: Text(const JsonEncoder.withIndent('  ').convert(txn))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Tutup'))
          ],
        ),
      );

  String _date(Object? value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null
        ? value.toString()
        : DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(parsed.toLocal());
  }

  Widget _reports() {
    final data = _data as Map<String, dynamic>;
    final methods = data['by_method'] as Map<String, dynamic>? ?? {};
    final products =
        (data['by_product'] as List? ?? []).cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _period,
          decoration: const InputDecoration(labelText: 'Periode laporan'),
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Harian')),
            DropdownMenuItem(value: 'weekly', child: Text('Mingguan')),
            DropdownMenuItem(value: 'monthly', child: Text('Bulanan')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _period = value;
              _data = null;
            });
            _load();
          },
        ),
        const SizedBox(height: 12),
        _statCard(
            'Total Penjualan', _money(data['total']), Icons.payments_outlined),
        _statCard('Jumlah Transaksi', '${data['count'] ?? 0}',
            Icons.receipt_long_outlined),
        _statCard('QRIS', _money(methods['QRIS']), Icons.qr_code_2),
        _statCard('NFC', _money(methods['NFC']), Icons.nfc),
        _sectionHeading('Penjualan per Produk'),
        if (products.isEmpty)
          const ListTile(title: Text('Tidak ada data pada periode ini.')),
        for (final product in products)
          ListTile(
            title: Text(product['name']?.toString() ?? ''),
            subtitle: Text('Terjual ${product['qty'] ?? 0}'),
            trailing: Text(_money(product['total'])),
          ),
      ],
    );
  }

  Widget _storeSettings() {
    final data = _data as Map<String, dynamic>;
    return Column(
      children: [
        _statCard('Nama Toko', data['store_name']?.toString() ?? '-',
            Icons.storefront_outlined),
        _statCard('Alamat', data['address']?.toString() ?? '-',
            Icons.location_on_outlined),
        _statCard(
            'Telepon', data['phone']?.toString() ?? '-', Icons.phone_outlined),
        FilledButton.icon(
          onPressed: () async {
            final form = await _editForm(
                'Pengaturan Toko',
                const [
                  _FormField('store_name', 'Nama toko'),
                  _FormField('address', 'Alamat'),
                  _FormField('phone', 'Telepon'),
                ],
                initial: data);
            if (form == null) return;
            await _runAction(
              () async =>
                  _put('/umkm/settings', data: {...form, 'logo': data['logo']}),
              success: 'Pengaturan toko disimpan',
            );
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Ubah Pengaturan'),
        ),
        const SizedBox(height: 8),
        const Text('Logo toko dapat diperbarui melalui website HawuPay.'),
      ],
    );
  }

  Widget _admins() {
    final admins = (_data as List).cast<Map<String, dynamic>>();
    return Column(
      children: [
        FilledButton.icon(
            onPressed: _createAdmin,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Tambah Admin')),
        for (final admin in admins)
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                  child: Icon(Icons.admin_panel_settings_outlined)),
              title: Text(admin['name']?.toString() ?? ''),
              subtitle: Text(
                  '${admin['email'] ?? ''} · Dibuat ${_date(admin['created_at'])}'),
            ),
          ),
      ],
    );
  }

  Widget _umkms() {
    final stores = (_data as List).cast<Map<String, dynamic>>();
    final visible = stores
        .where((store) =>
            '${store['store_name']} ${store['email']} ${store['address']}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    return Column(
      children: [
        FilledButton.icon(
            onPressed: _createUmkm,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Tambah UMKM')),
        TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama toko, email...')),
        for (final store in visible)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(store['store_name']?.toString() ?? ''),
                    subtitle: Text(
                        '${store['email'] ?? ''}\n${store['address'] ?? ''}\nSaldo ${_money(store['balance'])}'),
                    trailing: Chip(
                        label: Text(
                            store['active'] == false ? 'Nonaktif' : 'Aktif')),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _umkmId = store['id'].toString();
                            _umkmName = store['store_name']?.toString();
                            _page = _Page.umkmProducts;
                            _data = null;
                          });
                          _load();
                        },
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Produk toko'),
                      ),
                      OutlinedButton(
                        onPressed: () => _runAction(
                          () async =>
                              _patch('/admin/umkms/${store['id']}/toggle'),
                          success: 'Status UMKM diperbarui',
                        ),
                        child: Text(store['active'] == false
                            ? 'Aktifkan'
                            : 'Nonaktifkan'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final accepted = await _confirm(
                            'Hapus UMKM?',
                            'Menghapus ${store['store_name']} juga menghapus data tokonya dari server.',
                          );
                          if (accepted) {
                            await _runAction(
                              () => _delete('/admin/umkms/${store['id']}'),
                              success: 'UMKM dihapus',
                            );
                          }
                        },
                        child: const Text('Hapus',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _umkmProducts() {
    final data = _data as Map<String, dynamic>;
    final store = data['umkm'] as Map<String, dynamic>? ?? {};
    final products =
        (data['products'] as List? ?? []).cast<Map<String, dynamic>>();
    return Column(
      children: [
        ListTile(
            title: Text(store['store_name']?.toString() ?? _umkmName ?? ''),
            subtitle: const Text('Katalog produk UMKM')),
        for (final product in products)
          Card(
            child: ListTile(
              title: Text(product['name']?.toString() ?? ''),
              subtitle: Text(
                  '${product['category'] ?? 'Umum'} · ${_money(product['price'])} · Stok ${product['stock'] ?? 0}'),
              trailing: Text(product['approval_status']?.toString() ?? ''),
            ),
          ),
      ],
    );
  }

  Widget _approvals() {
    final products = (_data as List).cast<Map<String, dynamic>>();
    return Column(
      children: [
        if (products.isEmpty)
          const Card(
              child: ListTile(title: Text('Tidak ada pengajuan produk.'))),
        for (final product in products)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product['name']?.toString() ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                      '${product['store_name'] ?? ''} · ${_money(product['price'])} · Stok ${product['stock'] ?? 0}'),
                  if ((product['description'] ?? '').toString().isNotEmpty)
                    Text(product['description'].toString()),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _decideProduct(product, 'REJECTED'),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _decideProduct(product, 'APPROVED'),
                          child: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _decideProduct(
      Map<String, dynamic> product, String status) async {
    final form = await _editForm('Catatan keputusan (opsional)', const [
      _FormField('approval_note', 'Catatan'),
    ]);
    if (form == null) return;
    await _runAction(
      () async => _patch('/admin/products/${product['id']}/decision', data: {
        'status': status,
        'approval_note': form['approval_note'],
      }),
      success: status == 'APPROVED' ? 'Produk disetujui' : 'Produk ditolak',
    );
  }

  Widget _passwordResets() {
    final requests = (_data as List).cast<Map<String, dynamic>>();
    return Column(
      children: [
        if (requests.isEmpty)
          const Card(
              child: ListTile(
                  title: Text('Tidak ada permintaan reset password.'))),
        for (final request in requests)
          Card(
            child: ListTile(
              title: Text(request['name']?.toString() ?? ''),
              subtitle: Text(
                  '${request['email'] ?? ''} · ${request['store_name'] ?? ''}\n${_date(request['requested_at'])}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (choice) => _runAction(
                  () async {
                    final path =
                        '/admin/password-reset-requests/${request['id']}/$choice';
                    await _post(path,
                        data: choice == 'reject'
                            ? {'reason': 'Ditolak melalui aplikasi mobile'}
                            : {});
                  },
                  success: choice == 'approve'
                      ? 'Tautan reset dikirim'
                      : 'Permintaan ditolak',
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'approve', child: Text('Setujui')),
                  PopupMenuItem(value: 'reject', child: Text('Tolak')),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _settlement() {
    final data = _data as Map<String, dynamic>;
    final config = data['config'] as Map<String, dynamic>;
    return Column(
      children: [
        _statCard('Total Dana Masuk', _money(data['total_in']),
            Icons.payments_outlined),
        _statCard('Bagian UMKM (${config['umkm_pct']}%)',
            _money(data['umkm_share']), Icons.store_outlined),
        _statCard('Bagian Pemkab (${config['pemkab_pct']}%)',
            _money(data['pemkab_share']), Icons.account_balance_outlined),
        _statCard('Bagian Admin (${config['admin_pct']}%)',
            _money(data['admin_share']), Icons.admin_panel_settings_outlined),
        _statCard('Alokasi menunggu', _money(data['pending_allocation_total']),
            Icons.pending_actions_outlined),
        FilledButton(
          onPressed: () async {
            final form = await _editForm(
                'Konfigurasi Settlement',
                const [
                  _FormField('umkm_pct', 'UMKM (%)', number: true),
                  _FormField('pemkab_pct', 'Pemkab (%)', number: true),
                  _FormField('admin_pct', 'Admin (%)', number: true),
                ],
                initial: config);
            if (form == null) return;
            final total = (form['umkm_pct'] as num) +
                (form['pemkab_pct'] as num) +
                (form['admin_pct'] as num);
            if ((total - 100).abs() > 0.01) {
              _showMessage('Total persentase harus 100%.', isError: true);
              return;
            }
            await _runAction(
              () async => _put('/admin/settlement', data: form),
              success: 'Konfigurasi settlement diperbarui',
            );
          },
          child: const Text('Ubah Persentase'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
              'Ledger ini mencatat alokasi; transfer dana nyata memerlukan integrasi perbankan.'),
        ),
      ],
    );
  }

  Widget _audit() {
    final logs = (_data as List).cast<Map<String, dynamic>>();
    return Column(
      children: [
        for (final log in logs)
          Card(
            child: ListTile(
              title: Text(log['action']?.toString() ?? ''),
              subtitle: Text(
                  '${_date(log['created_at'])}\nUser: ${log['user_id'] ?? '-'} · UMKM: ${log['umkm_id'] ?? '-'}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Detail audit'),
                    content: SingleChildScrollView(
                        child: Text(const JsonEncoder.withIndent('  ')
                            .convert(log['meta']))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Tutup'))
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _adminSettings() {
    return Column(
      children: [
        _statCard('Email Admin', _user.email, Icons.email_outlined),
        FilledButton.icon(
          onPressed: () async {
            final form = await _editForm('Ubah Email Admin', const [
              _FormField('email', 'Email baru'),
              _FormField('current_password', 'Password saat ini',
                  password: true),
            ], initial: {
              'email': _user.email
            });
            if (form == null) return;
            await _runAction(
              () async {
                final result = await _put('/admin/account', data: form)
                    as Map<String, dynamic>;
                final updated = AppUser(
                  _user.name,
                  result['email']?.toString() ?? _user.email,
                  _user.role,
                  id: _user.id,
                  umkmId: _user.umkmId,
                );
                await ref.read(tokenStoreProvider).saveUser(updated.toJson());
                ref.read(userProvider.notifier).state = updated;
              },
              success: 'Email admin diperbarui',
            );
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Ubah Email'),
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon) => Card(
        child: ListTile(
          leading: Icon(icon, color: TW.indigo),
          title: Text(title,
              style: const TextStyle(color: TW.slate500, fontSize: 12)),
          subtitle: Text(value,
              style: const TextStyle(
                  color: TW.slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
      );

  Widget _sectionHeading(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
}

class ValueListenableBuilder2 extends StatelessWidget {
  const ValueListenableBuilder2({
    super.key,
    required this.online,
    required this.pending,
    required this.builder,
  });

  final ValueNotifier<bool> online;
  final ValueNotifier<int> pending;
  final Widget Function(bool, int) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: online,
        builder: (_, isOnline, __) => ValueListenableBuilder<int>(
          valueListenable: pending,
          builder: (_, count, __) => builder(isOnline, count),
        ),
      );
}

class _DashboardChartPainter extends CustomPainter {
  _DashboardChartPainter(List<Map<String, dynamic>> series)
      : points = series.length > 7
            ? series.sublist(series.length - 7)
            : List.unmodifiable(series);

  final List<Map<String, dynamic>> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 60 || size.height <= 50) return;

    const left = 46.0;
    const right = 8.0;
    const top = 10.0;
    const bottom = 30.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final values = points
        .map((point) => (point['total'] as num?)?.toDouble() ?? 0)
        .toList();
    final maximum = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    final scale = maximum == 0 ? 1.0 : maximum * 1.12;
    final gridPaint = Paint()
      ..color = TW.border
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = TW.navy
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = TW.navy.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;

    for (var step = 0; step <= 3; step++) {
      final fraction = step / 3;
      final y = chart.bottom - chart.height * fraction;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawLabel(
        canvas,
        _compactAmount(scale * fraction),
        Offset(0, y - 7),
        width: left - 6,
        align: TextAlign.right,
        color: TW.slate500,
        fontSize: 9,
      );
    }

    final positions = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (values.length - 1);
      final y = chart.bottom - chart.height * values[index] / scale;
      positions.add(Offset(x, y));
    }

    final area = Path()..moveTo(positions.first.dx, chart.bottom);
    for (final position in positions) {
      area.lineTo(position.dx, position.dy);
    }
    area
      ..lineTo(positions.last.dx, chart.bottom)
      ..close();
    canvas.drawPath(area, fillPaint);

    final line = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (final position in positions.skip(1)) {
      line.lineTo(position.dx, position.dy);
    }
    canvas.drawPath(line, linePaint);
    for (final position in positions) {
      canvas.drawCircle(position, 3.5, Paint()..color = TW.gold);
      canvas.drawCircle(
        position,
        2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    }

    for (var index = 0; index < points.length; index++) {
      final date = DateTime.tryParse(points[index]['date']?.toString() ?? '');
      final label = date == null
          ? (points[index]['date']?.toString() ?? '')
          : DateFormat('d/M', 'id_ID').format(date);
      final x = positions[index].dx;
      _drawLabel(
        canvas,
        label,
        Offset(x - 22, chart.bottom + 7),
        width: 44,
        align: TextAlign.center,
        color: TW.slate500,
        fontSize: 9,
      );
    }
  }

  static String _compactAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).round()}jt';
    if (value >= 1000) return '${(value / 1000).round()}rb';
    return value.round().toString();
  }

  static void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset, {
    required double width,
    required TextAlign align,
    required Color color,
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textAlign: align,
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DashboardChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
