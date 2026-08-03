import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/features/user_state/presentation/widgets/sync_status_label.dart';

/// Debug-only affordance that opens [UserStateDiagnosticsPanel].
///
/// Callers must gate this behind `kDebugMode` — it is never hidden by this
/// widget itself so it stays trivially tree-shakeable to check at the call
/// site, matching how the rest of the app avoids fake/hidden UI.
class UserStateDiagnosticsFab extends StatelessWidget {
  const UserStateDiagnosticsFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'user-state-diagnostics-fab',
      tooltip: 'تشخيص حالة المستخدم (تصحيح فقط)',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const UserStateDiagnosticsPanel(),
      ),
      child: const Icon(Icons.bug_report_outlined),
    );
  }
}

/// Read-only sync/state inspector, plus a safe lang-toggle test action.
/// Debug builds only — see [UserStateDiagnosticsFab].
class UserStateDiagnosticsPanel extends ConsumerWidget {
  const UserStateDiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(userStateControllerProvider);
    final completedCount = snapshot.appState.completed
        .where((day) => day)
        .length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تشخيص حالة المستخدم',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DiagnosticsRow('uid', snapshot.uid ?? '—'),
            _DiagnosticsRow(
              'syncStatus',
              '${snapshot.syncStatus.name} (${snapshot.syncStatus.labelAr})',
            ),
            _DiagnosticsRow(
              'lastSyncedAt',
              snapshot.lastSyncedAt?.toIso8601String() ?? '—',
            ),
            _DiagnosticsRow('lang', snapshot.appState.lang),
            _DiagnosticsRow(
              'completed',
              '$completedCount / ${snapshot.appState.completed.length}',
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: () => ref
                  .read(userStateControllerProvider.notifier)
                  .toggleLangDebugProbe(),
              child: Text(
                'تبديل اللغة (اختبار آمن) — الحالية: ${snapshot.appState.lang}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.inkSoft),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
