import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/new_challenge_sheet.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';

/// Friends tab: user search, my friends, incoming and outgoing requests.
class FriendsPanel extends ConsumerStatefulWidget {
  const FriendsPanel({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends ConsumerState<FriendsPanel> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final incoming = ref.watch(incomingRequestsProvider);
    final outgoing = ref.watch(visibleOutgoingRequestsProvider);
    final frN = friends.valueOrNull?.length ?? 0;
    final inN = incoming.valueOrNull?.length ?? 0;
    final outN = outgoing.valueOrNull?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const UserSearchBox(),
        const SizedBox(height: 8),
        LegacySegmentedTabs(
          dense: true,
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
          labels: [
            frN > 0 ? 'صديقاتي ($frN)' : 'صديقاتي',
            'طلبات واردة',
            outN > 0 ? 'طلبات مرسلة ($outN)' : 'طلبات مرسلة',
          ],
          badges: {1: inN},
        ),
        const SizedBox(height: 14),
        switch (_tab) {
          1 => _IncomingList(async: incoming),
          2 => _OutgoingList(async: outgoing),
          _ => _FriendList(async: friends),
        },
      ],
    );
  }
}

class _FriendList extends ConsumerWidget {
  const _FriendList({required this.async});

  final AsyncValue<List<Friendship>> async;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(socialIdentityProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => RetryNote(
        message: 'تعذّر تحميل الصديقات.',
        onRetry: () => ref.invalidate(friendsProvider),
      ),
      data: (list) {
        if (me == null) return const SizedBox.shrink();
        if (list.isEmpty) {
          return const EmptyNote(
            message:
                'لا صديقات بعد. ابحثي عن صديقتكِ بالاسم أو المعرّف أو البريد، وبعد قبولها تظهر هنا.',
          );
        }
        return Column(
          children: [
            for (final f in list) _FriendRow(friendship: f, me: me.uid),
          ],
        );
      },
    );
  }
}

class _FriendRow extends ConsumerStatefulWidget {
  const _FriendRow({required this.friendship, required this.me});

  final Friendship friendship;
  final String me;

  @override
  ConsumerState<_FriendRow> createState() => _FriendRowState();
}

class _FriendRowState extends ConsumerState<_FriendRow> {
  bool _busy = false;

