/// Utility class to parse and format dates and times synchronized to the device's local timezone.
class AppDateUtils {
  AppDateUtils._();

  /// Safely parses dates from various formats (ISO with/without Z, space-separated, epoch timestamp)
  /// and converts them accurately to the user device's local timezone.
  static DateTime? parseToLocal(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.isUtc ? raw.toLocal() : raw;

    final str = raw.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return null;

    // Check if numeric (epoch milliseconds or seconds)
    final numVal = int.tryParse(str);
    if (numVal != null) {
      if (numVal > 100000000000) {
        // Milliseconds
        return DateTime.fromMillisecondsSinceEpoch(numVal, isUtc: true).toLocal();
      } else if (numVal > 1000000000) {
        // Seconds
        return DateTime.fromMillisecondsSinceEpoch(numVal * 1000, isUtc: true).toLocal();
      }
    }

    // Standardize ISO string: replace space with 'T' (e.g. "2026-09-17 01:05:00" -> "2026-09-17T01:05:00")
    var s = str.replaceFirst(' ', 'T');

    final hasZ = s.endsWith('Z') || s.endsWith('z');
    final hasOffset = RegExp(r'[+-]\d{2}(:?\d{2})?$').hasMatch(s);

    try {
      if (hasZ || hasOffset) {
        return DateTime.parse(s).toLocal();
      } else {
        // Backend UTC naive datetimes have no 'Z' or offset indicator.
        // We append 'Z' so DateTime.parse treats it as UTC, then converts to device's local timezone.
        return DateTime.parse('${s}Z').toLocal();
      }
    } catch (_) {
      try {
        final fallback = DateTime.tryParse(str);
        if (fallback != null) {
          // If parsed without timezone, treat as UTC and convert to local
          if (!hasZ && !hasOffset) {
            return DateTime.utc(
              fallback.year,
              fallback.month,
              fallback.day,
              fallback.hour,
              fallback.minute,
              fallback.second,
              fallback.millisecond,
              fallback.microsecond,
            ).toLocal();
          }
          return fallback.toLocal();
        }
      } catch (_) {}
    }
    return null;
  }

  /// Formats time as 'HH:mm' in local device time (e.g. "08:15").
  static String formatTime(dynamic raw) {
    final dt = parseToLocal(raw);
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formats relative time ago in Indonesian, comparing with local device time.
  static String formatTimeAgo(dynamic raw) {
    final dt = parseToLocal(raw);
    if (dt == null) {
      if (raw != null && raw.toString().isNotEmpty && raw.toString() != 'null') {
        return raw.toString();
      }
      return '';
    }

    final now = DateTime.now();
    final diff = now.difference(dt);

    // Negative difference or clock drift within 1 minute
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Baru saja';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt lalu';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    }
    if (diff.inDays == 1) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Kemarin $h:$m';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    }
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks minggu lalu';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months bulan lalu';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  /// Formats date into Indonesian formatted date (e.g. "17 September 2026").
  static String formatDate(dynamic raw, {bool withTime = false}) {
    final dt = parseToLocal(raw);
    if (dt == null) return '';

    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final monthName = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
    final dateStr = '${dt.day} $monthName ${dt.year}';

    if (withTime) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$dateStr $h:$m';
    }
    return dateStr;
  }
}

