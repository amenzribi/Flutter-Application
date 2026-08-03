import 'dart:async';

import 'package:barakah40_flutter/features/home/domain/entities/home_progress.dart';
import 'package:barakah40_flutter/features/home/domain/repositories/home_repository.dart';

/// In-memory local store. Starts empty until feature modules write real data.
class HomeLocalStore {
  HomeProgress _progress = HomeProgress.empty;
  final _controller = StreamController<HomeProgress>.broadcast();

  HomeProgress get progress => _progress;

  Stream<HomeProgress> get stream async* {
    yield _progress;
    yield* _controller.stream;
  }

  void replace(HomeProgress progress) {
    _progress = progress;
    _controller.add(progress);
  }

  void dispose() {
    _controller.close();
  }
}

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl({HomeLocalStore? store})
    : _store = store ?? HomeLocalStore();

  final HomeLocalStore _store;

  @override
  HomeProgress getProgress() => _store.progress;

  @override
  Stream<HomeProgress> watchProgress() => _store.stream;
}
