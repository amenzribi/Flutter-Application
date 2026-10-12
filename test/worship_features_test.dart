import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/core/utils/arabic_numbers.dart';
import 'package:barakah40_flutter/features/adhkar/domain/adhkar_models.dart';
import 'package:barakah40_flutter/features/auth/domain/entities/app_user.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/qibla/data/qibla_geocoder.dart';
import 'package:barakah40_flutter/features/qibla/domain/qibla_math.dart';
import 'package:barakah40_flutter/features/qibla/presentation/qibla_screen.dart';
import 'package:barakah40_flutter/features/tree/domain/tree_growth_service.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';
import 'package:barakah40_flutter/features/user_state/presentation/controllers/user_state_controller.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_user_state_repositories.dart';

Future<void> settle([int ticks = 8]) async {
  for (var i = 0; i < ticks; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('content copied from the legacy app', () {
    final adhkar = AdhkarCatalog.fromJson(
      jsonDecode(File('assets/data/adhkar.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final duas = [
      for (final e
          in jsonDecode(File('assets/data/duas.json').readAsStringSync())
              as List)
        Dua.fromJson(Map<String, dynamic>.from(e as Map)),
    ];

    test('morning and evening adhkar are complete and well formed', () {
      expect(adhkar.morning, hasLength(21));
      expect(adhkar.evening, hasLength(20));
      for (final d in [...adhkar.morning, ...adhkar.evening]) {
        expect(d.count, greaterThan(0));
        expect(d.source, isNotEmpty);
        expect(d.isQuran || d.text.isNotEmpty, isTrue);
      }
      expect(adhkar.morning.where((d) => d.isQuran).map((d) => d.quranRef), [
        'kursi',
        'muawidhat',
      ]);
    });

    test('duas carry category, text and source', () {
      expect(duas, hasLength(9));
      for (final d in duas) {
        expect(d.category, isNotEmpty);
        expect(d.text, isNotEmpty);
        expect(d.source, isNotEmpty);
      }
    });

    test('counter keys match the legacy adhKey', () {
      expect(AdhkarCatalog.key(AdhkarSession.morning, 3), 'morning_3');
      expect(AdhkarCatalog.key(AdhkarSession.evening, 0), 'evening_0');
    });
  });

  group('qibla maths (legacy bearingTo / distanceTo)', () {
    test('from Tripoli, Libya', () {
      final b = QiblaMath.qiblaBearing(32.8872, 13.1913);
      expect(b, closeTo(109.2, 0.5));
      expect(QiblaMath.distanceToMakkah(32.8872, 13.1913), closeTo(2916, 5));
    });

    test('from London', () {
      expect(QiblaMath.qiblaBearing(51.5074, -0.1278), closeTo(119.0, 0.5));
    });

    test('city lookup picks the country the user typed', () {
      final results = [
        {
          'country': 'Lebanon',
          'country_code': 'LB',
          'latitude': 34.43,
          'longitude': 35.84,
        },
        {
          'country': 'Libya',
          'country_code': 'LY',
          'latitude': 32.89,
          'longitude': 13.19,
        },
      ];
      expect(pickGeocodeResult(results, 'Libya')?.lat, 32.89);
      expect(pickGeocodeResult(results, 'ly')?.lat, 32.89);
      expect(pickGeocodeResult(results, '')?.lat, 34.43);
      expect(pickGeocodeResult(results, 'Egypt'), isNull);
      // Arabic country names cannot match: most relevant result.
      expect(pickGeocodeResult(results, 'ليبيا')?.lat, 34.43);
    });

    test('at the Kaaba the distance is zero', () {
      expect(QiblaMath.distanceToMakkah(21.4225, 39.8262), 0);
    });

    test('calibration hint follows legacy thresholds', () {
      expect(
        const CompassReading(heading: 0, accuracy: -1).needsCalibration,
        isTrue,
      );
      expect(
        const CompassReading(heading: 0, accuracy: 25).needsCalibration,
        isTrue,
      );
      expect(
        const CompassReading(heading: 0, accuracy: 10).needsCalibration,
        isFalse,
      );
      expect(const CompassReading(heading: 0).needsCalibration, isFalse);
    });
  });

  test('arabic digits', () {
    expect(arabicDigits(2026), '٢٠٢٦');
    expect(TasbeehCounter.subText(0, 0), 'تسبيح مفتوح');
    expect(TasbeehCounter.subText(70, 33), 'من ٣٣ • دورات: ٢');
  });

  group('controller actions', () {
    late FakeAuthRepository auth;
    late ProviderContainer container;
    late UserStateController controller;

    setUp(() async {
      auth = FakeAuthRepository();
      final remote = FakeUserStateRemoteRepository();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userStateLocalRepositoryProvider.overrideWithValue(
            FakeUserStateLocalRepository(),
          ),
          userStateRemoteRepositoryProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(() {
        auth.dispose();
        remote.dispose();
        container.dispose();
      });
      controller = container.read(userStateControllerProvider.notifier);
      auth.emit(const AppUser(uid: 'u1', email: 'a@b.co', emailVerified: true));
      await settle();
    });

    UserStateSnapshotView s() =>
        UserStateSnapshotView(container.read(userAppStateProvider));

    test(
      'adhkar counter is capped, goes down to zero, and counts as activity',
      () {
        controller.incrementAdhkar('morning_2', max: 3);
        controller.incrementAdhkar('morning_2', max: 3);
        controller.incrementAdhkar('morning_2', max: 3);
        controller.incrementAdhkar('morning_2', max: 3);
        expect(s().state.adhkarCount['morning_2'], 3);
        expect(TreeGrowthService.computePoints(s().state), greaterThan(0));
        for (var i = 0; i < 5; i++) {
          controller.decrementAdhkar('morning_2');
        }
        expect(s().state.adhkarCount['morning_2'], 0);
      },
    );

    test('tasbih taps, target and reset', () {
      controller.setTasbeehTarget(33);
      for (var i = 0; i < 34; i++) {
        controller.tapTasbeeh();
      }
      expect(s().state.tasbeeh.count, 34);
      expect(s().state.tasbeeh.target, 33);
      controller.resetTasbeeh();
      expect(s().state.tasbeeh.count, 0);
      expect(s().state.tasbeeh.target, 33);
    });

    test('intention for today and journal entries', () {
      controller.setIntentionToday('  ابتغاء البركة  ');
      final key = UserStateController.intentionKey(DateTime.now());
      expect(s().state.intention[key], 'ابتغاء البركة');
      controller.addJournalEntry('   ', '١/١/٢٠٢٦');
      controller.addJournalEntry('خاطرة', '١/١/٢٠٢٦');
      expect(s().state.journal, [
        {'date': '١/١/٢٠٢٦', 'text': 'خاطرة'},
      ]);
    });

    test('restart clears progress and keeps the settings', () {
      controller.completeChallengeDay(0);
      controller.incrementAdhkar('morning_0', max: 1);
      controller.tapTasbeeh();
      controller.setReciter('Husary_128kbps');
      controller.setPrayerCity(city: 'Tripoli', country: 'Libya');
      controller.addJournalEntry('خاطرة', 'd');

      controller.restartChallenge();
      final st = s().state;
      expect(st.completed.where((d) => d), isEmpty);
      expect(st.adhkarCount, isEmpty);
      expect(st.tasbeeh.count, 0);
      expect(st.journal, isEmpty);
      expect(st.extra.containsKey('activity'), isFalse);
      expect((st.extra['tree'] as Map)['shownStage'], 0);
      expect(st.reciter, 'Husary_128kbps');
      expect(st.prayer.city, 'Tripoli');
      expect(st.prayer.log, isEmpty);
      expect(st.started, isNotNull);
    });
  });
}

/// Tiny wrapper so the tests read `s().state.x`.
class UserStateSnapshotView {
  UserStateSnapshotView(this.state);
  final UserAppState state;
}
