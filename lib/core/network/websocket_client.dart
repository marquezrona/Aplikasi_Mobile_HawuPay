import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_constants.dart';
import 'api_client.dart';

/// Format event yang diasumsikan dari backend:
/// {"type":"transaction.created|stock.updated|product.approved","data":{...}}
class RealtimeEvent {
  RealtimeEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}

class WebSocketClient {
  WebSocketClient(this._tokens);
  final TokenStore _tokens;
  final _ctrl = StreamController<RealtimeEvent>.broadcast();
  WebSocketChannel? _ch;
  Timer? _retry, _demo;
  int _attempt = 0;
  bool _closed = false;

  Stream<RealtimeEvent> get events => _ctrl.stream;

  Future<void> connect() async {
    _closed = false;
    if (ApiConstants.useDemoMode) return _startDemo();
    final t = await _tokens.read();
    final url = t == null ? ApiConstants.wsUrl : '${ApiConstants.wsUrl}?token=$t';
    try {
      _ch = WebSocketChannel.connect(Uri.parse(url));
      _ch!.stream.listen((raw) {
        _attempt = 0;
        try {
          final m = jsonDecode(raw as String) as Map<String, dynamic>;
          _ctrl.add(RealtimeEvent(m['type'] as String, (m['data'] ?? {}) as Map<String, dynamic>));
        } catch (_) {}
      }, onDone: _reconnect, onError: (_) => _reconnect());
    } catch (_) {
      _reconnect();
    }
  }

  void _reconnect() {
    if (_closed) return;
    _retry?.cancel();
    final secs = min(30, pow(2, _attempt++).toInt()); // exponential backoff
    _retry = Timer(Duration(seconds: secs), connect);
  }

  void _startDemo() {
    _demo?.cancel();
    final rnd = Random();
    _demo = Timer.periodic(const Duration(seconds: 6), (_) {
      _ctrl.add(RealtimeEvent('transaction.created', {
        'store': ['Toko Hawu Jaya', 'Warung Sari', 'Kopi Kupang'][rnd.nextInt(3)],
        'total': (rnd.nextInt(20) + 1) * 5000,
        'method': rnd.nextBool() ? 'QRIS' : 'NFC',
      }));
    });
  }

  void dispose() {
    _closed = true;
    _retry?.cancel();
    _demo?.cancel();
    _ch?.sink.close();
    _ctrl.close();
  }
}
