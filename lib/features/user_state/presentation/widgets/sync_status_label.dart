import 'package:barakah40_flutter/features/user_state/domain/entities/sync_status.dart';

/// Short Arabic labels for [SyncStatus], for small unobtrusive UI chips.
extension SyncStatusLabelAr on SyncStatus {
  String get labelAr {
    switch (this) {
      case SyncStatus.initial:
      case SyncStatus.loadingLocal:
      case SyncStatus.loadingRemote:
        return 'جارٍ التحميل…';
      case SyncStatus.ready:
        return 'جاهز';
      case SyncStatus.syncing:
        return 'جارٍ الحفظ…';
      case SyncStatus.synced:
        return 'تمّت المزامنة';
      case SyncStatus.offline:
        return 'غير متصلة بالسحابة';
      case SyncStatus.error:
        return 'تعذّرت المزامنة';
    }
  }
}
