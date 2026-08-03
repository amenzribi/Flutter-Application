/// Client-side auth validation matching legacy `web/index.html` behavior.
abstract final class AuthValidators {
  /// Legacy: `/^[^@\s]+@[^@\s]+\.[^@\s]+$/`
  static final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static const int minPasswordLength = 6;
  static const int minNameLength = 2;

  static String? email(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'اكتبي بريدكِ الإلكتروني';
    }
    if (!emailPattern.hasMatch(email)) {
      return 'صيغة البريد غير صحيحة — مثال: name@email.com';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < minPasswordLength) {
      return 'كلمة المرور 6 أحرف على الأقل';
    }
    return null;
  }

  static String? displayName(String? value) {
    final name = (value ?? '').trim();
    if (name.length < minNameLength) {
      return 'اكتبي اسمكِ ليظهر لصديقاتك (حرفان على الأقل)';
    }
    return null;
  }

  static String? loginForm({required String email, required String password}) {
    return AuthValidators.email(email) ?? AuthValidators.password(password);
  }

  static String? registerForm({
    required String name,
    required String email,
    required String password,
  }) {
    return displayName(name) ??
        AuthValidators.email(email) ??
        AuthValidators.password(password);
  }

  static String? resetForm({required String email}) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return 'أدخلي بريدك أولاً';
    }
    return AuthValidators.email(trimmed);
  }
}
