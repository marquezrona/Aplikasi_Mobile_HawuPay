import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/api_constants.dart';
import '../network/api_client.dart';

/// Offline-first queue: queued transactions are signed and sent through the
/// same transaction endpoints used by the HawuPay website.
class OfflineSyncService {
  OfflineSyncService(this._api);
  final ApiClient _api;
  late Box<String> _box;
  final pending = ValueNotifier<int>(0);
  final online = ValueNotifier<bool>(true);
  final lastError = ValueNotifier<String?>(null);
  StreamSubscription? _sub;
  bool _flushing = false;

  bool _isOn(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  Future<void> init() async {
    _box = await Hive.openBox<String>('tx_queue');
    pending.value = _box.length;
    online.value = _isOn(await Connectivity().checkConnectivity());
    _sub = Connectivity().onConnectivityChanged.listen((r) async {
      online.value = _isOn(r);
      if (online.value && await _api.tokens.read() != null) flush();
    });
  }

  /// true = terkirim ke server, false = masuk antrean offline.
  Future<bool> submit(Map<String, dynamic> tx) async {
    tx['client_txn_id'] ??= 'tx-${DateTime.now().microsecondsSinceEpoch}';
    tx['device_id'] ??= await _api.tokens.deviceId();
    tx['nonce'] ??= 'nonce-${DateTime.now().microsecondsSinceEpoch}';
    if (!online.value) return _enqueue(tx);
    if (ApiConstants.useDemoMode) return true;
    try {
      await _send(tx);
      lastError.value = null;
      return true;
    } on DioException catch (error) {
      if (!_isNetworkError(error)) rethrow;
      lastError.value =
          error.message ?? 'Koneksi terputus; transaksi masuk antrean.';
      return _enqueue(tx);
    }
  }

  Future<void> _send(Map<String, dynamic> tx) async {
    final signed = await _api.dio.post(
      '/umkm/transactions/signature',
      data: {
        'client_txn_id': tx['client_txn_id'],
        'total': tx['total'],
        'device_id': tx['device_id'],
        'nonce': tx['nonce'],
      },
    );
    await _api.dio.post(
      '/umkm/transactions',
      data: {...tx, 'signature': signed.data['signature']},
    );
  }

  bool _isNetworkError(DioException error) =>
      error.response == null &&
      (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout);

  bool _enqueue(Map<String, dynamic> tx) {
    tx['offline'] = true;
    _box.add(jsonEncode(tx));
    pending.value = _box.length;
    return false;
  }

  Future<void> flush() async {
    if (_flushing || _box.isEmpty || await _api.tokens.read() == null) return;
    _flushing = true;
    try {
      final keys = _box.keys.toList();
      if (ApiConstants.useDemoMode) {
        await Future.delayed(const Duration(seconds: 1));
        await _box.deleteAll(keys);
      } else {
        for (final key in keys) {
          final transaction =
              jsonDecode(_box.get(key)!) as Map<String, dynamic>;
          try {
            await _send(transaction);
            await _box.delete(key);
          } on DioException catch (error) {
            if (error.response?.statusCode == 409) {
              await _box.delete(key);
              continue;
            }
            lastError.value = error.response?.data is Map
                ? (error.response?.data['detail']?.toString() ?? error.message)
                : error.message;
            break;
          }
        }
      }
      pending.value = _box.length;
      if (_box.isEmpty) lastError.value = null;
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _sub?.cancel();
    pending.dispose();
    online.dispose();
    lastError.dispose();
  }
}
