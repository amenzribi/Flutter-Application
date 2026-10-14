import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'adhan_notifier.dart';

AdhanNotifier createAdhanNotifier() => _WebAdhanNotifier();

class _WebAdhanNotifier implements AdhanNotifier {
  @override
  bool get supported => globalContext.has('Notification');

  @override
  bool get granted => supported && web.Notification.permission == 'granted';

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    if (granted) return true;
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  }

  @override
  void show({required String title, required String body}) {
    if (!granted) return;
    web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        dir: 'rtl',
        lang: 'ar',
        icon: 'icons/Icon-192.png',
        tag: 'adhan',
        requireInteraction: true,
      ),
    );
  }
}