  Future<void> _chat() async {
    final me = ref.read(socialIdentityProvider);
    if (me == null) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(socialRepositoryProvider)
          .openDirectConversation(
            me,
            widget.friendship.otherUid(widget.me),
            widget.friendship.otherName(widget.me),
          );
      if (mounted) context.push(AppRoutes.chatPath(id));
    } on SocialException catch (e) {
      if (mounted) showSocialSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final name = widget.friendship.otherName(widget.me);
    final ok = await confirmAction(
      context,
      title: 'إزالة صديقة',
      message:
          'إزالة $name من قائمتكِ؟ تبقى رسائلكما محفوظة لكن لن يمكنكما المراسلة.',
      confirmLabel: 'إزالة',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(socialRepositoryProvider)
          .unfriend(widget.me, widget.friendship.otherUid(widget.me));
      if (mounted) showSocialSnack(context, 'تمت الإزالة');
    } on SocialException catch (e) {
      if (mounted) showSocialSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friendship;
    final uid = f.otherUid(widget.me);
    final name = f.otherName(widget.me);
    return LegacyRow(
      child: Row(
        children: [
          SocialAvatar(uid: uid, name: name),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NameText(name),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    MiniButton(
                      label: 'مراسلة',
                      icon: Icons.chat_bubble_outline_rounded,
                      tone: MiniButtonTone.ok,
                      busy: _busy,
                      onPressed: _chat,
                    ),
                    MiniButton(
                      label: 'تحدٍّ',
                      onPressed: () => showNewChallengeSheet(
                        context,
                        presetFriendUid: uid,
                        presetFriendName: name,
                      ),
                    ),
                    MiniButton(
                      label: 'إزالة',
                      tone: MiniButtonTone.no,
                      onPressed: _remove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingList extends ConsumerWidget {
  const _IncomingList({required this.async});

  final AsyncValue<List<FriendRequest>> async;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => RetryNote(
        message: 'تعذّر تحميل الطلبات.',
        onRetry: () => ref.invalidate(incomingRequestsProvider),
      ),
      data: (list) => list.isEmpty
          ? const EmptyNote(message: 'لا طلبات صداقة واردة.')
          : Column(children: [for (final r in list) _IncomingRow(request: r)]),
    );
  }
}

class _IncomingRow extends ConsumerStatefulWidget {
  const _IncomingRow({required this.request});

  final FriendRequest request;

  @override
  ConsumerState<_IncomingRow> createState() => _IncomingRowState();
}

class _IncomingRowState extends ConsumerState<_IncomingRow> {
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

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final me = ref.watch(socialIdentityProvider);
    final repo = ref.read(socialRepositoryProvider);
    return LegacyRow(
      child: Row(
        children: [
          SocialAvatar(uid: r.from, name: r.fromName),
          const SizedBox(width: 11),
          Expanded(child: _NameText(r.fromName, sub: 'تريد إضافتكِ')),
          MiniButton(
            label: 'قبول',
            tone: MiniButtonTone.ok,
            busy: _busy == 'acc',
            onPressed: _busy != null || me == null
                ? null
                : () => _run(
                    'acc',
                    () => repo.acceptFriendRequest(me, r),
                    'تمّت إضافة ${r.fromName}',
                  ),
          ),
          const SizedBox(width: 6),
          MiniButton(
            label: 'رفض',
            tone: MiniButtonTone.no,
            busy: _busy == 'rej',
            onPressed: _busy != null || me == null
                ? null
                : () => _run(
                    'rej',
                    () => repo.declineFriendRequest(me.uid, r),
                    'رُفض الطلب',
                  ),
          ),
        ],
      ),
    );
  }
}

class _OutgoingList extends ConsumerWidget {
  const _OutgoingList({required this.async});

  final AsyncValue<List<FriendRequest>> async;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => RetryNote(
        message: 'تعذّر تحميل الطلبات.',
        onRetry: () => ref.invalidate(outgoingRequestsProvider),
      ),
      data: (list) => list.isEmpty
          ? const EmptyNote(
              message: 'لا طلبات مرسلة. ابحثي عن صديقتكِ من الأعلى.',
            )
          : Column(children: [for (final r in list) _OutgoingRow(request: r)]),
    );
  }
}

class _OutgoingRow extends ConsumerStatefulWidget {
  const _OutgoingRow({required this.request});

  final FriendRequest request;

  @override
  ConsumerState<_OutgoingRow> createState() => _OutgoingRowState();
}

class _OutgoingRowState extends ConsumerState<_OutgoingRow> {
  bool _busy = false;

  Future<void> _cancel() async {
    final me = ref.read(socialIdentityProvider);
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(socialRepositoryProvider)
          .cancelFriendRequest(me.uid, widget.request);
      if (mounted) showSocialSnack(context, 'أُلغي الطلب');
    } on SocialException catch (e) {
      if (mounted) showSocialSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return LegacyRow(
      child: Row(
        children: [
          SocialAvatar(uid: r.to, name: r.toName),
          const SizedBox(width: 11),
          Expanded(child: _NameText(r.toName, sub: 'بانتظار القبول')),
          MiniButton(
            label: 'إلغاء',
            tone: MiniButtonTone.no,
            busy: _busy,
            onPressed: _cancel,
          ),
        ],
      ),
    );
  }
}

/// Debounced search by exact email, username or name prefix.
class UserSearchBox extends ConsumerStatefulWidget {
  const UserSearchBox({super.key});

  @override
  ConsumerState<UserSearchBox> createState() => _UserSearchBoxState();
}

class _UserSearchBoxState extends ConsumerState<UserSearchBox> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<PublicProfile> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), _run);
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    final me = ref.read(socialIdentityProvider);
    if (me == null) return;
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _query = q;
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(socialRepositoryProvider)
          .searchUsers(me.uid, q);
      if (!mounted || _controller.text.trim() != q) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on SocialException catch (e) {
      if (!mounted || _controller.text.trim() != q) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.line),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: colors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('userSearchField'),
                  controller: _controller,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _run(),
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'ابحثي بالاسم أو المعرّف أو البريد',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'مسح',
                  icon: Icon(Icons.close_rounded, color: colors.muted),
                  onPressed: _clear,
                ),
            ],
          ),
        ),
        if (_query.isNotEmpty || _loading) ...[
          const SizedBox(height: 6),
          _buildResults(),
        ],
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) return const _Loading(label: 'جارٍ البحث…');
    if (_error != null) return RetryNote(message: _error!, onRetry: _run);
    if (_results.isEmpty) {
      return const EmptyNote(
        message:
            'لا نتائج مطابقة. جرّبي بداية الاسم أو المعرّف، أو البريد الإلكتروني كاملاً.',
      );
    }
    return Column(
      children: [for (final p in _results) SearchResultRow(profile: p)],
    );
  }
}

