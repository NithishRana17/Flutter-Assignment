
class TimeUtils {
  /// Converts decimal hours to "H:MM" format (for input fields)
  /// e.g. 1.5 -> "1:30", 1.25 -> "1:15"
  static String decimalToInput(double hours) {
    int h = hours.truncate();
    int m = ((hours - h) * 60).round();
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  /// Converts decimal hours to "Xh : XXm" format (for display)
  /// e.g. 1.5 -> "1h : 30m", 12.08 -> "12h : 05m"
  static String decimalToDuration(double hours) {
    int h = hours.truncate();
    int m = ((hours - h) * 60).round();
    return '${h}h : ${m.toString().padLeft(2, '0')}m';
  }

  /// Alias for decimalToDuration (backward compatibility)
  static String decimalToHumanDuration(double hours) => decimalToDuration(hours);

  /// Converts "HH:MM" string to decimal hours
  /// e.g. "1:30" -> 1.5
  /// Returns null if format is invalid
  static double? durationToDecimal(String duration) {
    if (duration.isEmpty) return 0.0;
    final parts = duration.split(':');
    if (parts.length != 2) return null;
    
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    
    if (h == null || m == null || m < 0 || m >= 60) return null;
    
    return h + (m / 60.0);
  }

  /// Validates "HH:MM" format
  static bool isValidDuration(String value) {
    if (value.isEmpty) return true; // Allow empty (treated as 0)
    final RegExp regex = RegExp(r'^\d+:[0-5]\d$');
    return regex.hasMatch(value);
  }
}
