import 'package:barakah40_flutter/features/home/domain/entities/home_progress.dart';
import 'package:barakah40_flutter/features/home/domain/repositories/home_repository.dart';
import 'package:barakah40_flutter/features/home/domain/services/home_progress_mapper.dart';
import 'package:barakah40_flutter/features/user_state/presentation/controllers/user_state_controller.dart';

/// Derives [HomeProgress] from [UserAppState] — the single source of truth
/// owned by [UserStateController] — via [HomeProgressMapper].
class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._controller);

  final UserStateController _controller;

  @override
  HomeProgress getProgress() =>
      HomeProgressMapper.map(_controller.snapshot.appState);

  @override
  Stream<HomeProgress> watchProgress() async* {
    yield HomeProgressMapper.map(_controller.snapshot.appState);
    yield* _controller.stream.map(
      (snapshot) => HomeProgressMapper.map(snapshot.appState),
    );
  }
}
