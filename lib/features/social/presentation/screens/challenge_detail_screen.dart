import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/domain/social_repository.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/message_thread_view.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';

/// Shared challenge: progress leaderboard, discussion and members.
class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeDetailScreen> createState() =>
      _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  int _tab = 0;

  void _back() => context.canPop()
      ? context.pop()
      : context.go('${AppRoutes.community}?tab=2');

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final async = ref.watch(challengeProvider(widget.challengeId));
    final me = ref.watch(socialIdentityProvider)?.uid ?? '';

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text(async.valueOrNull?.name ?? 'التحدّي'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Removed members lose read access: the listener errors with
        // permission-denied, which we present as "no longer a member".
        error: (e, _) => const _Gone(),
        data: (c) {
          if (c == null || !c.members.contains(me)) return const _Gone();
          final tabs = ['التقدّم', if (c.hasDiscussion) 'النقاش', 'العضوات'];
          final tab = _tab.clamp(0, tabs.length - 1);
          final label = tabs[tab];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: LegacySegmentedTabs(
                  dense: true,
                  labels: tabs,
                  selected: tab,
                  onSelected: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: switch (label) {
                  'النقاش' => MessageThreadView(
                    thread: ThreadRef.challenge(c.id),
                    showSenderNames: true,
                  ),
                  'العضوات' => _MembersTab(challenge: c, me: me),
                  _ => _ProgressTab(challenge: c),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyNote(message: 'لستِ عضوة في هذا التحدّي، أو أنه حُذف.'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('${AppRoutes.community}?tab=2'),
              child: const Text('العودة إلى التحديات'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTab extends ConsumerWidget {
  const _ProgressTab({required this.challenge});

  final GroupChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.barakahColors;
    final rows = ref.watch(challengeProgressProvider(challenge.id));
    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: RetryNote(
          message: 'تعذّر تحميل التقدّم.',
          onRetry: () =>
              ref.invalidate(challengeProgressProvider(challenge.id)),
        ),
      ),
      data: (list) {
        final byUid = {for (final r in list) r.uid: r};
        final members = [
          ...challenge.members,
        ]..sort((a, b) => (byUid[b]?.days ?? 0).compareTo(byUid[a]?.days ?? 0));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              'يتحدّث تقدّمكِ تلقائياً عند تعليم أيام تحدّي الأربعين.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            for (final uid in members)
              LegacyRow(
                child: Row(
                  children: [
                    SocialAvatar(uid: uid, name: challenge.nameOf(uid)),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            byUid[uid]?.name ?? challenge.nameOf(uid),
                            style: TextStyle(
                              fontFamily: 'ReemKufi',
                              fontSize: 15,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value:
                                  (byUid[uid]?.days ?? 0) / challenge.goalDays,
                              minHeight: 7,
                              backgroundColor: colors.line,
                              color: colors.olive,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      byUid[uid] == null
                          ? 'لم تبدأ'
                          : '${byUid[uid]!.days}/${challenge.goalDays}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.oliveDeep,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MembersTab extends ConsumerStatefulWidget {
  const _MembersTab({required this.challenge, required this.me});

  final GroupChallenge challenge;
  final String me;

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  String? _busy;

  Future<void> _run(
    String key,
    Future<void> Function() action,
    String ok,
  ) async {
    setState(() => _busy = key);
    try {
      await action();
      if (mounted) showSocialSnack(context, ok);
    } on SocialException catch (e) {
      if (mounted) showSocialSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _leave() async {
    final c = widget.challenge;
    final owner = c.isOwner(widget.me);
    final ok = await confirmAction(
      context,
      title: owner ? 'حذف التحدّي' : 'مغادرة التحدّي',
      message: owner
          ? 'أنتِ منشئة التحدّي؛ مغادرته تحذفه لجميع العضوات مع نقاشه. متابعة؟'
          : 'مغادرة «${c.name}»؟ لن تري النقاش بعد ذلك.',
      confirmLabel: owner ? 'حذف' : 'مغادرة',
      destructive: true,
    );
    if (!ok || !mounted) return;
    // Captured up front: once we are out of `members` the page swaps to the
    // "gone" view and this state is disposed before the write returns.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = 'leave');
    try {
      await ref.read(socialRepositoryProvider).leaveChallenge(widget.me, c);
      router.go('${AppRoutes.community}?tab=2');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(owner ? 'حُذف التحدّي' : 'غادرتِ التحدّي')),
        );
    } on SocialException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final me = widget.me;
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
    final addable = [
      for (final f in friends)
        if (!c.members.contains(f.otherUid(me))) f,
    ];
    final repo = ref.read(socialRepositoryProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final uid in c.members)
          LegacyRow(
            child: Row(
              children: [
                SocialAvatar(uid: uid, name: c.nameOf(uid)),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    uid == me ? '${c.nameOf(uid)} (أنتِ)' : c.nameOf(uid),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.isOwner(uid))
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 6),
                    child: Text('المنشئة', style: TextStyle(fontSize: 12)),
                  )
                else if (c.isOwner(me))
                  MiniButton(
                    label: 'إزالة',
                    tone: MiniButtonTone.no,
                    busy: _busy == uid,
                    onPressed: _busy != null
                        ? null
                        : () => _run(
                            uid,
                            () => repo.removeChallengeMember(c.id, uid),
                            'أُزيلت ${c.nameOf(uid)}',
                          ),
                  ),
              ],
            ),
          ),
        if (c.type == ChallengeType.group) ...[
          const SizedBox(height: 12),
          Text(
            'إضافة من صديقاتكِ',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (addable.isEmpty)
            const EmptyNote(
              message: 'كل صديقاتكِ في التحدّي، أو لا صديقات بعد.',
            )
          else
            for (final f in addable)
              LegacyRow(
                child: Row(
                  children: [
                    SocialAvatar(uid: f.otherUid(me), name: f.otherName(me)),
                    const SizedBox(width: 11),
                    Expanded(child: Text(f.otherName(me))),
                    MiniButton(
                      label: 'إضافة',
                      tone: MiniButtonTone.ok,
                      busy: _busy == f.id,
                      onPressed: _busy != null
                          ? null
                          : () => _run(
                              f.id,
                              () => repo.addChallengeMember(
                                c.id,
                                f.otherUid(me),
                                f.otherName(me),
                              ),
                              'أُضيفت ${f.otherName(me)}',
                            ),
                    ),
                  ],
                ),
              ),
        ],
        const SizedBox(height: 20),
        MiniButton(
          label: c.isOwner(me) ? 'حذف التحدّي' : 'مغادرة التحدّي',
          icon: Icons.logout_rounded,
          tone: MiniButtonTone.no,
          busy: _busy == 'leave',
          onPressed: _busy != null ? null : _leave,
        ),
      ],
    );
  }
}
