import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Emulator mode on web only: forgets the browser-stored Firebase session
/// before Firebase starts.
///
/// On start-up the Firebase JS SDK restores a stored user and refreshes it
/// against the real Auth endpoint before the app can switch Auth to the
/// emulator. With an emulator-issued token that call fails, the user is
/// signed out, and the emulator connection is silently not applied, so later
/// sign-ins would go to the real project. Starting without a stored session
/// avoids all of that; the cost is signing in again after a page reload while
/// testing against the emulators.
Future<void> clearStoredFirebaseSession() async {
  final indexedDb = globalContext['indexedDB'];
  if (indexedDb == null) return;
  final request = (indexedDb as JSObject).callMethod<JSObject>(
    'deleteDatabase'.toJS,
    'firebaseLocalStorageDb'.toJS,
  );
  final done = Completer<void>();
  void finish(JSAny? _) {
    if (!done.isCompleted) done.complete();
  }

  request['onsuccess'] = finish.toJS;
  request['onerror'] = finish.toJS;
  request['onblocked'] = finish.toJS;
  await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
}
