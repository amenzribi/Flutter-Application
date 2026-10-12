import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/core/constants/app_assets.dart';
import 'package:barakah40_flutter/features/home/presentation/providers/home_providers.dart';
import 'package:barakah40_flutter/features/tree/presentation/providers/tree_providers.dart';
import 'package:barakah40_flutter/features/tree/presentation/widgets/tree_card.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Legacy "الإنجازات" view: the full tree card, stats and stage legend.
class TreeScreen extends ConsumerWidget {
  const TreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(treeDisplayProvider);
    return PremiumScaffold(
      style: PremiumScaffoldStyle.photo,
      backgroundImage: ref.watch(dayPeriodProvider).backgroundAsset,
      appBar: AppBar(
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('الإنجازات', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: ResponsiveContent(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const TreeCard(compact: false),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat(value: '${d.points}', label: 'نقاط الشجرة'),
                  const SizedBox(width: 10),
                  _Stat(
                    value: '${(d.vitality * 100).round()}%',
                    label: 'الحيوية',
                  ),
                  const SizedBox(width: 10),
                  _Stat(value: '${d.stage + 1}', label: 'المرحلة'),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'حالات الشجرة',
                style: TextStyle(
                  fontFamily: 'ReemKufi',
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Legend(asset: AppAssets.treeGrow(19), label: 'مباركة'),
                  _Legend(asset: AppAssets.treeGrow(10), label: 'نامية'),
                  _Legend(asset: AppAssets.treeGrow(3), label: 'صغيرة'),
                  _Legend(asset: AppAssets.treeWilt(2), label: 'ذابلة'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xB312160F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x2ED8B878)),
                ),
                child: const Text(
                  'تنمو بنشاطكِ (صلاة، قراءة، أذكار، سبحة) بحدّ مرحلة واحدة يومياً '
                  '(ومرحلتين في يوم حافل)، وتذبل عند فوات صلاة، وتعود بذرة إذا مرّ '
                  'يوم كامل دون نشاط. تُحفظ حالتكِ في حسابكِ.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: Color(0xD9F1ECE0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F4ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9E3D6)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'ReemKufi',
                fontSize: 20,
                color: Color(0xFF2F2C27),
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A9384)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: Image.asset(asset, fit: BoxFit.cover, cacheWidth: 300),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
