// End-to-end check of the social features: the app's own repository code,
// real Firestore security rules, three independently signed-in users.
//
// Runs in Chrome against the local emulators only (never the live project):
//   firebase emulators:start --only auth,firestore --project barakah-40-a5dac
//   flutter build web --profile -t e2e/social_e2e_main.dart -o build/e2e
//   then open build/e2e in Chrome; results are listed on the page.
//
// Every run creates fresh accounts named e2e.<run>.*@barakah.test.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart'
    show
        StringDescription,
        wrapMatcher,
        isEmpty,
        isNull,
        isNot,
        isTrue,
        isFalse,
        contains;

import 'package:barakah40_flutter/features/social/data/firestore_social_repository.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/domain/social_repository.dart';
import 'package:barakah40_flutter/firebase_options.dart';

final run = DateTime.now().millisecondsSinceEpoch;

/// One signed-in user with their own Firebase app instance (own session).
class Session {
  Session(this.label, this.app, this.auth, this.db, this.me)
    : repo = FirestoreSocialRepository(firestore: db);

  final String label;
  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final SocialIdentity me;
  final FirestoreSocialRepository repo;

  String get uid => me.uid;

  static Future<Session> create(String label, String name) async {
    final app = await Firebase.initializeApp(
      name: 'e2e-$label-$run',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 9099);
    final db = FirebaseFirestore.instanceFor(app: app);
    db.useFirestoreEmulator('127.0.0.1', 8085);
    final email = 'e2e.$run.$label@barakah.test';
    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: 'pw-$run-$label',
    );
    await cred.user!.updateDisplayName(name);
    final me = SocialIdentity(uid: cred.user!.uid, name: name, email: email);
    final s = Session(label, app, auth, db, me);
    await s.repo.publishProfile(me);
    return s;
  }
}

/// Waits until [stream] emits a value matching [test] (real-time delivery).
/// Number of the current wait inside a check, reported on timeout.
var waitNo = 0;

Future<T> eventually<T>(
  Stream<T> stream,
  bool Function(T) test, {
  Duration timeout = const Duration(seconds: 30),
}) {
  final n = ++waitNo;
  return stream
      .firstWhere(test)
      .timeout(
        timeout,
        onTimeout: () => throw StateError('wait #$n timed out'),
      );
}

Future<bool> denied(Future<void> Function() action) async {
  try {
    await action();
    return false;
  } on SocialException catch (e) {
    // Refused either by the app's own checks or by the security rules.
    return e.code == null ||
        e.code == 'permission-denied' ||
        e.code == 'stale' ||
        e.code == 'self';
  } on FirebaseException catch (e) {
    return e.code == 'permission-denied';
  }
}

