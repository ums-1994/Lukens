/// Utility functions for the document editor
class EditorUtils {
  /// Format timestamp to relative time string
  static String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final DateTime dt = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  /// Get currency symbol from currency string like "Rand (ZAR)"
  static String getCurrencySymbol(String currency) {
    final currencyMap = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'ZAR': 'R',
      'JPY': '¥',
      'CNY': '¥',
      'INR': '₹',
      'AUD': 'A\$',
      'CAD': 'C\$',
    };

    // Extract currency code from string like "Rand (ZAR)"
    final regex = RegExp(r'\(([A-Z]{3})\)');
    final match = regex.firstMatch(currency);
    if (match != null) {
      final code = match.group(1);
      return currencyMap[code] ?? '\$';
    }
    return '\$';
  }
}








