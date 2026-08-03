import 'package:barakah40_flutter/features/home/domain/entities/home_progress.dart';

/// Home progress contract — local-first; Firebase state sync arrives later.
abstract class HomeRepository {
  /// Current progress snapshot (never invents fake stats).
  HomeProgress getProgress();

  /// Stream of progress updates when local store changes.
  Stream<HomeProgress> watchProgress();
}