class SearchResultRow extends ConsumerStatefulWidget {
  const SearchResultRow({super.key, required this.profile});

  final PublicProfile profile;

  @override
  ConsumerState<SearchResultRow> createState() => _SearchResultRowState();
}

class _SearchResultRowState extends ConsumerState<SearchResultRow> {
  bool _busy = false;

  Future<void> _act(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted) showSocialSnack(context, message);
    } on SocialException catch (e) {
      if (mounted) showSocialSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final relation = ref.watch(friendRelationProvider(p.uid));
    final me = ref.watch(socialIdentityProvider);
    final repo = ref.read(socialRepositoryProvider);

    final Widget action = switch (relation) {
      FriendRelation.friend => const MiniButton(
        label: 'صديقة',
        icon: Icons.check_rounded,
        onPressed: null,
      ),
      FriendRelation.outgoing => MiniButton(
        label: 'إلغاء الطلب',
        tone: MiniButtonTone.no,
        busy: _busy,
        onPressed: () => _act(() async {
          final r = (ref.read(outgoingRequestsProvider).valueOrNull ?? [])
              .firstWhere((r) => r.to == p.uid);
          await repo.cancelFriendRequest(me!.uid, r);
          return 'أُلغي الطلب';
        }),
      ),
      FriendRelation.incoming => MiniButton(
        label: 'قبول',
        tone: MiniButtonTone.ok,
        busy: _busy,
        onPressed: () => _act(() async {
          final r = (ref.read(incomingRequestsProvider).valueOrNull ?? [])
              .firstWhere((r) => r.from == p.uid);
          await repo.acceptFriendRequest(me!, r);
          return 'تمّت إضافة ${p.name}';
        }),
      ),
      FriendRelation.self => const SizedBox.shrink(),
      FriendRelation.none => MiniButton(
        label: 'إضافة',
        icon: Icons.person_add_alt_1_rounded,
        tone: MiniButtonTone.ok,
        busy: _busy,
        onPressed: me == null
            ? null
            : () => _act(() async {
                final result = await repo.sendFriendRequest(me, p);
                return switch (result) {
                  SendRequestResult.sent => 'أُرسل الطلب إلى ${p.name}',
                  SendRequestResult.acceptedTheirs =>
                    '${p.name} أرسلت لكِ طلباً من قبل — أصبحتما صديقتين',
                  SendRequestResult.alreadyFriends => 'أنتما صديقتان بالفعل',
                  SendRequestResult.alreadyPending =>
                    'الطلب مُرسل وبانتظار القبول',
                };
              }),
      ),
    };

    return LegacyRow(
      child: Row(
        children: [
          SocialAvatar(uid: p.uid, name: p.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: _NameText(
              p.name,
              sub: p.username.isEmpty ? null : '@${p.username}',
              subLtr: true,
            ),
          ),
          action,
        ],
      ),
    );
  }
}

class _NameText extends StatelessWidget {
  const _NameText(this.name, {this.sub, this.subLtr = false});

  final String name;
  final String? sub;
  final bool subLtr;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'ReemKufi',
            fontSize: 15,
            color: colors.ink,
          ),
        ),
        if (sub != null)
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: subLtr ? TextDirection.ltr : null,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              color: colors.muted,
            ),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(label!, style: TextStyle(color: colors.muted, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}
