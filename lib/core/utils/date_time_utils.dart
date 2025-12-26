import 'package:intl/intl.dart';

/// Date and time formatting utilities
class DateTimeUtils {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');

  /// Format date for display (e.g., "24 Dec 2024")
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format time for display (e.g., "14:30")
  static String formatTime(DateTime time) {
    return _timeFormat.format(time);
  }

  /// Format date and time for display
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Format date for API (ISO format)
  static String formatDateForApi(DateTime date) {
    return _isoDateFormat.format(date);
  }

  /// Parse ISO date string
  static DateTime? parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Calculate hours between two times
  static double calculateHours(DateTime start, DateTime end) {
    final difference = end.difference(start);
    return difference.inMinutes / 60.0;
  }

  /// Format hours for display (e.g., "2.5 hrs")
  static String formatHours(double hours) {
    return '${hours.toStringAsFixed(1)} hrs';
  }

  /// Get relative time string (e.g., "2 days ago")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return formatDate(dateTime);
    }
  }
}
