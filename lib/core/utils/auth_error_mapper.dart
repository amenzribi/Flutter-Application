import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

/// Maps Firebase Auth exception codes to Arabic messages used by the legacy app.
abstract final class AuthErrorMapper {
  static const Map<String, String> _messages = {
    'email-already-in-use': 'البريد مستخدم — سجّلي الدخول',
    'invalid-email': 'بريد غير صالح',
    'weak-password': 'كلمة المرور ضعيفة',
    'wrong-password': 'كلمة المرور غير صحيحة',
    'user-not-found': 'لا يوجد حساب بهذا البريد — أنشئي حسابًا جديدًا',
    'invalid-credential': 'البريد أو كلمة المرور غير صحيحة',
    'too-many-requests': 'محاولات كثيرة — انتظري دقائق ثم أعيدي المحاولة',
    'network-request-failed': 'تعذّر الاتصال بالشبكة',
    'internal-error': 'خطأ مؤقّت — أعيدي المحاولة',
    'unauthorized-domain':
        'النطاق غير مُصرّح به في Firebase (Authorized domains)',
    'account-exists-with-different-credential':
        'هذا البريد مسجّل بطريقة دخول أخرى',
    'operation-not-supported-in-this-environment': 'هذه الطريقة غير مدعومة هنا',
    'operation-not-allowed':
        'فعّلي «Email/Password» من Firebase Console ← Authentication ← Sign-in method',
    'admin-restricted-operation':
        'التسجيل مقيّد — فعّلي Email/Password في Firebase Console',
    'configuration-not-found':
        'إعداد المصادقة غير موجود — فعّلي Email/Password في Firebase Console',
    'invalid-api-key': 'مفتاح Firebase غير صالح — تحقّقي من الإعدادات',
    'popup-closed-by-user': 'أُغلقت نافذة الدخول',
    'user-disabled': 'هذا الحساب معطّل',
    'requires-recent-login': 'أعيدي تسجيل الدخول ثم حاولي مرة أخرى',
  };

  static String map(Object error) {
    if (error is FirebaseAuthException) {
      final code = error.code.replaceFirst('auth/', '');
      return _messages[code] ??
          'تعذّر إتمام العملية${code.isNotEmpty ? ' ($code)' : ''}';
    }
    // Errors from the native Google sign-in plugin (Android/iOS).
    if (error is PlatformException) {
      switch (error.code) {
        case 'sign_in_canceled':
          return _messages['popup-closed-by-user']!;
        case 'network_error':
          return _messages['network-request-failed']!;
        case 'sign_in_failed':
          // Usually ApiException 10: the app's SHA-1 fingerprint or OAuth
          // client is missing from the Firebase project.
          return 'الدخول بـ Google غير مُعدّ لهذا الجهاز بعد — استخدمي البريد وكلمة المرور';
      }
    }
    return 'تعذّر إتمام العملية';
  }
}
