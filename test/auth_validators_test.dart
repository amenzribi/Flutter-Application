import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/core/utils/auth_validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('rejects empty', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('   '), isNotNull);
    });

    test('rejects invalid format', () {
      expect(AuthValidators.email('a@b'), isNotNull);
      expect(AuthValidators.email('not-an-email'), isNotNull);
    });

    test('accepts valid email', () {
      expect(AuthValidators.email('name@email.com'), isNull);
    });
  });

  group('AuthValidators.password', () {
    test('rejects short passwords', () {
      expect(AuthValidators.password('12345'), isNotNull);
    });

    test('accepts length >= 6', () {
      expect(AuthValidators.password('123456'), isNull);
    });
  });

  group('AuthValidators.registerForm', () {
    test('requires name of at least 2 characters', () {
      expect(
        AuthValidators.registerForm(
          name: 'أ',
          email: 'a@b.co',
          password: '123456',
        ),
        isNotNull,
      );
    });

    test('passes when all fields valid', () {
      expect(
        AuthValidators.registerForm(
          name: 'نورة',
          email: 'noura@email.com',
          password: '123456',
        ),
        isNull,
      );
    });
  });

  group('AuthValidators.loginForm', () {
    test('requires email and password', () {
      expect(
        AuthValidators.loginForm(email: '', password: '123456'),
        isNotNull,
      );
      expect(
        AuthValidators.loginForm(email: 'a@b.co', password: '123'),
        isNotNull,
      );
    });

    test('passes when valid', () {
      expect(
        AuthValidators.loginForm(email: 'a@b.co', password: '123456'),
        isNull,
      );
    });
  });

  group('AuthValidators.resetForm', () {
    test('requires email first', () {
      expect(AuthValidators.resetForm(email: ''), isNotNull);
    });

    test('validates format', () {
      expect(AuthValidators.resetForm(email: 'bad'), isNotNull);
      expect(AuthValidators.resetForm(email: 'a@b.co'), isNull);
    });
  });
}
