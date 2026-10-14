import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barakah40_flutter/app/app.dart';
import 'package:barakah40_flutter/app/emulator_session_guard.dart';
import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/firebase_options.dart';

/// Local testing only: `--dart-define=USE_FIREBASE_EMULATORS=true` points
/// Auth and Firestore at the emulators started by `firebase emulators:start`
/// (see firebase/README.md). Ignored in release builds.
const _useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

/// Boots Flutter bindings, SharedPreferences, Firebase, then the root app.
///
/// On Firebase init failure, shows a friendly Arabic error screen instead of
/// crashing with a raw exception.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  final prefs = await SharedPreferences.getInstance();

  try {
    if (_useEmulators && !kReleaseMode && kIsWeb) {
      await clearStoredFirebaseSession();
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (_useEmulators && !kReleaseMode) {
      // The Android emulator reaches the computer running the Firebase
      // emulators at 10.0.2.2; everything else uses the local loopback.
      final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : '127.0.0.1';
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
      AppLogger.warning('Using local Firebase emulators');
    }
    AppLogger.info('Firebase initialized');
    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const BarakahApp(),
      ),
    );
  } catch (error, stackTrace) {
    AppLogger.error('Firebase initialization failed', error, stackTrace);
    runApp(const _BootstrapFailureApp());
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'تعذّر تهيئة التطبيق',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'فشل الاتصال بإعدادات الخدمة. تحقّقي من الاتصال بالشبكة ثم أغلقي التطبيق وأعيدي فتحه.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
