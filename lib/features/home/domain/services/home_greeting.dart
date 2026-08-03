/// Time-of-day Arabic greetings (feminine address, matching legacy tone).
abstract final class HomeGreeting {
  static String forDateTime(DateTime now, {String? displayName}) {
    final hour = now.hour;
    final base = switch (hour) {
      >= 5 && < 12 => 'صباح الخير',
      >= 12 && < 17 => 'نهارك سعيد',
      >= 17 && < 20 => 'مساء الخير',
      _ => 'مساء النور',
    };
    final name = displayName?.trim();
    if (name == null || name.isEmpty) {
      return base;
    }
    return '$base، $name';
  }
}
