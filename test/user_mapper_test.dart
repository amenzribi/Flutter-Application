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
  });

  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final bool emailVerified;
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
          .having((u) => u.emailVerified, 'emailVerified', true),
    );
  });
}
