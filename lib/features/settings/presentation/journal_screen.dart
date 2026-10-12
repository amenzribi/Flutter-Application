import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/constants/app_assets.dart';
import 'package:barakah40_flutter/core/utils/arabic_numbers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';
import 'package:barakah40_flutter/features/user_state/presentation/controllers/user_state_controller.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Legacy "نيّتي اليوم" (`openIntention`) and "دفتر المشاعر"
/// (`openJournal`) on one page, saved in `S.intention` and `S.journal`.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  late final _intention = TextEditingController(
    text:
        (ref
                .read(userAppStateProvider)
                .intention[UserStateController.intentionKey(DateTime.now())]
            as String?) ??
        '',
  );
  final _entry = TextEditingController();

  @override
  void dispose() {
    _intention.dispose();
    _entry.dispose();
    super.dispose();
  }

  void _saveIntention() {
    ref
        .read(userStateControllerProvider.notifier)
        .setIntentionToday(_intention.text);
    FocusScope.of(context).unfocus();
    showSocialSnack(context, 'نيّتك محفوظة');
  }

  void _addEntry() {
    final text = _entry.text.trim();
    if (text.isEmpty) return;
    final d = DateTime.now();
    ref
        .read(userStateControllerProvider.notifier)
        .addJournalEntry(
          text,
          '${arabicDigits(d.day)}/${arabicDigits(d.month)}/${arabicDigits(d.year)}',
        );
    _entry.clear();
    FocusScope.of(context).unfocus();
    showSocialSnack(context, 'أُضيفت خاطرتك');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final journal = ref.watch(userAppStateProvider.select((s) => s.journal));
    final entries = [
      for (final e in journal.reversed)
        if (e is Map) e,
    ];
    return PremiumScaffold(
      style: PremiumScaffoldStyle.photo,
      backgroundImage: AppAssets.pageQuran,
      appBar: AppBar(
        foregroundColor: Colors.white,
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('دفتري'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ResponsiveContent(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _Card(
                title: 'نيّتي اليوم',
                subtitle: 'اكتبي نيّتك قبل القراءة',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _intention,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText:
                            'مثال: أقرأ اليوم ابتغاء البركة وطمأنينة القلب…',
                      ),
                    ),
                    PremiumButton(
                      label: 'حفظ النيّة',
                      onPressed: _saveIntention,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Card(
                title: 'دفتر المشاعر',
                subtitle: 'دوّني شعورك بعد القراءة',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _entry,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'كيف كان لقاؤك بالقرآن اليوم؟',
                      ),
                    ),
                    PremiumButton(label: 'إضافة', onPressed: _addEntry),
                    const SizedBox(height: 14),
                    if (entries.isEmpty)
                      const EmptyNote(
                        message: 'لا توجد كتابات بعد — ابدئي بأوّل خاطرة.',
                      )
                    else
                      for (final e in entries)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e['date'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${e['text'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.7,
                                  color: colors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ReemKufi',
              fontSize: 18,
              color: colors.ink,
            ),
          ),
          Text(subtitle, style: TextStyle(fontSize: 12.5, color: colors.muted)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
