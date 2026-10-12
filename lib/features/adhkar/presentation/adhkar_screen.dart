import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/constants/app_assets.dart';
import 'package:barakah40_flutter/core/utils/arabic_numbers.dart';
import 'package:barakah40_flutter/features/adhkar/domain/adhkar_models.dart';
import 'package:barakah40_flutter/features/adhkar/presentation/adhkar_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Legacy "الأذكار" view: morning and evening adhkar from «حصن المسلم», a
/// counter per dhikr (`S.adhkarCount`), each tap recorded as adhkar activity
/// for the tree. Counters are capped at the dhikr's count and, as in the
/// legacy app, are not reset automatically.
class AdhkarScreen extends ConsumerStatefulWidget {
  const AdhkarScreen({super.key, this.initial});

  final AdhkarSession? initial;

  @override
  ConsumerState<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends ConsumerState<AdhkarScreen> {
  // Legacy `adhMode='morning'`.
  late AdhkarSession _session = widget.initial ?? AdhkarSession.morning;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(adhkarCatalogProvider);
    return PremiumScaffold(
      style: PremiumScaffoldStyle.photo,
      backgroundImage: AppAssets.pageAdhkar,
      appBar: AppBar(
        foregroundColor: Colors.white,
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('الأذكار'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: ResponsiveContent(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              LegacySegmentedTabs(
                labels: [for (final s in AdhkarSession.values) s.label],
                icons: const [
                  Icons.wb_sunny_outlined,
                  Icons.nights_stay_outlined,
                ],
                selected: _session.index,
                onSelected: (i) =>
                    setState(() => _session = AdhkarSession.values[i]),
              ),
              const SizedBox(height: 12),
              const _Note(
                'أذكار «حصن المسلم» كاملة، روجِعت بعناية. والآيات الواردة فيها تُجلب من مصدر قرآني موثوق. اضغطي العدّاد عند كل تكرار.',
              ),
              const SizedBox(height: 12),
              catalog.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => RetryNote(
                  message: 'تعذّر تحميل الأذكار.',
                  onRetry: () => ref.invalidate(adhkarCatalogProvider),
                ),
                data: (c) =>
                    _AdhkarList(session: _session, items: c.of(_session)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdhkarList extends ConsumerWidget {
  const _AdhkarList({required this.session, required this.items});

  final AdhkarSession session;
  final List<Dhikr> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(userAppStateProvider.select((s) => s.adhkarCount));
    final done = [
      for (var i = 0; i < items.length; i++)
        dhikrCountOf(counts, AdhkarCatalog.key(session, i)) >= items[i].count,
    ].where((d) => d).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'أتممتِ ${arabicDigits(done)} من ${arabicDigits(items.length)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < items.length; i++)
          _DhikrCard(
            dhikr: items[i],
            dhikrKey: AdhkarCatalog.key(session, i),
            count: dhikrCountOf(counts, AdhkarCatalog.key(session, i)),
          ),
      ],
    );
  }
}

class _DhikrCard extends ConsumerWidget {
  const _DhikrCard({
    required this.dhikr,
    required this.dhikrKey,
    required this.count,
  });

  final Dhikr dhikr;
  final String dhikrKey;
  final int count;

  void _inc(BuildContext context, WidgetRef ref) {
    final next = (count + 1).clamp(0, dhikr.count);
    ref
        .read(userStateControllerProvider.notifier)
        .incrementAdhkar(dhikrKey, max: dhikr.count);
    if (next == dhikr.count && count < dhikr.count) {
      showSocialSnack(context, '🌿 تقبّل الله منكِ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.barakahColors;
    final complete = count >= dhikr.count;
    final quran = dhikr.isQuran ? ref.watch(adhkarQuranTextsProvider) : null;
    final Widget text;
    if (quran == null) {
      text = _text(dhikr.text, quran: false, colors: colors);
    } else {
      text = quran.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => RetryNote(
          message: 'تعذّر تحميل نص الآيات. تحقّقي من الاتصال.',
          onRetry: () => ref.invalidate(adhkarQuranTextsProvider),
        ),
        data: (m) =>
            _text(m[dhikr.quranRef] ?? '', quran: true, colors: colors),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: complete ? colors.oliveSoft : colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: complete ? colors.olive.withValues(alpha: 0.5) : colors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          text,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  dhikr.source,
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ),
              if (complete)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 16, color: colors.olive),
                      Text(
                        'تمّ',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.oliveDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              _CounterButton(
                icon: Icons.remove_rounded,
                tooltip: 'إنقاص',
                onPressed: count > 0
                    ? () => ref
                          .read(userStateControllerProvider.notifier)
                          .decrementAdhkar(dhikrKey)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Semantics(
                  label:
                      '${arabicDigits(count)} من ${arabicDigits(dhikr.count)}',
                  excludeSemantics: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: arabicDigits(count),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colors.oliveDeep,
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${arabicDigits(dhikr.count)}',
                          style: TextStyle(color: colors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _CounterButton(
                icon: Icons.add_rounded,
                tooltip: 'تكرار',
                filled: true,
                onPressed: complete ? null : () => _inc(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _text(
    String value, {
    required bool quran,
    required BarakahColors colors,
  }) {
    return Text(
      value,
      textAlign: TextAlign.justify,
      style: TextStyle(
        fontFamily: quran ? 'AmiriQuran' : 'Amiri',
        fontSize: quran ? 20 : 18,
        height: quran ? 2.0 : 1.8,
        color: colors.ink,
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: filled ? colors.olive : colors.surfaceMuted,
          foregroundColor: filled ? Colors.white : colors.oliveDeep,
          disabledBackgroundColor: colors.surfaceMuted,
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xB312160F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2ED8B878)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          height: 1.6,
        ),
      ),
    );
  }
}
