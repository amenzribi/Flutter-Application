import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/features/home/presentation/providers/home_providers.dart';
import 'package:barakah40_flutter/features/tree/domain/tree_growth_service.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/sync_status.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

/// Tree state re-evaluated whenever user state changes and every 30s (the
/// home clock), like legacy's 60s `refreshTree` interval.
final treeResolutionProvider = Provider<TreeResolution>((ref) {
  final state = ref.watch(userAppStateProvider);
  final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
  return TreeGrowthService.resolve(state, now);
});

final treeDisplayProvider = Provider<TreeDisplay>(
  (ref) => ref.watch(treeResolutionProvider).display,
);

/// Persists `S.tree` when resolution moved the stage (legacy `cappedStage`
/// calls `save()`), outside of build. Kept alive by the tree card.
///
/// Never writes while the account's state is still loading: a patch applied
/// to the placeholder defaults would be pushed over the real remote state.
final treePersistProvider = Provider<void>((ref) {
  const loading = {
    SyncStatus.initial,
    SyncStatus.loadingLocal,
    SyncStatus.loadingRemote,
  };
  void persist(TreeResolution r) {
    final updated = r.updatedTree;
    if (updated == null) return;
    if (loading.contains(ref.read(userSyncStatusProvider))) return;
    Future.microtask(
      () => ref
          .read(userStateControllerProvider.notifier)
          .updateExtra('tree', updated),
    );
  }

  ref.listen(treeResolutionProvider, (_, next) => persist(next));
  ref.listen(
    userSyncStatusProvider,
    (_, _) => persist(ref.read(treeResolutionProvider)),
  );
  persist(ref.read(treeResolutionProvider));
});