void defineChecks() {
  late Session a, b, c;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    a = await Session.create('a', 'اختبار أمينة $run');
    b = await Session.create('b', 'اختبار هدى $run');
    c = await Session.create('c', 'اختبار سارة $run');
  });

  test(
    'search by name, @username and email; no email in results; never self',
    () async {
      final byName = await a.repo.searchUsers(a.uid, 'اختبار هدى $run');
      expect(byName.map((p) => p.uid), contains(b.uid));
      final byUser = await a.repo.searchUsers(a.uid, '@e2e.$run.b');
      expect(byUser.map((p) => p.uid), [b.uid]);
      final byEmail = await a.repo.searchUsers(
        a.uid,
        'E2E.$run.B@BARAKAH.TEST',
      );
      expect(byEmail.map((p) => p.uid), [b.uid]);
      expect(await a.repo.searchUsers(a.uid, a.me.email!), isEmpty);
      final raw = await a.db.collection('profiles').doc(b.uid).get();
      expect(raw.data()!.keys, isNot(contains('email')));
      // Nobody can list the email index.
      expect(
        await denied(() => c.db.collection('emailIndex').limit(5).get()),
        isTrue,
      );
    },
  );

  test(
    'invite, real-time receipt, duplicate and self refused, accept',
    () async {
      final incomingB = b.repo.watchIncomingRequests(b.uid);
      final arrived = eventually(
        incomingB,
        (l) => l.any((r) => r.from == a.uid),
      );
      final bProfile = (await a.repo.fetchProfile(b.uid))!;
      expect(
        await a.repo.sendFriendRequest(a.me, bProfile),
        SendRequestResult.sent,
      );
      final req = (await arrived).firstWhere((r) => r.from == a.uid);
      await eventually(
        a.repo.watchOutgoingRequests(a.uid),
        (l) => l.any((r) => r.to == b.uid),
      );
      expect(
        await a.repo.sendFriendRequest(a.me, bProfile),
        SendRequestResult.alreadyPending,
      );
      final aProfile = (await a.repo.fetchProfile(a.uid))!;
      var selfRefused = false;
      try {
        await a.repo.sendFriendRequest(a.me, aProfile);
      } on SocialException catch (e) {
        selfRefused = e.code == 'self';
      }
      expect(selfRefused, isTrue);
      // A third user cannot accept, or read, someone else's request.
      expect(await denied(() => c.repo.acceptFriendRequest(c.me, req)), isTrue);
      // And directly against the database rules: C cannot touch or read it.
      expect(
        await denied(
          () => c.db.doc('friendRequests/${req.id}').update({
            'status': 'accepted',
            'updatedAt': FieldValue.serverTimestamp(),
          }),
        ),
        isTrue,
      );
      expect(
        await denied(() => c.db.doc('friendRequests/${req.id}').get()),
        isTrue,
      );

      final aFriends = eventually(
        a.repo.watchFriends(a.uid),
        (l) => l.any((f) => f.otherUid(a.uid) == b.uid),
      );
      await b.repo.acceptFriendRequest(b.me, req);
      await b.repo.acceptFriendRequest(b.me, req); // double tap: harmless
      await aFriends;
      await eventually(
        b.repo.watchFriends(b.uid),
        (l) => l.length == 1 && l.single.otherUid(b.uid) == a.uid,
      );
      await eventually(b.repo.watchIncomingRequests(b.uid), (l) => l.isEmpty);
      await eventually(a.repo.watchOutgoingRequests(a.uid), (l) => l.isEmpty);
    },
  );

  test('decline, re-send, cancel; the other side updates live', () async {
    final aProfile = (await c.repo.fetchProfile(a.uid))!;
    await c.repo.sendFriendRequest(c.me, aProfile);
    final req = (await eventually(
      a.repo.watchIncomingRequests(a.uid),
      (l) => l.any((r) => r.from == c.uid),
    )).firstWhere((r) => r.from == c.uid);
    await a.repo.declineFriendRequest(a.uid, req);
    await eventually(
      c.repo.watchOutgoingRequests(c.uid),
      (l) => l.every((r) => r.to != a.uid),
    );
    expect(
      await c.repo.sendFriendRequest(c.me, aProfile),
      SendRequestResult.sent,
    );
    await eventually(
      a.repo.watchIncomingRequests(a.uid),
      (l) => l.any((r) => r.from == c.uid),
    );
    final mine = (await eventually(
      c.repo.watchOutgoingRequests(c.uid),
      (l) => l.any((r) => r.to == a.uid),
    )).firstWhere((r) => r.to == a.uid);
    await c.repo.cancelFriendRequest(c.uid, mine);
    await eventually(
      a.repo.watchIncomingRequests(a.uid),
      (l) => l.every((r) => r.from != c.uid),
    );
    await eventually(a.repo.watchFriends(a.uid), (l) => l.length == 1);
  });

  test(
    'simultaneous invitations end as one friendship, nothing pending',
    () async {
      final bOfC = (await c.repo.fetchProfile(b.uid))!;
      final cOfB = (await b.repo.fetchProfile(c.uid))!;
      final results = await Future.wait([
        c.repo.sendFriendRequest(c.me, bOfC),
        b.repo.sendFriendRequest(b.me, cOfB),
      ]);
      // Whatever interleaving happened, settle it the way the app does.
      if (!results.contains(SendRequestResult.acceptedTheirs)) {
        final req = (await eventually(
          b.repo.watchIncomingRequests(b.uid),
          (l) => l.any((r) => r.from == c.uid),
        )).firstWhere((r) => r.from == c.uid);
        await b.repo.acceptFriendRequest(b.me, req);
      }
      await eventually(
        c.repo.watchFriends(c.uid),
        (l) => l.any((f) => f.otherUid(c.uid) == b.uid),
      );
      // Nothing left pending in either direction, on either side.
      await eventually(
        c.repo.watchIncomingRequests(c.uid),
        (l) => l.every((r) => r.from != b.uid),
      );
      await eventually(
        c.repo.watchOutgoingRequests(c.uid),
        (l) => l.every((r) => r.to != b.uid),
      );
      await eventually(
        b.repo.watchIncomingRequests(b.uid),
        (l) => l.every((r) => r.from != c.uid),
      );
      await eventually(
        b.repo.watchOutgoingRequests(b.uid),
        (l) => l.every((r) => r.to != c.uid),
      );
    },
  );

  test('private chat: one conversation, real time both ways, persists, '
      'outsider refused', () async {
    final idA = await a.repo.openDirectConversation(a.me, b.uid, b.me.name);
    final idB = await b.repo.openDirectConversation(b.me, a.uid, a.me.name);
    expect(idA, idB);
    final thread = ThreadRef.direct(idA);

    final bSees = eventually(
      b.repo.watchMessages(thread),
      (l) => l.any((m) => m.text == 'السلام عليكم' && !m.pending),
    );
    await a.repo.sendMessage(a.me, thread, 'السلام عليكم');
    await bSees;
    final long = 'وعليكم السلام ' * 100;
    final aSees = eventually(
      a.repo.watchMessages(thread),
      (l) => l.any((m) => m.text == long.trim()),
    );
    await b.repo.sendMessage(b.me, thread, long);
    final list = await aSees;
    expect(list.map((m) => m.senderId).toList(), [a.uid, b.uid]);
    expect(list.first.createdAt!.isAfter(list.last.createdAt!), isFalse);

    await eventually(
      a.repo.watchConversation(idA),
      (c) => c!.unreadFor(a.uid) == 1 && c.lastMessage!.senderId == b.uid,
    );
    await a.repo.markConversationRead(a.uid, idA);
    await eventually(
      a.repo.watchConversation(idA),
      (c) => c!.unreadFor(a.uid) == 0,
    );

    // "Reload": a brand-new session for A still has the history.
    final a2 = Session(
      'a2',
      a.app,
      a.auth,
      FirebaseFirestore.instanceFor(app: a.app),
      a.me,
    );
    await eventually(a2.repo.watchMessages(thread), (l) => l.length == 2);

    // C is a friend of B but not part of A–B's conversation.
    expect(await denied(() => c.repo.watchMessages(thread).first), isTrue);
    expect(
      await denied(() => c.repo.sendMessage(c.me, thread, 'تطفّل')),
      isTrue,
    );
    expect(await denied(() => c.db.doc('conversations/$idA').get()), isTrue);
  });

  test('duo challenge: invite, accept, shared progress, bounds', () async {
    final id = await a.repo.createChallenge(
      a.me,
      type: ChallengeType.duo,
      name: 'تحدّي $run',
      friendUid: b.uid,
      friendName: b.me.name,
    );
    final invite = await eventually(
      b.repo.watchChallengeInvites(b.uid),
      (l) => l.any((c) => c.id == id),
    );
    expect(invite.single.members, [a.uid]);
    // Invited, not yet a member: no access to progress or discussion.
    expect(await denied(() => b.repo.watchChallengeProgress(id).first), isTrue);
    await b.repo.acceptChallengeInvite(b.me, id);
    await b.repo.acceptChallengeInvite(b.me, id); // second tap harmless
    await eventually(
      b.repo.watchChallenge(id),
      (c) => c != null && c.members.length == 2 && c.members.last == b.uid,
    );

    await b.repo.updateMyChallengeProgress(
      b.me,
      id,
      List.generate(40, (i) => i < 3),
    );
    await b.repo.updateMyChallengeProgress(
      b.me,
      id,
      List.generate(40, (i) => i < 3),
    ); // same days again: still 3
    await a.repo.updateMyChallengeProgress(
      a.me,
      id,
      List.generate(40, (i) => i < 1),
    );
    // Both participants converge on the same numbers: B 3/40, A 1/40.
    bool consistent(List<ChallengeMemberProgress> l) =>
        l.length == 2 &&
        l.firstWhere((p) => p.uid == b.uid).days == 3 &&
        l.firstWhere((p) => p.uid == a.uid).days == 1;
    await eventually(a.repo.watchChallengeProgress(id), consistent);
    await eventually(b.repo.watchChallengeProgress(id), consistent);

    // Cheating is refused by the rules: more days than the goal, or
    // writing someone else's row.
    expect(
      await denied(
        () => b.db.doc('challenges/$id/progress/${b.uid}').set({
          'uid': b.uid,
          'name': 'x',
          'days': 41,
          'percent': 100,
          'cells': <bool>[],
          'at': 1,
        }),
      ),
      isTrue,
    );
    expect(
      await denied(
        () => b.db.doc('challenges/$id/progress/${a.uid}').set({
          'uid': a.uid,
          'name': 'x',
          'days': 40,
          'percent': 100,
          'cells': <bool>[],
          'at': 1,
        }),
      ),
      isTrue,
    );
    // C (not a member) sees nothing.
    expect(await denied(() => c.repo.watchChallenge(id).first), isTrue);
  });

  test(
    'duo decline is visible to both; cancelled invite cannot be accepted',
    () async {
      final id = await a.repo.createChallenge(
        a.me,
        type: ChallengeType.duo,
        name: 'تحدٍّ ثانٍ $run',
        friendUid: b.uid,
        friendName: b.me.name,
      );
      await eventually(
        b.repo.watchChallengeInvites(b.uid),
        (l) => l.any((c) => c.id == id),
      );
      await b.repo.declineChallengeInvite(b.uid, id);
      final seen = await eventually(
        a.repo.watchChallenge(id),
        (c) => c != null && c.declined.contains(b.uid),
      );
      expect(seen!.members, [a.uid]);
      await eventually(
        b.repo.watchChallengeInvites(b.uid),
        (l) => l.every((c) => c.id != id),
      );

      await a.repo.inviteToChallenge(id, b.uid, b.me.name);
      await a.repo.cancelChallengeInvite(id, b.uid);
      expect(
        await denied(() => b.repo.acceptChallengeInvite(b.me, id)),
        isTrue,
      );
      await eventually(
        a.repo.watchChallenge(id),
        (c) => c!.members.length == 1 && c.invited.isEmpty,
      );
    },
  );

  test('group: invite chain, live discussion, non-member and leaver refused, '
      'owner delete clears everything', () async {
    final id = await a.repo.createChallenge(
      a.me,
      type: ChallengeType.group,
      name: 'حلقة $run',
    );
    final thread = ThreadRef.challenge(id);
    // A cannot invite C: they are not friends.
    expect(
      await denied(() => a.repo.inviteToChallenge(id, c.uid, 'C')),
      isTrue,
    );
    await a.repo.inviteToChallenge(id, b.uid, b.me.name);
    await b.repo.acceptChallengeInvite(b.me, id);
    // B invites her own friend C.
    await b.repo.inviteToChallenge(id, c.uid, c.me.name);
    expect(await denied(() => c.repo.watchMessages(thread).first), isTrue);
    await c.repo.acceptChallengeInvite(c.me, id);

    final cSees = eventually(
      c.repo.watchMessages(thread),
      (l) => l.any((m) => m.senderId == a.uid),
    );
    await a.repo.sendMessage(a.me, thread, 'بسم الله نبدأ');
    await cSees;
    final aSees = eventually(
      a.repo.watchMessages(thread),
      (l) => l.any((m) => m.senderId == c.uid),
    );
    await c.repo.sendMessage(c.me, thread, 'معكم إن شاء الله');
    await aSees;
    await eventually(
      b.repo.watchMessages(thread),
      (l) => l.map((m) => m.senderId).join(',') == [a.uid, c.uid].join(','),
    );

    // C leaves and loses access.
    final group = (await eventually(
      c.repo.watchChallenge(id),
      (g) => g != null && g.members.contains(c.uid),
    ))!;
    await c.repo.leaveChallenge(c.uid, group);
    // Asked of the server (her device still holds what she already received).
    expect(
      await denied(
        () => c.db
            .collection('challenges/$id/messages')
            .get(const GetOptions(source: Source.server)),
      ),
      isTrue,
    );
    expect(
      await denied(
        () => c.db
            .doc('challenges/$id')
            .get(const GetOptions(source: Source.server)),
      ),
      isTrue,
    );
    expect(
      await denied(() => c.repo.sendMessage(c.me, thread, 'ما زلت هنا؟')),
      isTrue,
    );

    // Owner deletes: messages and progress go too (checked as B before the
    // challenge document disappears is impossible, so check counts as A).
    await b.repo.updateMyChallengeProgress(b.me, id, List.filled(40, false));
    final full = (await a.repo.watchChallenge(id).first)!;
    await a.repo.leaveChallenge(a.uid, full);
    // Gone: the live view reports either "no document" or "no access" (there
    // is no membership left to check); the app shows its "gone" screen for
    // both.
    try {
      await eventually(a.repo.watchChallenge(id), (g) => g == null);
    } on FirebaseException catch (e) {
      expect(e.code, 'permission-denied');
    }
    // Its discussion and progress are gone too. Nobody can read a deleted
    // challenge any more, so ask the local emulator with admin access.
    for (final sub in ['messages', 'progress']) {
      final res = await http.get(
        Uri.parse(
          'http://127.0.0.1:8085/v1/projects/barakah-40-a5dac/databases/'
          '(default)/documents/challenges/$id/$sub',
        ),
        headers: {'Authorization': 'Bearer owner'},
      );
      final docs = (jsonDecode(res.body) as Map)['documents'];
      expect(docs, isNull, reason: '$sub left behind');
    }
  });

  test('private user state is owner-only', () async {
    await a.db.doc('users/${a.uid}').set({
      'state': {'completed': List.filled(40, false)},
      'updated': 1,
    }, SetOptions(merge: true));
    expect(await denied(() => b.db.doc('users/${a.uid}').get()), isTrue);
    expect(
      await denied(() => b.db.doc('users/${a.uid}').set({'state': {}})),
      isTrue,
    );
  });

  test('account deletion removes profile, email lookup, friendships and '
      'cancels open invitations', () async {
    final d = await Session.create('d', 'اختبار حذف $run');
    final aOfD = (await d.repo.fetchProfile(a.uid))!;
    await d.repo.sendFriendRequest(d.me, aOfD);
    await d.repo.removeMySocialData(d.me);
    await d.db.doc('users/${d.uid}').set({'name': 'x'});
    await d.db.doc('users/${d.uid}').delete();
    await d.auth.currentUser!.delete();

    expect(await a.repo.fetchProfile(d.uid), isNull);
    await eventually(
      a.repo.watchIncomingRequests(a.uid),
      (l) => l.every((r) => r.from != d.uid),
    );
    final lookup = await a.db
        .collection('emailIndex')
        .doc(emailKeyOf(d.me.email!))
        .get();
    expect(lookup.exists, isFalse);
  });
}

