import 'package:flutter_compass/flutter_compass.dart';

import 'package:barakah40_flutter/features/qibla/domain/qibla_math.dart';

/// Device heading on Android and iOS. `null` when the device has no compass.
Stream<CompassReading>? compassReadings() {
  final events = FlutterCompass.events;
  if (events == null) return null;
  return events
      .where((e) => e.heading != null)
      .map((e) => CompassReading(heading: e.heading!, accuracy: e.accuracy));
}

/// Native platforms ask for sensors without an extra prompt.
Future<bool> requestCompassPermission() async => true;
