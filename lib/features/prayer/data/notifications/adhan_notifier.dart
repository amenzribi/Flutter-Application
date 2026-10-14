import 'adhan_notifier_stub.dart'
    if (dart.library.js_interop) 'adhan_notifier_web.dart';

/// Shows the "time for prayer" alert. On the web this is a browser
/// notification, shown while the app is open (also in a background tab).
abstract class AdhanNotifier {
  factory AdhanNotifier() => createAdhanNotifier();

  /// Whether this platform can show the alert at all.
  bool get supported;

  /// Whether the user already allowed alerts.
  bool get granted;

  /// Asks the user for permission; returns whether alerts are allowed.
  Future<bool> requestPermission();

  void show({required String title, required String body});
}
