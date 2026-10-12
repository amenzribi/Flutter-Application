import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:barakah40_flutter/features/qibla/domain/qibla_math.dart';

/// Legacy `startCompass` on the web: `deviceorientationabsolute` and
/// `deviceorientation` events; Safari's `webkitCompassHeading` when present,
/// otherwise `360 - alpha` (accuracy unknown when not absolute).
Stream<CompassReading>? compassReadings() {
  final window = globalContext;
  late final StreamController<CompassReading> controller;
  JSFunction? listener;

  void onEvent(JSObject e) {
    double? heading;
    double? accuracy;
    final webkit = e['webkitCompassHeading'];
    if (webkit != null && webkit.isA<JSNumber>()) {
      heading = (webkit as JSNumber).toDartDouble;
      final acc = e['webkitCompassAccuracy'];
      if (acc != null && acc.isA<JSNumber>()) {
        accuracy = (acc as JSNumber).toDartDouble;
      }
    } else {
      final alpha = e['alpha'];
      if (alpha != null && alpha.isA<JSNumber>()) {
        heading = (360 - (alpha as JSNumber).toDartDouble) % 360;
        final absolute = e['absolute'];
        if (absolute != null &&
            absolute.isA<JSBoolean>() &&
            !(absolute as JSBoolean).toDart) {
          accuracy = -1;
        }
      }
    }
    if (heading != null && !controller.isClosed) {
      controller.add(CompassReading(heading: heading, accuracy: accuracy));
    }
  }

  controller = StreamController<CompassReading>(
    onListen: () {
      listener = onEvent.toJS;
      for (final type in ['deviceorientationabsolute', 'deviceorientation']) {
        window.callMethod<JSAny?>(
          'addEventListener'.toJS,
          type.toJS,
          listener,
          true.toJS,
        );
      }
    },
    onCancel: () {
      for (final type in ['deviceorientationabsolute', 'deviceorientation']) {
        window.callMethod<JSAny?>(
          'removeEventListener'.toJS,
          type.toJS,
          listener,
          true.toJS,
        );
      }
    },
  );
  return controller.stream;
}

/// iOS Safari needs `DeviceOrientationEvent.requestPermission()` from a tap.
Future<bool> requestCompassPermission() async {
  final doe = globalContext['DeviceOrientationEvent'];
  if (doe == null) return false;
  final request = (doe as JSObject)['requestPermission'];
  if (request == null || !request.isA<JSFunction>()) return true;
  try {
    final result = await (doe.callMethod<JSPromise<JSString>>(
      'requestPermission'.toJS,
    )).toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}
