import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/quran/domain/entities/audio_playback_state.dart';
import 'package:barakah40_flutter/features/quran/presentation/controllers/quran_audio_controller.dart';

import 'fakes/fake_quran_audio_player.dart';

/// Flushes pending microtasks from the fake player's async setUrl/play.
Future<void> settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeQuranAudioPlayer player;
  late List<int?> audioPosUpdates;
  late String reciterId;

  QuranAudioController buildController() {
    return QuranAudioController(
      player: player,
      reciterId: () => reciterId,
      onAudioPosChanged: audioPosUpdates.add,
    );
  }

  setUp(() {
    player = FakeQuranAudioPlayer();
    audioPosUpdates = [];
    reciterId = 'Alafasy_128kbps';
  });

  test('playFrom loads the url and transitions to playing', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.playFrom(1);
    await settle();

    expect(controller.state.status, AudioPlaybackStatus.playing);
    expect(controller.state.currentAyah, 1);
    expect(player.setUrlCalls, [
      'https://everyayah.com/data/Alafasy_128kbps/002001.mp3',
    ]);
    expect(player.playCalls, hasLength(1));
    expect(audioPosUpdates, [1]);
  });

  test('playFrom ignores out-of-range ayahs', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.playFrom(0);
    await controller.playFrom(287);
    await settle();

    expect(controller.state.status, AudioPlaybackStatus.idle);
    expect(player.setUrlCalls, isEmpty);
  });

  test('pause stops playback and sets paused status', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.playFrom(5);
    await settle();
    await controller.pause();

    expect(controller.state.status, AudioPlaybackStatus.paused);
    expect(player.pauseCalls, hasLength(1));
  });

  test('resume from paused replays without reloading the url', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.playFrom(5);
    await settle();
    await controller.pause();
    player.setUrlCalls.clear();

    await controller.resume();

    expect(controller.state.status, AudioPlaybackStatus.playing);
    expect(player.setUrlCalls, isEmpty); // resumed, not reloaded
    expect(player.playCalls, hasLength(2));
  });

  test(
    'stop resets state to idle and clears the persisted audio position',
    () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      await controller.playFrom(5);
      await settle();
      audioPosUpdates.clear();

      await controller.stop();

      expect(controller.state, AudioPlaybackState.idleState);
      expect(player.stopCalls, hasLength(1));
      expect(audioPosUpdates, [null]);
    },
  );

  test('auto-advances to the next ayah on completion', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.playFrom(5);
    await settle();

    player.completeCurrent();
    await settle();

    expect(controller.state.currentAyah, 6);
    expect(controller.state.status, AudioPlaybackStatus.playing);
    expect(player.setUrlCalls, [
      'https://everyayah.com/data/Alafasy_128kbps/002005.mp3',
      'https://everyayah.com/data/Alafasy_128kbps/002006.mp3',
    ]);
  });

  test('stops (does not wrap) after completing the last ayah (286)', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.playFrom(286);
    await settle();

    player.completeCurrent();
    await settle();

    expect(controller.state, AudioPlaybackState.idleState);
    expect(player.stopCalls, hasLength(1));
  });

  test('position and duration streams update state', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.playFrom(1);
    await settle();

    player.emitDuration(const Duration(seconds: 30));
    player.emitPosition(const Duration(seconds: 5));
    await settle();

    expect(controller.state.duration, const Duration(seconds: 30));
    expect(controller.state.position, const Duration(seconds: 5));
  });

  test(
    'falls over to the next EveryAyah folder mirror when the primary 404s',
    () async {
      reciterId = 'Maher_AlMuaiqly_64kbps';
      player.failingUrls.add(
        'https://everyayah.com/data/Maher_AlMuaiqly_64kbps/002001.mp3',
      );
      final controller = buildController();
      addTearDown(controller.dispose);

      await controller.playFrom(1);
      await settle();

      expect(controller.state.status, AudioPlaybackStatus.playing);
      expect(player.setUrlCalls, [
        'https://everyayah.com/data/Maher_AlMuaiqly_64kbps/002001.mp3',
        'https://everyayah.com/data/MaherAlMuaiqly128kbps/002001.mp3',
      ]);
    },
  );

  test('reports an Arabic error once every folder mirror has failed', () async {
    reciterId = 'Alafasy_128kbps';
    player.failingUrls.add(
      'https://everyayah.com/data/Alafasy_128kbps/002001.mp3',
    );
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.playFrom(1);
    await settle();

    expect(controller.state.status, AudioPlaybackStatus.error);
    expect(controller.state.errorMessage, 'تعذّر تشغيل الصوت');
    expect(player.playCalls, isEmpty);
  });

  test('dispose releases the underlying player', () async {
    final controller = buildController();
    controller.dispose();
    await settle();
    expect(player.disposed, isTrue);
  });
}
