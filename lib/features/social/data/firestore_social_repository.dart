import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/domain/social_repository.dart';

/// Firestore implementation of [SocialRepository].
///
/// Collection layout: see `docs/SOCIAL_DATA_MODEL.md`. Every rule this code
/// relies on is covered by `firebase/tests/firestore.rules.test.js`.
class FirestoreSocialRepository implements SocialRepository {
  FirestoreSocialRepository({FirebaseFirestore? firestore})
    : _injected = firestore;

  final FirebaseFirestore? _injected;

  // Resolved on first use so building the provider never touches Firebase
  // (widget tests run without Firebase.initializeApp).
  late final FirebaseFirestore _db = _injected ?? FirebaseFirestore.instance;

  static const searchPageSize = 10;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('profiles');
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('friendRequests');
  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection('friendships');
  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');
  CollectionReference<Map<String, dynamic>> get _challenges =>
      _db.collection('challenges');

  // ---------------------------------------------------------------------------
  // Profiles & search
  // ---------------------------------------------------------------------------

  @override
  Future<void> publishProfile(SocialIdentity me) => _guard(() async {
    final ref = _profiles.doc(me.uid);
    final existing = await ref.get();
    final name = me.name.trim().isEmpty ? 'صديقة بركة' : me.name.trim();
    await ref.set({
      'uid': me.uid,
      'name': name.length > 60 ? name.substring(0, 60) : name,
      'nameKey': nameSearchKey(name),
      'username': usernameOf(me.email, name),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final email = me.email;
    if (email != null && email.trim().isNotEmpty) {
      await _db.collection('emailIndex').doc(emailKeyOf(email)).set({
        'uid': me.uid,
      });
    }
  });

  @override
  Future<PublicProfile?> fetchProfile(String uid) => _guard(() async {
    final snap = await _profiles.doc(uid).get();
    final data = snap.data();
    return data == null ? null : PublicProfile.fromMap(uid, data);
  });

  @override
  Future<List<PublicProfile>> searchUsers(String me, String query) =>
      _guard(() async {
        final q = query.trim();
        if (q.isEmpty) return const [];

        if (q.contains('@') && !q.startsWith('@')) {
          final index = await _db
              .collection('emailIndex')
              .doc(emailKeyOf(q))
              .get();
          final uid = index.data()?['uid'];
          if (uid is! String || uid == me) return const [];
          final profile = await fetchProfile(uid);
          return profile == null ? const [] : [profile];
        }

        final prefix = q.replaceFirst(RegExp('^@'), '').toLowerCase();
        if (prefix.isEmpty) return const [];
        final end = '$prefix\uf8ff';
        final namePrefix = nameSearchKey(prefix);
        final nameEnd = '$namePrefix\uf8ff';
        final results = await Future.wait([
          _profiles
              .where('username', isGreaterThanOrEqualTo: prefix)
              .where('username', isLessThan: end)
              .limit(searchPageSize)
              .get(),
          if (namePrefix.isNotEmpty)
            _profiles
                .where('nameKey', isGreaterThanOrEqualTo: namePrefix)
                .where('nameKey', isLessThan: nameEnd)
                .limit(searchPageSize)
                .get(),
        ]);
        final seen = <String>{me};
        final out = <PublicProfile>[];
        for (final snap in results) {
          for (final doc in snap.docs) {
            if (seen.add(doc.id)) {
              out.add(PublicProfile.fromMap(doc.id, doc.data()));
            }
          }
        }
        return out;
      });

  // ---------------------------------------------------------------------------
  // Friends
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Friendship>> watchFriends(String me) => _friendships
      .where('users', arrayContains: me)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => Friendship.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => a.otherName(me).compareTo(b.otherName(me))),
      );

  @override
  Stream<List<FriendRequest>> watchIncomingRequests(String me) => _requests
      .where('to', isEqualTo: me)
      .where('status', isEqualTo: FriendRequestStatus.pending.name)
      .snapshots()
      .map(_requestList);

  @override
  Stream<List<FriendRequest>> watchOutgoingRequests(String me) => _requests
      .where('from', isEqualTo: me)
      .where('status', isEqualTo: FriendRequestStatus.pending.name)
      .snapshots()
      .map(_requestList);

  List<FriendRequest> _requestList(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => FriendRequest.fromMap(d.data())).toList()..sort(
        (a, b) => (b.createdAt ?? DateTime(3000)).compareTo(
          a.createdAt ?? DateTime(3000),
        ),
      );

