import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barakah40_flutter/features/prayer/data/location/prayer_location_service.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/daily_prayer_schedule.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_sync_state.dart';
import 'package:barakah40_flutter/features/prayer/domain/repositories/prayer_times_repository.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/prayer_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/sync_status.dart';
import 'package:barakah40_flutter/features/user_state/presentation/controllers/user_state_controller.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';

/// Read-model for the prayer times screen: current [PrayerSyncState] plus
/// whatever schedule/error context goes with it.
class PrayerScheduleState {
  const PrayerScheduleState({
    required this.status,
    this.schedule,
    this.errorMessage,
  });

  final PrayerSyncState status;

  /// Today's schedule, once fetched/cached — retained across a subsequent
  /// [PrayerSyncState.loading] (e.g. pull-to-refresh) so the UI doesn't
  /// flash empty.
  final DailyPrayerSchedule? schedule;

  final String? errorMessage;

  static const initial = PrayerScheduleState(status: PrayerSyncState.loading);

  factory PrayerScheduleState.loading({DailyPrayerSchedule? schedule}) =>
      PrayerScheduleState(status: PrayerSyncState.loading, schedule: schedule);

  factory PrayerScheduleState.ready(DailyPrayerSchedule schedule) =>
      PrayerScheduleState(status: PrayerSyncState.ready, schedule: schedule);

  factory PrayerScheduleState.needsCity() =>
      const PrayerScheduleState(status: PrayerSyncState.needsCity);

  factory PrayerScheduleState.permissionDenied() =>
      const PrayerScheduleState(status: PrayerSyncState.permissionDenied);

  factory PrayerScheduleState.offline(String message) => PrayerScheduleState(
    status: PrayerSyncState.offline,
    errorMessage: message,
  );

  factory PrayerScheduleState.error(String message) =>
      PrayerScheduleState(status: PrayerSyncState.error, errorMessage: message);
}

/// Drives the prayer schedule fetch pipeline described in
/// `docs/migration-analysis/FLUTTER_PRAYER_TIMES.md` §§ 2, 11:
/// same-day cache → manual city → one-shot silent GPS, with an explicit
/// [locate] entry point for the "استخدم موقعي" button and [saveCity] for
/// the city sheet's save action.
class PrayerScheduleController extends StateNotifier<PrayerScheduleState> {
  PrayerScheduleController(
    this._ref, {
    required PrayerTimesRepository repository,
    required PrayerLocationService locationService,
    // ignore: prefer_initializing_formals
  }) : _repository = repository,
       // ignore: prefer_initializing_formals
       _locationService = locationService,
       super(PrayerScheduleState.initial) {
    _init();
  }

  final Ref _ref;
  final PrayerTimesRepository _repository;
  final PrayerLocationService _locationService;

  UserStateController get _userStateController =>
      _ref.read(userStateControllerProvider.notifier);

  PrayerSettings get _prayerSettings => _ref.read(userAppStateProvider).prayer;

  Future<void> _init() async {
    await _waitForUserStateReady();
    if (!mounted) return;
    await refresh();
  }

  /// [UserStateController]'s local→remote reconciliation is asynchronous
  /// (`SharedPreferences.getInstance()`/Firestore reads). Reading
  /// [_prayerSettings] before the local snapshot has loaded would see
  /// defaults (empty city) and could wrongly fall through to a GPS attempt.
  /// Waits until local state is at least loaded (`loadingLocal` is the only
  /// phase where it isn't yet).
  Future<void> _waitForUserStateReady() async {
    bool isLoadingLocal(SyncStatus status) =>
        status == SyncStatus.initial || status == SyncStatus.loadingLocal;
    if (!isLoadingLocal(_userStateController.snapshot.syncStatus)) return;
    await _userStateController.stream.firstWhere(
      (snapshot) => !isLoadingLocal(snapshot.syncStatus),
    );
  }

