import 'package:intl/intl.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
String rupiah(num v) => _rp.format(v);
String hhmm(DateTime d) => DateFormat('HH:mm:ss').format(d);
