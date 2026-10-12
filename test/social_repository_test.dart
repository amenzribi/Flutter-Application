import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/social/data/firestore_social_repository.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/domain/social_repository.dart';

// Data-flow tests for the Firestore repository against an in-memory
// Firestore. Security rules are covered separately by
// firebase/tests/firestore.rules.test.js on the emulator.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreSocialRepository repo;

  const amina = SocialIdentity(uid: 'a1', name: 'أمينة', email: 'Amina@x.com');
  const huda = SocialIdentity(uid: 'h1', name: 'هدى', email: 'huda@x.com');
  const sara = SocialIdentity(uid: 's1', name: 'سارة', email: 'sara@x.com');

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreSocialRepository(firestore: db);
    for (final u in [amina, huda, sara]) {
      await repo.publishProfile(u);
    }
  });

  Future<PublicProfile> profile(SocialIdentity u) async =>
      (await repo.fetchProfile(u.uid))!;

  group('search', () {
    test('exact email is case-insensitive and excludes me', () async {
      final r = await repo.searchUsers('h1', 'AMINA@x.com');
      expect(r.map((p) => p.uid), ['a1']);
      expect(await repo.searchUsers('a1', 'amina@x.com'), isEmpty);
    });

    test('username prefix finds users, never me', () async {
      final r = await repo.searchUsers('a1', 'hu');
      expect(r.map((p) => p.uid), ['h1']);
      expect(await repo.searchUsers('a1', 'ami'), isEmpty);
    });

    test(
      'Arabic name search ignores hamza, ta marbuta and diacritics',
      () async {
        expect(nameSearchKey('  أمينةُ '), 'امينه');
        final r = await repo.searchUsers('h1', 'امينه');
        expect(r.map((p) => p.uid), ['a1']);
        final r2 = await repo.searchUsers('h1', 'أمي');
        expect(r2.map((p) => p.uid), ['a1']);
      },
    );

    test('blank query returns nothing', () async {
      expect(await repo.searchUsers('a1', '   '), isEmpty);
    });
  });

  group('friend requests', () {
    test('send shows pending on both sides, accept makes friends', () async {
      expect(
        await repo.sendFriendRequest(amina, await profile(huda)),
        SendRequestResult.sent,
      );
      final outgoing = await repo.watchOutgoingRequests('a1').first;
      final incoming = await repo.watchIncomingRequests('h1').first;
      expect(outgoing.single.to, 'h1');
      expect(incoming.single.from, 'a1');

      await repo.acceptFriendRequest(huda, incoming.single);

      expect(await repo.watchIncomingRequests('h1').first, isEmpty);
      expect(await repo.watchOutgoingRequests('a1').first, isEmpty);
      final aFriends = await repo.watchFriends('a1').first;
      final hFriends = await repo.watchFriends('h1').first;
      expect(aFriends.single.otherUid('a1'), 'h1');
      expect(hFriends.single.otherName('h1'), 'أمينة');
    });

    test('self invite is rejected', () async {
      expect(
        () async => repo.sendFriendRequest(amina, await profile(amina)),
        throwsA(isA<SocialException>()),
      );
    });

    test('duplicate send reports already pending, no second doc', () async {
      await repo.sendFriendRequest(amina, await profile(huda));
      expect(
        await repo.sendFriendRequest(amina, await profile(huda)),
        SendRequestResult.alreadyPending,
      );
      final all = await db.collection('friendRequests').get();
      expect(all.docs, hasLength(1));
    });

    test(
      'crossed invites accept the other side instead of duplicating',
      () async {
        await repo.sendFriendRequest(amina, await profile(huda));
        expect(
          await repo.sendFriendRequest(huda, await profile(amina)),
          SendRequestResult.acceptedTheirs,
        );
        expect(await repo.watchFriends('a1').first, hasLength(1));
        expect(
          await db.collection('friendRequests').get().then((s) => s.size),
          1,
        );
      },
    );

    test('already friends short-circuits', () async {
      await repo.sendFriendRequest(amina, await profile(huda));
      final req = (await repo.watchIncomingRequests('h1').first).single;
      await repo.acceptFriendRequest(huda, req);
      expect(
        await repo.sendFriendRequest(amina, await profile(huda)),
        SendRequestResult.alreadyFriends,
      );
    });

    test('decline clears both lists and can be re-sent', () async {
      await repo.sendFriendRequest(amina, await profile(huda));
      final req = (await repo.watchIncomingRequests('h1').first).single;
      await repo.declineFriendRequest('h1', req);
      expect(await repo.watchIncomingRequests('h1').first, isEmpty);
      expect(await repo.watchOutgoingRequests('a1').first, isEmpty);

      expect(
        await repo.sendFriendRequest(amina, await profile(huda)),
        SendRequestResult.sent,
      );
      expect(await repo.watchIncomingRequests('h1').first, hasLength(1));
    });

    test('cancel removes the invite from the receiver', () async {
      await repo.sendFriendRequest(amina, await profile(huda));
      final req = (await repo.watchOutgoingRequests('a1').first).single;
      await repo.cancelFriendRequest('a1', req);
      expect(await repo.watchIncomingRequests('h1').first, isEmpty);
      expect(await repo.watchFriends('a1').first, isEmpty);
    });

    test('only the receiver can accept', () async {
      await repo.sendFriendRequest(amina, await profile(huda));
      final req = (await repo.watchOutgoingRequests('a1').first).single;
      expect(
        () => repo.acceptFriendRequest(amina, req),
        throwsA(isA<SocialException>()),
      );
    });

    test('unfriend removes the friendship for both', () async {
      await repo.sendFriendRequest(amina, await profile(huda));
      await repo.acceptFriendRequest(
        huda,
        (await repo.watchIncomingRequests('h1').first).single,
      );
      await repo.unfriend('h1', 'a1');
      expect(await repo.watchFriends('a1').first, isEmpty);
    });
  });

  group('direct chat', () {
    setUp(() async {
      await repo.sendFriendRequest(amina, await profile(huda));
      await repo.acceptFriendRequest(
        huda,
        (await repo.watchIncomingRequests('h1').first).single,
      );
    });

    test('both sides open the same conversation', () async {
      final a = await repo.openDirectConversation(amina, 'h1', 'هدى');
      final h = await repo.openDirectConversation(huda, 'a1', 'أمينة');
      expect(a, h);
      expect(await db.collection('conversations').get().then((s) => s.size), 1);
    });

    test('messages are chronological with preview and unread', () async {
      final id = await repo.openDirectConversation(amina, 'h1', 'هدى');
      const thread = ThreadRef.direct('a1_h1');
      expect(id, thread.id);

      await repo.sendMessage(amina, thread, 'السلام عليكم');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.sendMessage(amina, thread, '  كيف حالكِ؟  ');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.sendMessage(huda, thread, 'بخير والحمد لله');

      final msgs = await repo.watchMessages(thread).first;
      expect(msgs.map((m) => m.text), [
        'السلام عليكم',
        'كيف حالكِ؟',
        'بخير والحمد لله',
      ]);

      final conv = (await repo.watchConversation(id).first)!;
      expect(conv.lastMessage!.text, 'بخير والحمد لله');
      expect(conv.unreadFor('h1'), 2);
      expect(conv.unreadFor('a1'), 1);

      await repo.markConversationRead('h1', id);
      final after = (await repo.watchConversation(id).first)!;
      expect(after.unreadFor('h1'), 0);
      expect(after.unreadFor('a1'), 1);
    });

    test('blank messages are ignored and long ones rejected', () async {
      await repo.openDirectConversation(amina, 'h1', 'هدى');
      const thread = ThreadRef.direct('a1_h1');
      await repo.sendMessage(amina, thread, '   ');
      expect(await repo.watchMessages(thread).first, isEmpty);
      expect(
        () =>
            repo.sendMessage(amina, thread, 'x' * (ChatMessage.maxLength + 1)),
        throwsA(isA<SocialException>()),
      );
    });

    test('a 2000-character message is delivered intact', () async {
      await repo.openDirectConversation(amina, 'h1', 'هدى');
      const thread = ThreadRef.direct('a1_h1');
      final long = 'ب' * ChatMessage.maxLength;
      await repo.sendMessage(amina, thread, long);
      final msgs = await repo.watchMessages(thread).first;
      expect(msgs.single.text, long);
      final conv = (await repo.watchConversation('a1_h1').first)!;
      expect(conv.lastMessage!.text.length, lessThan(long.length));
    });

    test('conversation list is per member', () async {
      await repo.openDirectConversation(amina, 'h1', 'هدى');
      expect(await repo.watchConversations('a1').first, hasLength(1));
      expect(await repo.watchConversations('h1').first, hasLength(1));
      expect(await repo.watchConversations('s1').first, isEmpty);
    });
  });

  group('group challenges', () {
    test('create, add a friend, discuss, leave', () async {
      final id = await repo.createChallenge(
        amina,
        type: ChallengeType.group,
        name: '  حلقة الجمعة ',
      );
      await repo.addChallengeMember(id, 'h1', 'هدى');
      await repo.addChallengeMember(id, 's1', 'سارة');

      var c = (await repo.watchChallenge(id).first)!;
      expect(c.name, 'حلقة الجمعة');
      expect(c.members, ['a1', 'h1', 's1']);
      expect(c.isOwner('a1'), isTrue);
      expect(await repo.watchChallenges('s1').first, hasLength(1));

      final t = ThreadRef.challenge(id);
      await repo.sendMessage(huda, t, 'بسم الله نبدأ');
      c = (await repo.watchChallenge(id).first)!;
      expect(c.lastMessage!.text, 'بسم الله نبدأ');

      await repo.updateMyChallengeProgress(
        huda,
        id,
        List.generate(40, (i) => i < 4),
      );
      final progress = await repo.watchChallengeProgress(id).first;
      expect(progress.single.days, 4);
      expect(progress.single.percent, 10);

      await repo.leaveChallenge('h1', c);
      c = (await repo.watchChallenge(id).first)!;
      expect(c.members, ['a1', 's1']);
      expect(await repo.watchChallengeProgress(id).first, isEmpty);

      await repo.removeChallengeMember(id, 's1');
      expect((await repo.watchChallenge(id).first)!.members, ['a1']);
    });

    test('owner leaving deletes the challenge', () async {
      final id = await repo.createChallenge(
        amina,
        type: ChallengeType.solo,
        name: 'وردي',
      );
      final c = (await repo.watchChallenge(id).first)!;
      await repo.leaveChallenge('a1', c);
      expect(await repo.watchChallenge(id).first, isNull);
    });

    test('duo needs a friend and empty names are rejected', () async {
      expect(
        () => repo.createChallenge(amina, type: ChallengeType.duo, name: 'x'),
        throwsA(isA<SocialException>()),
      );
      expect(
        () => repo.createChallenge(amina, type: ChallengeType.solo, name: ' '),
        throwsA(isA<SocialException>()),
      );
    });
  });
}
