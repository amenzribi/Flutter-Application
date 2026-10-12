import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/constants/app_assets.dart';
import 'package:barakah40_flutter/features/adhkar/presentation/adhkar_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Legacy "الأدعية" view: duas from the Quran and Sunnah with sources.
/// Opening it counts a visit in `S.stats.duasOpened`, as in the legacy app.
class DuasScreen extends ConsumerStatefulWidget {
  const DuasScreen({super.key});

  @override
  ConsumerState<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends ConsumerState<DuasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stats = Map<String, dynamic>.from(
        (ref.read(userAppStateProvider).extra['stats'] as Map?) ?? const {},
      );
      final opened = stats['duasOpened'];
      stats['duasOpened'] = (opened is num ? opened.toInt() : 0) + 1;
      ref
          .read(userStateControllerProvider.notifier)
          .updateExtra('stats', stats);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final duas = ref.watch(duasProvider);
    return PremiumScaffold(
      style: PremiumScaffoldStyle.photo,
      backgroundImage: AppAssets.pageDuas,
      appBar: AppBar(
        foregroundColor: Colors.white,
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('الأدعية'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: ResponsiveContent(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xB312160F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'أدعية صحيحة من القرآن والسنّة مع مصادرها. للحفظ والتثبّت يُنصح بمراجعة «حصن المسلم».',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              duas.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => RetryNote(
                  message: 'تعذّر تحميل الأدعية.',
                  onRetry: () => ref.invalidate(duasProvider),
                ),
                data: (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in list)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.category,
                              style: TextStyle(
                                fontFamily: 'ReemKufi',
                                fontSize: 14,
                                color: colors.oliveDeep,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              d.text,
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 18,
                                height: 1.8,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d.source,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.muted,
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
