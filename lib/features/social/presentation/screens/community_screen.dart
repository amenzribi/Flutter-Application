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
        ref.watch(incomingRequestsProvider).valueOrNull?.length ?? 0;
    final unread = ref.watch(unreadTotalProvider);

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
                badges: {0: requests, 1: unread},
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumButton(
          label: 'تحدٍّ جديد',
          icon: Icons.add_rounded,
          onPressed: () => showNewChallengeSheet(context),
        ),
        const SizedBox(height: 14),
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
                                        c.lastMessage != null
                                            ? c.lastMessage!.text
                                            : '${c.type.arabicLabel} · ${c.members.length} عضوات',
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
}