  @override
  Future<SendRequestResult> sendFriendRequest(
    SocialIdentity me,
    PublicProfile target,
  ) => _guard(() async {
    if (target.uid == me.uid) {
      throw const SocialException('لا يمكنكِ إضافة نفسكِ.', code: 'self');
    }
    try {
      return await _sendOnce(me, target);
    } on FirebaseException catch (e) {
      // Both pressed "add" at the same instant: their request landed between
      // our check and our write, so the rules refused ours. Look again: now
      // we accept theirs (or find the friendship) instead of failing.
      if (e.code != 'permission-denied') rethrow;
      return _sendOnce(me, target);
    }
  });

  Future<SendRequestResult> _sendOnce(
    SocialIdentity me,
    PublicProfile target,
  ) async {
    final friendship = await _friendships
        .doc(socialPairId(me.uid, target.uid))
        .get();
    if (friendship.exists) return SendRequestResult.alreadyFriends;

    final reverse = await _requests
        .doc(friendRequestId(target.uid, me.uid))
        .get();
    final reverseData = reverse.data();
    if (reverseData != null &&
        reverseData['status'] == FriendRequestStatus.pending.name) {
      await acceptFriendRequest(me, FriendRequest.fromMap(reverseData));
      return SendRequestResult.acceptedTheirs;
    }

    final ref = _requests.doc(friendRequestId(me.uid, target.uid));
    final own = await ref.get();
    final ownData = own.data();
    if (ownData != null) {
      if (ownData['status'] == FriendRequestStatus.pending.name) {
        return SendRequestResult.alreadyPending;
      }
      await ref.update({
        'status': FriendRequestStatus.pending.name,
        'fromName': me.name,
        'toName': target.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return SendRequestResult.sent;
    }

    await ref.set({
      'from': me.uid,
      'to': target.uid,
      'fromName': me.name,
      'toName': target.name,
      'status': FriendRequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return SendRequestResult.sent;
  }

  @override
  Future<void> acceptFriendRequest(SocialIdentity me, FriendRequest request) =>
      _guard(() async {
        if (request.to != me.uid) {
          throw const SocialException('هذا الطلب ليس موجّهاً إليكِ.');
        }
        final pair = socialPairId(request.from, me.uid);
        final friendshipRef = _friendships.doc(pair);
        final requestRef = _requests.doc(request.id);
        // My own request the other way, if we invited each other at once.
        final crossedRef = _requests.doc(friendRequestId(me.uid, request.from));
        final (already, current, crossed) = await (
          friendshipRef.get(),
          requestRef.get(),
          crossedRef.get(),
        ).wait;
        final status = current.data()?['status'];
        if (status != FriendRequestStatus.pending.name) {
          // A second tap, or another device already answered. Accepted and
          // friends means the work is done; anything else is a real change.
          if (status == FriendRequestStatus.accepted.name && already.exists) {
            return;
          }
          throw const SocialException(
            'لم يعد هذا الطلب قائماً. ربما أُلغي أو تمّ الردّ عليه.',
            code: 'stale',
          );
        }
        final batch = _db.batch();
        batch.update(requestRef, {
          'status': FriendRequestStatus.accepted.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (crossed.data()?['status'] == FriendRequestStatus.pending.name) {
          batch.update(crossedRef, {
            'status': FriendRequestStatus.cancelled.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        if (!already.exists) {
          final users = [request.from, me.uid]..sort();
          batch.set(friendshipRef, {
            'users': users,
            'names': {request.from: request.fromName, me.uid: me.name},
            'since': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      });

  @override
  Future<void> declineFriendRequest(String me, FriendRequest request) => _guard(
    () => _requests.doc(request.id).update({
      'status': FriendRequestStatus.declined.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> cancelFriendRequest(String me, FriendRequest request) => _guard(
    () => _requests.doc(request.id).update({
      'status': FriendRequestStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> unfriend(String me, String friendUid) =>
      _guard(() => _friendships.doc(socialPairId(me, friendUid)).delete());

  // ---------------------------------------------------------------------------
  // Direct conversations
  // ---------------------------------------------------------------------------

  @override
  Future<String> openDirectConversation(
    SocialIdentity me,
    String friendUid,
    String friendName,
  ) => _guard(() async {
    final id = socialPairId(me.uid, friendUid);
    final ref = _conversations.doc(id);
    final existing = await ref.get();
    if (existing.exists) return id;
    final members = [me.uid, friendUid]..sort();
    await ref.set({
      'type': 'direct',
      'members': members,
      'names': {me.uid: me.name, friendUid: friendName},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'unread': {me.uid: 0, friendUid: 0},
    });
    return id;
  });

  @override
  Stream<List<Conversation>> watchConversations(String me) => _conversations
      .where('members', arrayContains: me)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => Conversation.fromMap(d.id, d.data())).toList()
              ..sort(
                (a, b) => (b.updatedAt ?? DateTime(3000)).compareTo(
                  a.updatedAt ?? DateTime(3000),
                ),
              ),
      );

  @override
  Stream<Conversation?> watchConversation(String id) =>
      _conversations.doc(id).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : Conversation.fromMap(id, data);
      });

  @override
  Stream<List<ChatMessage>> watchMessages(
    ThreadRef thread, {
    int limit = 100,
  }) => _db
      .collection('${thread.parentPath}/messages')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) => s.docs.reversed
            .map(
              (d) => ChatMessage.fromMap(
                d.id,
                d.data(),
                pending: d.metadata.hasPendingWrites,
              ),
            )
            .toList(),
      );

  @override
  Future<void> sendMessage(SocialIdentity me, ThreadRef thread, String text) =>
      _guard(() async {
        final body = text.trim();
        if (body.isEmpty) return;
        if (body.length > ChatMessage.maxLength) {
          throw const SocialException('الرسالة طويلة جداً (الحد ٢٠٠٠ حرف).');
        }
        final parent = _db.doc(thread.parentPath);
        final messageRef = parent.collection('messages').doc();
        final batch = _db.batch();
        batch.set(messageRef, {
          'senderId': me.uid,
          'senderName': me.name,
          'text': body,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final preview = body.length > 140 ? '${body.substring(0, 140)}…' : body;
        final update = <String, Object?>{
          'lastMessage': {
            'text': preview,
            'senderId': me.uid,
            'sentAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (!thread.isGroup) {
          final other = thread.id
              .split('_')
              .firstWhere((u) => u != me.uid, orElse: () => '');
          if (other.isNotEmpty) {
            update['unread.$other'] = FieldValue.increment(1);
          }
        }
        batch.update(parent, update);
        await batch.commit();
      });

  @override
  Future<void> markConversationRead(String me, String conversationId) => _guard(
    () => _conversations.doc(conversationId).update({'unread.$me': 0}),
  );

  // ---------------------------------------------------------------------------
  // Challenges
  // ---------------------------------------------------------------------------

  @override
  Stream<List<GroupChallenge>> watchChallenges(String me) => _challenges
      .where('members', arrayContains: me)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => GroupChallenge.fromMap(d.id, d.data())).toList()
              ..sort(
                (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(3000))
                    .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(3000)),
              ),
      );

  @override
  Stream<List<GroupChallenge>> watchChallengeInvites(String me) => _challenges
      .where('invited', arrayContains: me)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => GroupChallenge.fromMap(d.id, d.data())).toList()
              ..sort(
                (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(3000))
                    .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(3000)),
              ),
      );

  @override
  Stream<GroupChallenge?> watchChallenge(String id) =>
      _challenges.doc(id).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : GroupChallenge.fromMap(id, data);
      });

  @override
  Stream<List<ChallengeMemberProgress>> watchChallengeProgress(String id) =>
      _challenges
          .doc(id)
          .collection('progress')
          .snapshots()
          .map(
            (s) =>
                s.docs
                    .map((d) => ChallengeMemberProgress.fromMap(d.data()))
                    .toList()
                  ..sort((a, b) => b.days.compareTo(a.days)),
          );

  @override
  Future<String> createChallenge(
    SocialIdentity me, {
    required ChallengeType type,
    required String name,
    String? friendUid,
    String? friendName,
  }) => _guard(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw const SocialException('اكتبي اسماً للتحدّي (حتى ٦٠ حرفاً).');
    }
    if (type == ChallengeType.duo && friendUid == null) {
      throw const SocialException('اختاري صديقة للتحدّي الثنائي.');
    }
    final duo = type == ChallengeType.duo;
    final ref = _challenges.doc();
    await ref.set({
      'type': type.name,
      'name': trimmed,
      'ownerUid': me.uid,
      'members': [me.uid],
      'invited': [if (duo) friendUid!],
      'declined': <String>[],
      'names': {me.uid: me.name, if (duo) friendUid!: friendName ?? 'صديقة'},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'goalDays': 40,
      'lastMessage': null,
    });
    return ref.id;
  });

  @override
  Future<void> inviteToChallenge(
    String challengeId,
    String friendUid,
    String friendName,
  ) => _guard(
    () => _challenges.doc(challengeId).update({
      'invited': FieldValue.arrayUnion([friendUid]),
      'declined': FieldValue.arrayRemove([friendUid]),
      'names.$friendUid': friendName,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> cancelChallengeInvite(String challengeId, String uid) => _guard(
    () => _challenges.doc(challengeId).update({
      'invited': FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> acceptChallengeInvite(SocialIdentity me, String challengeId) =>
      _guard(() async {
        final ref = _challenges.doc(challengeId);
        final snap = await ref.get();
        final c = snap.data() == null
            ? null
            : GroupChallenge.fromMap(snap.id, snap.data()!);
        // A second tap after joining is already done.
        if (c != null && c.members.contains(me.uid)) return;
        if (c == null || !c.isInvited(me.uid)) {
          throw const SocialException(
            'لم تعد هذه الدعوة قائمة. ربما أُلغيت أو حُذف التحدّي.',
            code: 'stale',
          );
        }
        await ref.update({
          'members': FieldValue.arrayUnion([me.uid]),
          'invited': FieldValue.arrayRemove([me.uid]),
          'names.${me.uid}': me.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  Future<void> declineChallengeInvite(String me, String challengeId) =>
      _guard(() async {
        final ref = _challenges.doc(challengeId);
        final snap = await ref.get();
        final invited = snap.data()?['invited'];
        if (invited is! List || !invited.contains(me)) {
          throw const SocialException(
            'لم تعد هذه الدعوة قائمة. ربما أُلغيت أو حُذف التحدّي.',
            code: 'stale',
          );
        }
        await ref.update({
          'invited': FieldValue.arrayRemove([me]),
          'declined': FieldValue.arrayUnion([me]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  Future<void> removeChallengeMember(String challengeId, String uid) =>
      _guard(() async {
        await _challenges.doc(challengeId).update({
          'members': FieldValue.arrayRemove([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        try {
          await _challenges
              .doc(challengeId)
              .collection('progress')
              .doc(uid)
              .delete();
        } on FirebaseException catch (e) {
          AppLogger.warning('progress cleanup failed: ${e.code}');
        }
      });

  @override
  Future<void> leaveChallenge(String me, GroupChallenge challenge) =>
      _guard(() async {
        final ref = _challenges.doc(challenge.id);
        if (challenge.isOwner(me)) {
          // Clear progress and discussion first: once the challenge document
          // is gone, nobody can read or delete them any more.
          for (final sub in ['progress', 'messages']) {
            while (true) {
              final page = await ref.collection(sub).limit(400).get();
              if (page.docs.isEmpty) break;
              final batch = _db.batch();
              for (final d in page.docs) {
                batch.delete(d.reference);
              }
              await batch.commit();
            }
          }
          await ref.delete();
          return;
        }
        // Remove own progress first: once out of members it is unreadable.
        try {
          await ref.collection('progress').doc(me).delete();
        } on FirebaseException catch (e) {
          AppLogger.warning('progress cleanup failed: ${e.code}');
        }
        await ref.update({
          'members': FieldValue.arrayRemove([me]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  Future<void> removeMySocialData(SocialIdentity me) => _guard(() async {
    final outgoing = await watchOutgoingRequests(me.uid).first;
    for (final r in outgoing) {
      await cancelFriendRequest(me.uid, r);
    }
    final incoming = await watchIncomingRequests(me.uid).first;
    for (final r in incoming) {
      await declineFriendRequest(me.uid, r);
    }
    final invites = await watchChallengeInvites(me.uid).first;
    for (final c in invites) {
      await declineChallengeInvite(me.uid, c.id);
    }
    final challenges = await watchChallenges(me.uid).first;
    for (final c in challenges) {
      await leaveChallenge(me.uid, c);
    }
    final friends = await watchFriends(me.uid).first;
    for (final f in friends) {
      await _friendships.doc(f.id).delete();
    }
    final email = me.email;
    if (email != null && email.trim().isNotEmpty) {
      await _db.collection('emailIndex').doc(emailKeyOf(email)).delete();
    }
    await _profiles.doc(me.uid).delete();
  });

  @override
  Future<void> updateMyChallengeProgress(
    SocialIdentity me,
    String challengeId,
    List<bool> completed,
  ) => _guard(() async {
    final days = completed.where((d) => d).length;
    await _challenges.doc(challengeId).collection('progress').doc(me.uid).set({
      'uid': me.uid,
      'name': me.name,
      'days': days,
      'percent': (days / 40 * 100).round(),
      'cells': completed,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  });

  // ---------------------------------------------------------------------------

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SocialException {
      rethrow;
    } on FirebaseException catch (e, st) {
      AppLogger.error('Social Firestore error ${e.code}', e, st);
      throw SocialException(_messageFor(e.code), code: e.code);
    }
  }

  static String _messageFor(String code) => switch (code) {
    'permission-denied' =>
      'لم يُسمح بهذا الإجراء. قد تكون الحالة تغيّرت — حدّثي الصفحة وحاولي مجدداً.',
    'unavailable' || 'deadline-exceeded' =>
      'تعذّر الاتصال بالخادم. تحقّقي من الشبكة ثم أعيدي المحاولة.',
    'not-found' => 'لم يعد هذا العنصر موجوداً.',
    'unauthenticated' => 'سجّلي الدخول أولاً.',
    _ => 'حدث خطأ غير متوقّع. أعيدي المحاولة.',
  };
}
