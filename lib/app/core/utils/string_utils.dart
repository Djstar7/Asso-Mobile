/// String utility functions
class StringUtils {
  /// Get initials from a name (e.g., "John Doe" -> "JD")
  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Check if a string is a valid URL
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Truncate text to a specific length with ellipsis
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}$ellipsis';
  }

  /// Capitalize first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

  /// Format phone number for display
  static String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Format as +XXX XX XX XX XX
    if (digitsOnly.length >= 9) {
      return '+${digitsOnly.substring(0, 3)} ${digitsOnly.substring(3, 5)} ${digitsOnly.substring(5, 7)} ${digitsOnly.substring(7, 9)} ${digitsOnly.length > 9 ? digitsOnly.substring(9) : ''}';
    }

    return phoneNumber;
  }
}
