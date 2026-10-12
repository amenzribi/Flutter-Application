import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';

/// Legacy fixed bottom `.nav`: frosted surface, icon over a 9.5px bold label,
/// olive for the active tab. Only destinations that exist in this app are
/// shown (legacy also had Adhkar, Qibla and Duas, not migrated yet).
class LegacyBottomNav extends ConsumerWidget {
  const LegacyBottomNav({super.key, required this.location});

  final String location;

  static const _items = [
    (AppRoutes.home, 'الرئيسية', Icons.home_outlined, Icons.home_rounded),
    (AppRoutes.challenge, 'التحدّي', Icons.check_box_outlined, Icons.check_box),
    (AppRoutes.quran, 'القراءة', Icons.menu_book_outlined, Icons.menu_book),
    (AppRoutes.prayer, 'الصلاة', Icons.mosque_outlined, Icons.mosque),
    (
      AppRoutes.community,
      'المجتمع',
      Icons.people_alt_outlined,
      Icons.people_alt,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.barakahColors;
    final badge = ref.watch(communityBadgeProvider);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: colors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  for (final item in _items)
                    Expanded(
                      child: _NavButton(
                        label: item.$2,
                        icon: item.$3,
                        activeIcon: item.$4,
                        active: _isActive(item.$1),
                        badge: item.$1 == AppRoutes.community ? badge : 0,
                        onTap: () => context.go(item.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isActive(String route) {
    if (route == AppRoutes.home) {
      return location == AppRoutes.home || location == AppRoutes.tree;
    }
    return location == route || location.startsWith('$route/');
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final color = active ? colors.olive : colors.muted;
    return Semantics(
      selected: active,
      button: true,
      label: badge > 0 ? '$label، $badge جديد' : label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(active ? activeIcon : icon, size: 22, color: color),
                    if (badge > 0)
                      PositionedDirectional(
                        top: -6,
                        end: -12,
                        child: CountBadge(count: badge),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
