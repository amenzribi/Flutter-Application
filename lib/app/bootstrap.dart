import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:barakah40_flutter/app/app.dart';
import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/firebase_options.dart';

/// Boots Flutter bindings, Firebase, then the root app.
///
/// On Firebase init failure, shows a friendly Arabic error screen instead of
/// crashing with a raw exception.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Firebase initialized');
    runApp(const ProviderScope(child: BarakahApp()));
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
