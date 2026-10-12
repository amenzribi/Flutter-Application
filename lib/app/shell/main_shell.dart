import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/shell/legacy_bottom_nav.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';

/// Signed-in shell: the page above the legacy bottom navigation. Also keeps
/// the social profile / challenge-progress sync alive while signed in.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(socialSyncProvider);
    return Scaffold(
      body: child,
      bottomNavigationBar: LegacyBottomNav(
        location: GoRouterState.of(context).uri.path,
      ),
    );
  }
}
