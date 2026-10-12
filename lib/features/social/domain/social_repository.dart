import 'package:barakah40_flutter/features/social/domain/social_models.dart';

/// Signed-in user as the social layer needs it.
class SocialIdentity {
  const SocialIdentity({required this.uid, required this.name, this.email});

  final String uid;
  final String name;
  final String? email;
}

/// Where a message thread lives: a direct conversation or a challenge.
class ThreadRef {
  const ThreadRef.direct(this.id) : isGroup = false;
  const ThreadRef.challenge(this.id) : isGroup = true;

  final String id;
  final bool isGroup;

  String get parentPath => isGroup ? 'challenges/$id' : 'conversations/$id';

  @override
  bool operator ==(Object other) =>
      other is ThreadRef && other.id == id && other.isGroup == isGroup;

  @override
  int get hashCode => Object.hash(id, isGroup);
}

/// Friends, invitations, direct chat and group challenges.
///
/// Every write goes straight to Firestore and surfaces failures as
/// [SocialException]; nothing is reported as done before the server accepts
/// it (offline writes stay "pending" in the UI until acknowledged).
abstract class SocialRepository {
  /// Writes `profiles/{uid}` and `emailIndex/{email}` for the signed-in user.
  Future<void> publishProfile(SocialIdentity me);

  /// Exact email, or username/name prefix. Excludes [me].
  Future<List<PublicProfile>> searchUsers(String me, String query);

  Future<PublicProfile?> fetchProfile(String uid);

  Stream<List<Friendship>> watchFriends(String me);
  Stream<List<FriendRequest>> watchIncomingRequests(String me);
  Stream<List<FriendRequest>> watchOutgoingRequests(String me);

  Future<SendRequestResult> sendFriendRequest(
    SocialIdentity me,
    PublicProfile target,
  );
  Future<void> acceptFriendRequest(SocialIdentity me, FriendRequest request);
  Future<void> declineFriendRequest(String me, FriendRequest request);
  Future<void> cancelFriendRequest(String me, FriendRequest request);
  Future<void> unfriend(String me, String friendUid);

  /// Returns the id of the (possibly new) conversation with a friend.
  Future<String> openDirectConversation(
    SocialIdentity me,
    String friendUid,
    String friendName,
  );
  Stream<List<Conversation>> watchConversations(String me);
  Stream<Conversation?> watchConversation(String id);

  Stream<List<ChatMessage>> watchMessages(ThreadRef thread, {int limit = 100});
  Future<void> sendMessage(SocialIdentity me, ThreadRef thread, String text);
  Future<void> markConversationRead(String me, String conversationId);

  Stream<List<GroupChallenge>> watchChallenges(String me);
  Stream<GroupChallenge?> watchChallenge(String id);
  Stream<List<ChallengeMemberProgress>> watchChallengeProgress(String id);
  Future<String> createChallenge(
    SocialIdentity me, {
    required ChallengeType type,
    required String name,
    String? friendUid,
    String? friendName,
  });
  Future<void> addChallengeMember(String challengeId, String uid, String name);
  Future<void> removeChallengeMember(String challengeId, String uid);
  Future<void> leaveChallenge(String me, GroupChallenge challenge);
  Future<void> updateMyChallengeProgress(
    SocialIdentity me,
    String challengeId,
    List<bool> completed,
  );
}
