import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/auth/data/services/user_document_service.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _FakeUser extends Fake implements User {
  _FakeUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.providers = const [],
  });

  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final bool emailVerified;
  final List<String> providers;

  @override
  List<UserInfo> get providerData => [
    for (final p in providers)
      // ignore: invalid_use_of_protected_member
      UserInfo.fromJson({
        'providerId': p,
        'uid': uid,
        'isAnonymous': false,
        'isEmailVerified': emailVerified,
      }),
  ];
}

void main() {
  test('mapFirebaseUser copies identity fields only', () {
    final mapped = mapFirebaseUser(
      _FakeUser(
        uid: 'abc',
        email: 'A@B.CO',
        displayName: 'Noura',
        emailVerified: true,
      ),
    );

    expect(
      mapped,
      isA<AppUser>()
          .having((u) => u.uid, 'uid', 'abc')
          .having((u) => u.email, 'email', 'A@B.CO')
          .having((u) => u.displayName, 'displayName', 'Noura')
          .having((u) => u.emailVerified, 'emailVerified', true)
          .having((u) => u.needsEmailVerification, 'needs check', false),
    );
  });

  test('an unconfirmed password account must confirm its email to sync', () {
    final password = mapFirebaseUser(
      _FakeUser(uid: 'p', email: 'p@x.co', providers: const ['password']),
    );
    expect(password.isPasswordUser, isTrue);
    expect(password.needsEmailVerification, isTrue);

    final google = mapFirebaseUser(
      _FakeUser(uid: 'g', email: 'g@x.co', providers: const ['google.com']),
    );
    expect(google.needsEmailVerification, isFalse);
  });
}
