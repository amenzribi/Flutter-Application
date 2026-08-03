import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/quran/data/catalogs/reciters_catalog.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/reciter.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Searchable list of the 11 legacy EveryAyah reciters. Selecting one calls
/// [UserStateController.setReciter] and returns to the reader.
class ReciterSelectionScreen extends ConsumerStatefulWidget {
  const ReciterSelectionScreen({super.key});

  @override
  ConsumerState<ReciterSelectionScreen> createState() =>
      _ReciterSelectionScreenState();
}

class _ReciterSelectionScreenState
    extends ConsumerState<ReciterSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentReciterId = ref.watch(userAppStateProvider).reciter;
    final query = _query.trim();
    final filtered = query.isEmpty
        ? RecitersCatalog.all
        : RecitersCatalog.all
              .where((r) => r.arabicName.contains(query))
              .toList(growable: false);

    return PremiumScaffold(
      appBar: AppBar(
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          onPressed: _goBack,
        ),
        title: const Text('اختيار القارئ'),
      ),
      body: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'ابحثي عن قارئ',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد قارئ مطابق',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final reciter = filtered[index];
                        return _ReciterTile(
                          reciter: reciter,
                          selected: reciter.id == currentReciterId,
                          onTap: () {
                            ref
                                .read(userStateControllerProvider.notifier)
                                .setReciter(reciter.id);
                            _goBack();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReciterTile extends StatelessWidget {
  const _ReciterTile({
    required this.reciter,
    required this.selected,
    required this.onTap,
  });

  final Reciter reciter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              reciter.arabicName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: colors.olive)
          else
            Icon(Icons.chevron_left_rounded, color: colors.muted),
        ],
      ),
    );
  }
}
