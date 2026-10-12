import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/social/data/firestore_social_repository.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/domain/social_repository.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/sync_status.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return FirestoreSocialRepository();
});

/// The signed-in user as seen by the social layer, or `null` when signed out.
final socialIdentityProvider = Provider<SocialIdentity?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final display = (user.displayName ?? '').trim();
  final name = display.isNotEmpty
      ? display
      : ((user.email ?? '').split('@').first.trim().isNotEmpty
            ? (user.email ?? '').split('@').first.trim()
            : 'صديقة بركة');
  return SocialIdentity(uid: user.uid, name: name, email: user.email);
});

final friendsProvider = StreamProvider<List<Friendship>>((ref) {
  final me = ref.watch(socialIdentityProvider);
  if (me == null) return Stream.value(const []);
  return ref.watch(socialRepositoryProvider).watchFriends(me.uid);
});

final incomingRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  final me = ref.watch(socialIdentityProvider);
  if (me == null) return Stream.value(const []);
  return ref.watch(socialRepositoryProvider).watchIncomingRequests(me.uid);
});

/// Pending requests I sent, minus any to someone who is already a friend
/// (a crossed request that the other side resolved by accepting theirs).
final outgoingRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  final me = ref.watch(socialIdentityProvider);
  if (me == null) return Stream.value(const []);
  return ref.watch(socialRepositoryProvider).watchOutgoingRequests(me.uid);
});

final visibleOutgoingRequestsProvider =
    Provider<AsyncValue<List<FriendRequest>>>((ref) {
      final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
      final me = ref.watch(socialIdentityProvider)?.uid ?? '';
      final friendUids = {for (final f in friends) f.otherUid(me)};
      return ref
          .watch(outgoingRequestsProvider)
          .whenData(
            (list) => list.where((r) => !friendUids.contains(r.to)).toList(),
          );
    });

/// Pending requests to me, minus any from someone who is already a friend
/// (left behind when two people invited each other at the same moment).
final visibleIncomingRequestsProvider =
    Provider<AsyncValue<List<FriendRequest>>>((ref) {
      final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
      final me = ref.watch(socialIdentityProvider)?.uid ?? '';
      final friendUids = {for (final f in friends) f.otherUid(me)};
      return ref
          .watch(incomingRequestsProvider)
          .whenData(
            (list) => list.where((r) => !friendUids.contains(r.from)).toList(),
          );
    });

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final me = ref.watch(socialIdentityProvider);
  if (me == null) return Stream.value(const []);
  return ref.watch(socialRepositoryProvider).watchConversations(me.uid);
});

final unreadTotalProvider = Provider<int>((ref) {
  final me = ref.watch(socialIdentityProvider)?.uid;
  if (me == null) return 0;
  final list = ref.watch(conversationsProvider).valueOrNull ?? const [];
  return list.fold(0, (sum, c) => sum + c.unreadFor(me));
});

/// Badge for the community entry point: unread messages + incoming requests.
final communityBadgeProvider = Provider<int>((ref) {
  final requests =
      ref.watch(visibleIncomingRequestsProvider).valueOrNull ?? const [];
  final invites = ref.watch(challengeInvitesProvider).valueOrNull ?? const [];
  return ref.watch(unreadTotalProvider) + requests.length + invites.length;
});

final conversationProvider = StreamProvider.autoDispose
    .family<Conversation?, String>((ref, id) {
      return ref.watch(socialRepositoryProvider).watchConversation(id);
    });

final messagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, ThreadRef>((ref, thread) {
      return ref.watch(socialRepositoryProvider).watchMessages(thread);
    });

final challengesProvider = StreamProvider<List<GroupChallenge>>((ref) {
  final me = ref.watch(socialIdentityProvider);
  if (me == null) return Stream.value(const []);
  return ref.watch(socialRepositoryProvider).watchChallenges(me.uid);
});

final challengeInvitesProvider = StreamProvider<List<GroupChallenge>>((ref) {
  final me = ref.watch(socialIdentityProvider);
  if (me == null) return Stream.value(const []);
  return ref.watch(socialRepositoryProvider).watchChallengeInvites(me.uid);
});

final challengeProvider = StreamProvider.autoDispose
    .family<GroupChallenge?, String>((ref, id) {
      return ref.watch(socialRepositoryProvider).watchChallenge(id);
    });

final challengeProgressProvider = StreamProvider.autoDispose
    .family<List<ChallengeMemberProgress>, String>((ref, id) {
      return ref.watch(socialRepositoryProvider).watchChallengeProgress(id);
    });

/// Relationship to another user, derived from the live streams so it stays
/// in sync on both devices without extra reads.
final friendRelationProvider = Provider.family<FriendRelation, String>((
  ref,
  uid,
) {
  final me = ref.watch(socialIdentityProvider)?.uid;
  if (me == null) return FriendRelation.none;
  if (uid == me) return FriendRelation.self;
  final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
  if (friends.any((f) => f.users.contains(uid))) return FriendRelation.friend;
  final incoming = ref.watch(incomingRequestsProvider).valueOrNull ?? const [];
  if (incoming.any((r) => r.from == uid)) return FriendRelation.incoming;
  final outgoing = ref.watch(outgoingRequestsProvider).valueOrNull ?? const [];
  if (outgoing.any((r) => r.to == uid)) return FriendRelation.outgoing;
  return FriendRelation.none;
});

/// Background sync kept alive by the signed-in shell:
/// - publishes the public profile + email index once per signed-in uid;
/// - mirrors challenge-day completion into every challenge's progress row
///   (legacy `socSyncProgress`).
final socialSyncProvider = Provider<void>((ref) {
  final me = ref.watch(socialIdentityProvider);
  if (me == null) return;
  final repo = ref.watch(socialRepositoryProvider);

  repo.publishProfile(me).catchError((Object e) {
    AppLogger.warning('publishProfile failed: $e');
  });

  // Never mirror the empty placeholder state over real remote progress.
  const loading = {
    SyncStatus.initial,
    SyncStatus.loadingLocal,
    SyncStatus.loadingRemote,
  };
  var lastSynced = <String, int>{};
  void sync() {
    if (loading.contains(ref.read(userSyncStatusProvider))) return;
    final completed = ref.read(userAppStateProvider).completed;
    final days = completed.where((d) => d).length;
    final challenges = ref.read(challengesProvider).valueOrNull ?? const [];
    final next = <String, int>{};
    for (final c in challenges) {
      next[c.id] = days;
      if (lastSynced[c.id] == days) continue;
      repo.updateMyChallengeProgress(me, c.id, completed).catchError((
        Object e,
      ) {
        AppLogger.warning('challenge progress sync failed: $e');
      });
    }
    lastSynced = next;
  }

  ref.listen(challengesProvider, (_, _) => sync());
  ref.listen(userSyncStatusProvider, (_, _) => sync());
  ref.listen(
    userAppStateProvider.select((s) => s.completed.where((d) => d).length),
    (_, _) => sync(),
  );
});
