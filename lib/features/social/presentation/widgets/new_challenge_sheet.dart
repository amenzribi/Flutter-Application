import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';

/// Legacy "تحدٍّ جديد" flow: solo, with one friend (duo), or a group.
Future<void> showNewChallengeSheet(
  BuildContext context, {
  String? presetFriendUid,
  String? presetFriendName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _NewChallengeSheet(
      presetFriendUid: presetFriendUid,
      presetFriendName: presetFriendName,
    ),
  );
}

class _NewChallengeSheet extends ConsumerStatefulWidget {
  const _NewChallengeSheet({this.presetFriendUid, this.presetFriendName});

  final String? presetFriendUid;
  final String? presetFriendName;

  @override
  ConsumerState<_NewChallengeSheet> createState() => _NewChallengeSheetState();
}

class _NewChallengeSheetState extends ConsumerState<_NewChallengeSheet> {
  late ChallengeType _type = widget.presetFriendUid != null
      ? ChallengeType.duo
      : ChallengeType.group;
  late final _name = TextEditingController(
    text: widget.presetFriendName != null
        ? 'تحدّي البقرة مع ${widget.presetFriendName}'
        : 'تحدّي البقرة',
  );
  late String? _friendUid = widget.presetFriendUid;
  late String? _friendName = widget.presetFriendName;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final me = ref.read(socialIdentityProvider);
    if (me == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(socialRepositoryProvider)
          .createChallenge(
            me,
            type: _type,
            name: _name.text,
            friendUid: _type == ChallengeType.duo ? _friendUid : null,
            friendName: _type == ChallengeType.duo ? _friendName : null,
          );
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(AppRoutes.challengeDetailPath(id));
    } on SocialException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final me = ref.watch(socialIdentityProvider)?.uid ?? '';
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
    final types = ChallengeType.values;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تحدٍّ جديد',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            LegacySegmentedTabs(
              dense: true,
              labels: [for (final t in types) t.arabicLabel],
              selected: types.indexOf(_type),
              onSelected: (i) => setState(() => _type = types[i]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'اسم التحدّي'),
            ),
            if (_type == ChallengeType.duo) ...[
              const SizedBox(height: 4),
              Text(
                'اختاري صديقة',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (friends.isEmpty)
                const EmptyNote(message: 'أضيفي صديقة أولاً من تبويب الأصدقاء.')
              else
                for (final f in friends)
                  LegacyRow(
                    onTap: () => setState(() {
                      _friendUid = f.otherUid(me);
                      _friendName = f.otherName(me);
                    }),
                    child: Row(
                      children: [
                        SocialAvatar(
                          uid: f.otherUid(me),
                          name: f.otherName(me),
                        ),
                        const SizedBox(width: 11),
                        Expanded(child: Text(f.otherName(me))),
                        Icon(
                          _friendUid == f.otherUid(me)
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: colors.olive,
                        ),
                      ],
                    ),
                  ),
            ],
            if (_type == ChallengeType.duo && friends.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'تصل صديقتكِ دعوة، وتنضمّ إلى التحدّي عندما تقبلها.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_type == ChallengeType.group)
              Text(
                'بعد الإنشاء ادعي صديقاتكِ من صفحة التحدّي. يمكن لكل عضوة دعوة صديقاتها، وتنضمّ كل واحدة عندما تقبل.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: colors.danger)),
            ],
            const SizedBox(height: 16),
            PremiumButton(
              label: 'إنشاء التحدّي',
              icon: Icons.flag_outlined,
              busy: _busy,
              onPressed: _type == ChallengeType.duo && _friendUid == null
                  ? null
                  : _create,
            ),
          ],
        ),
      ),
    );
  }
}