// ---------------------------------------------------------------------------
// Minimal runner: the checks above run in order; results are printed to the
// console (prefixed "E2E") and listed on the page.

final _checks = <(String, Future<void> Function())>[];
Future<void> Function()? _setup;

void setUpAll(Future<void> Function() body) => _setup = body;
void test(String name, Future<void> Function() body) =>
    _checks.add((name, body));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final lines = ValueNotifier<List<String>>([]);
  runApp(
    MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<List<String>>(
          valueListenable: lines,
          builder: (context, value, _) => ListView(
            padding: const EdgeInsets.all(12),
            children: [for (final l in value) SelectableText(l)],
          ),
        ),
      ),
    ),
  );
  void log(String s) {
    // ignore: avoid_print
    print('E2E $s');
    lines.value = [...lines.value, s];
    globalContext['e2eLog'] = lines.value.join('\n').toJS;
  }

  defineChecks();
  try {
    await _setup!();
    log('SETUP ok (run $run)');
  } catch (e) {
    log('SETUP FAIL $e');
    return;
  }
  var pass = 0;
  var fail = 0;
  for (final (name, body) in _checks) {
    waitNo = 0;
    try {
      await body();
      pass++;
      log('PASS $name');
    } catch (e) {
      fail++;
      log('FAIL $name: $e');
    }
  }
  log('DONE pass=$pass fail=$fail');
}

/// `expect` without a test runner: throws a readable error on mismatch.
void expect(Object? actual, Object? matcher, {String? reason}) {
  final m = wrapMatcher(matcher);
  final state = <dynamic, dynamic>{};
  if (m.matches(actual, state)) return;
  final d = StringDescription()
    ..add('Expected: ')
    ..addDescriptionOf(m)
    ..add('\n  Actual: ')
    ..addDescriptionOf(actual);
  final mismatch = StringDescription();
  m.describeMismatch(actual, mismatch, state, false);
  throw StateError(
    '$d ${mismatch.length > 0 ? '\n   Which: $mismatch' : ''}'
    '${reason == null ? '' : '\n  ($reason)'}',
  );
}
