import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/core/utils/auth_error_mapper.dart';

void main() {
  test('maps known Firebase Auth codes to Arabic', () {
    expect(
      AuthErrorMapper.map(FirebaseAuthException(code: 'wrong-password')),
      'كلمة المرور غير صحيحة',
    );
    expect(
      AuthErrorMapper.map(FirebaseAuthException(code: 'auth/user-not-found')),
      'لا يوجد حساب بهذا البريد — أنشئي حسابًا جديدًا',
    );
    expect(
      AuthErrorMapper.map(FirebaseAuthException(code: 'invalid-credential')),
      'البريد أو كلمة المرور غير صحيحة',
    );
  });

  test('falls back for unknown codes without leaking secrets', () {
    final message = AuthErrorMapper.map(
      FirebaseAuthException(code: 'something-new'),
    );
    expect(message.contains('something-new'), isTrue);
    expect(message.toLowerCase().contains('password'), isFalse);
  });

  test('maps native Google sign-in errors', () {
    expect(
      AuthErrorMapper.map(PlatformException(code: 'sign_in_canceled')),
      'أُغلقت نافذة الدخول',
    );
    expect(
      AuthErrorMapper.map(PlatformException(code: 'sign_in_failed')),
      contains('Google'),
    );
  });

  test('maps non-auth errors generically', () {
    expect(AuthErrorMapper.map(Exception('boom')), 'تعذّر إتمام العملية');
  });
}
