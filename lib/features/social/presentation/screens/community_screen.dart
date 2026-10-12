import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/home/presentation/providers/home_providers.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/friends_panel.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/new_challenge_sheet.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Legacy "المجتمع" view: friends, conversations and challenges.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final requests =
        ref.watch(visibleIncomingRequestsProvider).valueOrNull?.length ?? 0;
    final unread = ref.watch(unreadTotalProvider);
    final invites =
        ref.watch(challengeInvitesProvider).valueOrNull?.length ?? 0;

    return PremiumScaffold(
      style: PremiumScaffoldStyle.photo,
      backgroundImage: ref.watch(dayPeriodProvider).backgroundAsset,
      // A bottom-nav tab: back only appears when it was pushed.
      appBar: AppBar(foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ResponsiveContent(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.groups_2_outlined, size: 30, color: colors.gold),
              const SizedBox(height: 6),
              Text(
                'المجتمع',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'تحدَّوا معاً في الخير',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 16),
              LegacySegmentedTabs(
                selected: _tab,
                onSelected: (i) => setState(() => _tab = i),
                labels: const ['الأصدقاء', 'المحادثات', 'التحديات'],
                icons: const [
                  Icons.people_alt_outlined,
                  Icons.chat_bubble_outline_rounded,
                  Icons.grid_view_rounded,
                ],
                badges: {0: requests, 1: unread, 2: invites},
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.line),
                ),
                child: switch (_tab) {
                  1 => const _ConversationsPanel(),
                  2 => const _ChallengesPanel(),
                  _ => const FriendsPanel(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationsPanel extends ConsumerWidget {
  const _ConversationsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(socialIdentityProvider)?.uid ?? '';
    final colors = context.barakahColors;
    return ref
        .watch(conversationsProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => RetryNote(
            message: 'تعذّر تحميل المحادثات.',
            onRetry: () => ref.invalidate(conversationsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyNote(
                message:
                    'لا محادثات بعد. افتحي تبويب الأصدقاء واضغطي «مراسلة» بجانب صديقتكِ.',
              );
            }
            return Column(
              children: [
                for (final c in list)
                  LegacyRow(
                    onTap: () => context.push(AppRoutes.chatPath(c.id)),
                    child: Row(
                      children: [
                        SocialAvatar(
                          uid: c.otherUid(me),
                          name: c.otherName(me),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.otherName(me),
                                style: TextStyle(
                                  fontFamily: 'ReemKufi',
                                  fontSize: 15,
                                  color: colors.ink,
                                ),
                              ),
                              Text(
                                _preview(c, me),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.unreadFor(me) > 0
                                      ? colors.ink
                                      : colors.muted,
                                  fontWeight: c.unreadFor(me) > 0
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _when(c.lastMessage?.sentAt ?? c.updatedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (c.unreadFor(me) > 0)
                              CountBadge(count: c.unreadFor(me)),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
  }

  static String _preview(Conversation c, String me) {
    final m = c.lastMessage;
    if (m == null) return 'لا رسائل بعد';
    return m.senderId == me ? 'أنتِ: ${m.text}' : m.text;
  }

  static String _when(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return DateFormat('h:mm a', 'ar').format(at);
    }
    return DateFormat('d MMM', 'ar').format(at);
  }
}

class _ChallengesPanel extends ConsumerWidget {
  const _ChallengesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.barakahColors;
    final invites = ref.watch(challengeInvitesProvider).valueOrNull ?? const [];
    final me = ref.watch(socialIdentityProvider)?.uid ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumButton(
          label: 'تحدٍّ جديد',
          icon: Icons.add_rounded,
          onPressed: () => showNewChallengeSheet(context),
        ),
        const SizedBox(height: 14),
        if (invites.isNotEmpty) ...[
          Text('دعوات إلى تحديات', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final c in invites) _ChallengeInviteRow(challenge: c, me: me),
          const SizedBox(height: 10),
        ],
        ref
            .watch(challengesProvider)
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => RetryNote(
                message: 'تعذّر تحميل التحديات.',
                onRetry: () => ref.invalidate(challengesProvider),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyNote(
                      message:
                          'لا تحديات مشتركة بعد. أنشئي تحدّياً فردياً أو مع صديقة أو مجموعة.',
                    )
                  : Column(
                      children: [
                        for (final c in list)
                          LegacyRow(
                            onTap: () => context.push(
                              AppRoutes.challengeDetailPath(c.id),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colors.oliveSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    c.type == ChallengeType.solo
                                        ? Icons.person_outline
                                        : Icons.groups_2_outlined,
                                    color: colors.olive,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'ReemKufi',
                                          fontSize: 15,
                                          color: colors.ink,
                                        ),
                                      ),
                                      Text(
                                        _subtitle(c),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_left, color: colors.muted),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
      ],
    );
  }

  static String _subtitle(GroupChallenge c) {
    if (c.lastMessage != null) return c.lastMessage!.text;
    if (c.type == ChallengeType.duo && c.members.length < 2) {
      if (c.invited.isNotEmpty) {
        return 'بانتظار قبول ${c.nameOf(c.invited.first)}';
      }
      if (c.declined.isNotEmpty) {
        return 'اعتذرت ${c.nameOf(c.declined.last)} عن التحدّي';
      }
    }
    final pending = c.invited.isEmpty ? '' : ' · ${c.invited.length} بانتظار';
    return '${c.type.arabicLabel} · ${c.members.length} عضوات$pending';
  }
}

/// A challenge a friend invited me to: accept to join, or decline.
class _ChallengeInviteRow extends ConsumerStatefulWidget {
  const _ChallengeInviteRow({required this.challenge, required this.me});

  final GroupChallenge challenge;
  final String me;

  @override
  ConsumerState<_ChallengeInviteRow> createState() =>
      _ChallengeInviteRowState();
}

class _ChallengeInviteRowState extends ConsumerState<_ChallengeInviteRow> {
  String? _busy;

  Future<void> _run(String key, Future<void> Function() action) async {
    // Captured up front: once answered, the invitation leaves the live list
    // and this row is disposed before the write returns.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = key);
    try {
      await action();
      if (key == 'acc') {
        router.push(AppRoutes.challengeDetailPath(widget.challenge.id));
      } else {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('اعتذرتِ عن التحدّي')));
      }
    } on SocialException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final me = ref.watch(socialIdentityProvider);
    final repo = ref.read(socialRepositoryProvider);
    final colors = context.barakahColors;
    return LegacyRow(
      child: Row(
        children: [
          SocialAvatar(uid: c.ownerUid, name: c.nameOf(c.ownerUid)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ReemKufi',
                    fontSize: 15,
                    color: colors.ink,
                  ),
                ),
                Text(
                  'دعوة من ${c.nameOf(c.ownerUid)} · ${c.type.arabicLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ],
            ),
          ),
          MiniButton(
            label: 'قبول',
            tone: MiniButtonTone.ok,
            busy: _busy == 'acc',
            onPressed: _busy != null || me == null
                ? null
                : () => _run('acc', () => repo.acceptChallengeInvite(me, c.id)),
          ),
          const SizedBox(width: 6),
          MiniButton(
            label: 'اعتذار',
            tone: MiniButtonTone.no,
            busy: _busy == 'dec',
            onPressed: _busy != null || me == null
                ? null
                : () => _run(
                    'dec',
                    () => repo.declineChallengeInvite(me.uid, c.id),
                  ),
          ),
        ],
      ),
    );
  }
}
