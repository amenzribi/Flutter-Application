import 'adhan_notifier.dart';

/// Phones and desktop: no alert yet (needs scheduled local notifications).
AdhanNotifier createAdhanNotifier() => _UnsupportedAdhanNotifier();

class _UnsupportedAdhanNotifier implements AdhanNotifier {
  @override
  bool get supported => false;

  @override
  bool get granted => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  void show({required String title, required String body}) {}
}
