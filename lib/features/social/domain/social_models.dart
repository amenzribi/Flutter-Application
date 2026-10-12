/// Social layer models: profiles, friend requests, friendships, direct
/// conversations, group challenges and their messages.
///
/// Firestore layout and invariants are documented in
/// `docs/SOCIAL_DATA_MODEL.md` and enforced by `firebase/firestore.rules`.
library;

/// Deterministic id for anything owned by exactly two users (friendship,
/// direct conversation): the two uids sorted and joined with `_`.
String socialPairId(String a, String b) =>
    a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

/// Friend request doc id: one per direction.
String friendRequestId(String from, String to) => '${from}_$to';

/// Lowercased email used as the `emailIndex` doc id.
String emailKeyOf(String email) => email.trim().toLowerCase();

/// Search key for names: lower case, Arabic diacritics and tatweel removed,
/// letter variants unified (أ إ آ ٱ → ا, ة → ه, ى → ي, ؤ → و, ئ → ي), spaces
/// collapsed. Stored as `profiles.nameKey` and applied to name queries, so
/// "امينة" finds "أمينة".
String nameSearchKey(String name) {
  var s = name.trim().toLowerCase();
  s = s.replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '');
  s = s
      .replaceAll(RegExp('[\u0623\u0625\u0622\u0671]'), '\u0627')
      .replaceAll('\u0629', '\u0647')
      .replaceAll('\u0649', '\u064A')
      .replaceAll('\u0624', '\u0648')
      .replaceAll('\u0626', '\u064A');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s.length > 60 ? s.substring(0, 60) : s;
}

/// Legacy `Social.usernameOf`: email local part, else the name without
/// spaces, restricted to `[a-z0-9._-]`.
String usernameOf(String? email, String? name) {
  final local = (email ?? '').split('@').first.toLowerCase();
  var username = local.replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  if (username.isEmpty) {
    username = (name ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  }
  if (username.isEmpty) username = 'user';
  return username.length > 40 ? username.substring(0, 40) : username;
}

DateTime? _toDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  // cloud_firestore Timestamp, without importing it into the domain layer.
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.value is String) entry.key.toString(): entry.value as String,
  };
}

List<String> _stringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

/// Public, searchable profile at `profiles/{uid}`. Never contains email.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.name,
    required this.username,
    this.treeStage,
    this.treeHealthy,
  });

  final String uid;
  final String name;
  final String username;
  final int? treeStage;
  final bool? treeHealthy;

  String get initial =>
      name.isEmpty ? '؟' : String.fromCharCode(name.runes.first);

  factory PublicProfile.fromMap(String uid, Map<String, dynamic> data) {
    return PublicProfile(
      uid: uid,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'صديقة بركة',
      username: data['username'] as String? ?? '',
      treeStage: (data['treeStage'] as num?)?.toInt(),
      treeHealthy: data['treeHealthy'] as bool?,
    );
  }
}

enum FriendRequestStatus {
  pending,
  accepted,
  declined,
  cancelled;

  static FriendRequestStatus parse(Object? raw) =>
      FriendRequestStatus.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => FriendRequestStatus.cancelled,
      );
}

/// `friendRequests/{from}_{to}`.
class FriendRequest {
  const FriendRequest({
    required this.from,
    required this.to,
    required this.fromName,
    required this.toName,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String from;
  final String to;
  final String fromName;
  final String toName;
  final FriendRequestStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get id => friendRequestId(from, to);

  /// The other party, seen from [me].
  String otherUid(String me) => from == me ? to : from;
  String otherName(String me) => from == me ? toName : fromName;

  factory FriendRequest.fromMap(Map<String, dynamic> data) {
    return FriendRequest(
      from: data['from'] as String? ?? '',
      to: data['to'] as String? ?? '',
      fromName: data['fromName'] as String? ?? '',
      toName: data['toName'] as String? ?? '',
      status: FriendRequestStatus.parse(data['status']),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }
}

/// `friendships/{lowUid}_{highUid}`.
class Friendship {
  const Friendship({
    required this.id,
    required this.users,
    required this.names,
    this.since,
  });

  final String id;
  final List<String> users;
  final Map<String, String> names;
  final DateTime? since;

  String otherUid(String me) =>
      users.firstWhere((u) => u != me, orElse: () => '');

  String otherName(String me) {
    final name = names[otherUid(me)];
    return name == null || name.trim().isEmpty ? 'صديقة' : name;
  }

  factory Friendship.fromMap(String id, Map<String, dynamic> data) {
    return Friendship(
      id: id,
      users: _stringList(data['users']),
      names: _stringMap(data['names']),
      since: _toDate(data['since']),
    );
  }
}

/// Relationship between the signed-in user and another user.
enum FriendRelation { self, friend, outgoing, incoming, none }

class LastMessage {
  const LastMessage({required this.text, required this.senderId, this.sentAt});

  final String text;
  final String senderId;
  final DateTime? sentAt;

  static LastMessage? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return LastMessage(
      text: raw['text'] as String? ?? '',
      senderId: raw['senderId'] as String? ?? '',
      sentAt: _toDate(raw['sentAt']),
    );
  }
}

/// `conversations/{pairId}` — one direct conversation per friendship.
class Conversation {
  const Conversation({
    required this.id,
    required this.members,
    required this.names,
    this.lastMessage,
    this.updatedAt,
    this.unread = const {},
  });

  final String id;
  final List<String> members;
  final Map<String, String> names;
  final LastMessage? lastMessage;
  final DateTime? updatedAt;
  final Map<String, int> unread;

  String otherUid(String me) =>
      members.firstWhere((u) => u != me, orElse: () => '');

  String otherName(String me) {
    final name = names[otherUid(me)];
    return name == null || name.trim().isEmpty ? 'صديقة' : name;
  }

  int unreadFor(String me) => unread[me] ?? 0;

  factory Conversation.fromMap(String id, Map<String, dynamic> data) {
    final unreadRaw = data['unread'];
    return Conversation(
      id: id,
      members: _stringList(data['members']),
      names: _stringMap(data['names']),
      lastMessage: LastMessage.fromMap(data['lastMessage']),
      updatedAt: _toDate(data['updatedAt']),
      unread: unreadRaw is Map
          ? {
              for (final e in unreadRaw.entries)
                if (e.value is num) e.key.toString(): (e.value as num).toInt(),
            }
          : const {},
    );
  }
}

/// A message in a direct conversation or a challenge discussion.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.createdAt,
    this.pending = false,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;

  /// Server time; an estimate while [pending].
  final DateTime? createdAt;

  /// Written locally but not yet acknowledged by the server.
  final bool pending;

  static const maxLength = 2000;

  factory ChatMessage.fromMap(
    String id,
    Map<String, dynamic> data, {
    bool pending = false,
  }) {
    return ChatMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: _toDate(data['createdAt']),
      pending: pending,
    );
  }
}

