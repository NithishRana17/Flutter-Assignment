/// Validation utilities for forms
class Validators {
  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validate password (min 6 characters)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validate ICAO code (exactly 4 characters)
  static String? validateIcao(String? value) {
    if (value == null || value.isEmpty) {
      return 'ICAO code is required';
    }
    if (value.length != 4) {
      return 'ICAO code must be exactly 4 characters';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value.toUpperCase())) {
      return 'ICAO code must contain only letters and numbers';
    }
    return null;
  }

  /// Validate aircraft registration
  static String? validateAircraftReg(String? value) {
    if (value == null || value.isEmpty) {
      return 'Aircraft registration is required';
    }
    if (value.length < 2) {
      return 'Enter a valid aircraft registration';
    }
    return null;
  }

  /// Validate that a value is not empty
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate hours (must be non-negative)
  static String? validateHours(String? value, {bool required = false}) {
    if (value == null || value.isEmpty) {
      return required ? 'Hours is required' : null;
    }
    final hours = double.tryParse(value);
    if (hours == null) {
      return 'Enter a valid number';
    }
    if (hours < 0) {
      return 'Hours cannot be negative';
    }
    if (hours > 24) {
      return 'Hours cannot exceed 24';
    }
    return null;
  }
}