  /// Re-derives from cache, or fetches: same-day skip mirrors legacy
  /// `fetchPrayerTimes`'s `timesDate===k&&times.fajr` short-circuit. Safe
  /// to call repeatedly (e.g. pull-to-refresh, or on screen re-entry).
  Future<void> refresh() async {
    final today = PrayerDayKey.dayKey();
    final settings = _prayerSettings;
    final cached = DailyPrayerSchedule.fromSettings(settings, today);
    if (cached.hasFajr) {
      state = PrayerScheduleState.ready(cached);
      return;
    }

    // Located by GPS before: fetch for the same coordinates. The city saved
    // then is only the time-zone name (e.g. "Cairo" for all of Egypt), so
    // fetching by that name would give another town's times. Choosing a
    // city by hand clears the coordinates (UserStateController.setPrayerCity).
    final lat = settings.extra['lat'];
    final lng = settings.extra['lng'];
    if (lat is num && lng is num) {
      state = PrayerScheduleState.loading(schedule: state.schedule);
      await _fetchByCoordinates(lat.toDouble(), lng.toDouble());
      return;
    }

    if (settings.city.trim().isNotEmpty) {
      await _fetchByCity(settings.city, settings.country, silent: true);
      return;
    }

    await _locate(silent: true);
  }

  /// Explicit "استخدم موقعي الحالي" action — always attempts GPS regardless
  /// of an existing city (legacy `locatePrayer(false)`).
  Future<void> locate() => _locate(silent: false);

  /// Saves [city]/[country] (legacy `openCity`'s save handler) and fetches
  /// its schedule.
  Future<void> saveCity(String city, String country) async {
    _userStateController.setPrayerCity(city: city, country: country);
    await _fetchByCity(city, country, silent: false);
  }

  Future<void> _locate({required bool silent}) async {
    state = PrayerScheduleState.loading(schedule: state.schedule);
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;

    switch (result.status) {
      case PrayerLocationStatus.success:
        await _fetchByCoordinates(result.latitude!, result.longitude!);
        break;
      case PrayerLocationStatus.permissionDenied:
      case PrayerLocationStatus.permissionDeniedForever:
        state = PrayerScheduleState.permissionDenied();
        break;
      case PrayerLocationStatus.serviceDisabled:
        state = silent
            ? PrayerScheduleState.needsCity()
            : PrayerScheduleState.error(
                PrayerLocationCopy.serviceDisabledExplanation,
              );
        break;
      case PrayerLocationStatus.error:
        state = silent
            ? PrayerScheduleState.needsCity()
            : PrayerScheduleState.error(
                result.message ?? PrayerLocationCopy.genericErrorExplanation,
              );
        break;
    }
  }

  Future<void> _fetchByCity(
    String city,
    String country, {
    required bool silent,
  }) async {
    state = PrayerScheduleState.loading(schedule: state.schedule);
    final today = PrayerDayKey.dayKey();
    try {
      final result = await _repository.fetchByCity(
        city: city,
        country: country,
        method: _prayerSettings.method,
      );
      if (!mounted) return;
      if (result.times.isEmpty) {
        state = PrayerScheduleState.error(
          'لم يتم العثور على أوقات صلاة لهذه المدينة — تحققي من الاسم.',
        );
        return;
      }
      _userStateController.applyPrayerSchedule(
        times: result.times,
        timesDate: today,
      );
      state = PrayerScheduleState.ready(
        DailyPrayerSchedule(
          dayKey: today,
          times: result.times,
          city: city,
          country: country,
          method: _prayerSettings.method,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      state = PrayerScheduleState.offline(
        'تعذّر جلب أوقات الصلاة — تحققي من اتصالكِ بالإنترنت.',
      );
    }
  }

  Future<void> _fetchByCoordinates(double latitude, double longitude) async {
    final today = PrayerDayKey.dayKey();
    try {
      final result = await _repository.fetchByCoordinates(
        latitude: latitude,
        longitude: longitude,
        method: _prayerSettings.method,
      );
      if (!mounted) return;
      if (result.times.isEmpty) {
        state = PrayerScheduleState.error(
          PrayerLocationCopy.genericErrorExplanation,
        );
        return;
      }
      final cityLabel = result.timezoneCityLabel;
      _userStateController.applyPrayerSchedule(
        times: result.times,
        timesDate: today,
        city: cityLabel,
        lat: latitude,
        lng: longitude,
        tz: result.timezone,
      );
      state = PrayerScheduleState.ready(
        DailyPrayerSchedule(
          dayKey: today,
          times: result.times,
          city: cityLabel ?? _prayerSettings.city,
          country: _prayerSettings.country,
          method: _prayerSettings.method,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      state = PrayerScheduleState.offline(
        'تعذّر جلب أوقات الصلاة — تحققي من اتصالكِ بالإنترنت.',
      );
    }
  }
}
