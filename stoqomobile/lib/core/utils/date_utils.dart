import 'package:intl/intl.dart';

class AppDateUtils {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');
  static final _timeFormat = DateFormat('HH:mm');

  static String formatDate(DateTime? dt) =>
      dt == null ? '-' : _dateFormat.format(dt.toLocal());

  static String formatDateTime(DateTime? dt) =>
      dt == null ? '-' : _dateTimeFormat.format(dt.toLocal());

  static String formatTime(DateTime? dt) =>
      dt == null ? '-' : _timeFormat.format(dt.toLocal());

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String toIso(DateTime dt) => dt.toUtc().toIso8601String();
  static DateTime fromIso(String s) => DateTime.parse(s).toLocal();
}