enum ChallengeType {
  solo,
  duo,
  group;

  static ChallengeType parse(Object? raw) => ChallengeType.values.firstWhere(
    (t) => t.name == raw,
    orElse: () => ChallengeType.group,
  );

  String get arabicLabel => switch (this) {
    ChallengeType.solo => 'فردي',
    ChallengeType.duo => 'مع صديقة',
    ChallengeType.group => 'جماعي',
  };
}

/// `challenges/{cid}` — legacy solo/duo/group 40-day challenge. Group and duo
/// challenges carry a member-only discussion (`messages` subcollection).
class GroupChallenge {
  const GroupChallenge({
    required this.id,
    required this.type,
    required this.name,
    required this.ownerUid,
    required this.members,
    required this.names,
    this.goalDays = 40,
    this.createdAt,
    this.lastMessage,
    this.updatedAt,
  });

  final String id;
  final ChallengeType type;
  final String name;
  final String ownerUid;
  final List<String> members;
  final Map<String, String> names;
  final int goalDays;
  final DateTime? createdAt;
  final LastMessage? lastMessage;
  final DateTime? updatedAt;

  bool isOwner(String uid) => ownerUid == uid;

  String nameOf(String uid) {
    final name = names[uid];
    return name == null || name.trim().isEmpty ? 'صديقة' : name;
  }

  bool get hasDiscussion => type != ChallengeType.solo;

  factory GroupChallenge.fromMap(String id, Map<String, dynamic> data) {
    return GroupChallenge(
      id: id,
      type: ChallengeType.parse(data['type']),
      name: data['name'] as String? ?? 'تحدٍّ',
      ownerUid: data['ownerUid'] as String? ?? '',
      members: _stringList(data['members']),
      names: _stringMap(data['names']),
      goalDays: (data['goalDays'] as num?)?.toInt() ?? 40,
      createdAt: _toDate(data['createdAt']),
      lastMessage: LastMessage.fromMap(data['lastMessage']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }
}

/// `challenges/{cid}/progress/{uid}` (legacy shape).
class ChallengeMemberProgress {
  const ChallengeMemberProgress({
    required this.uid,
    required this.name,
    required this.days,
    required this.percent,
  });

  final String uid;
  final String name;
  final int days;
  final int percent;

  factory ChallengeMemberProgress.fromMap(Map<String, dynamic> data) {
    return ChallengeMemberProgress(
      uid: data['uid'] as String? ?? '',
      name: data['name'] as String? ?? 'صديقة',
      days: (data['days'] as num?)?.toInt() ?? 0,
      percent: (data['percent'] as num?)?.toInt() ?? 0,
    );
  }
}

/// User-facing failure with an Arabic message. Thrown by the repository for
/// expected refusals (self-invite, already friends, permission denied…).
class SocialException implements Exception {
  const SocialException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'SocialException($code): $message';
}

/// Outcome of [SocialRepository.sendFriendRequest].
enum SendRequestResult {
  /// A new pending request was written.
  sent,

  /// The other user had already invited us; we accepted instead.
  acceptedTheirs,

  /// Already friends; nothing written.
  alreadyFriends,

  /// A pending request from us already exists; nothing written.
  alreadyPending,
}
