import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/constants/app_assets.dart';
import 'package:barakah40_flutter/core/utils/arabic_numbers.dart';
import 'package:barakah40_flutter/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:barakah40_flutter/features/qibla/data/compass_source.dart';
import 'package:barakah40_flutter/features/qibla/data/qibla_geocoder.dart';
import 'package:barakah40_flutter/features/qibla/domain/qibla_math.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

const _myLocation = 'موقعي الحالي';

/// Legacy "القبلة" view: compass to the Kaaba, then the tasbih counter and
/// the mosque duas, on one page as in the legacy app.
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  StreamSubscription<CompassReading>? _sub;
  CompassReading? _reading;
  bool _busy = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _snack(String message) => showSocialSnack(context, message);

  /// [quiet] when started automatically after choosing a location: a device
  /// without a compass (e.g. a computer) should not get an error for a
  /// button nobody pressed. The angle and distance still show.
  Future<void> _startCompass({bool quiet = false}) async {
    if (_sub != null) return;
    final allowed = await requestCompassPermission();
    if (!mounted) return;
    if (!allowed) {
      if (!quiet) _snack('اسمحي بالوصول لاتجاه الجهاز لتعمل البوصلة');
      return;
    }
    final stream = compassReadings();
    if (stream == null) {
      if (!quiet) _snack('البوصلة غير مدعومة على هذا الجهاز');
      return;
    }
    _sub = stream.listen((r) {
      if (mounted) setState(() => _reading = r);
    }, onError: (Object _) => _snack('تعذّر تفعيل البوصلة على هذا الجهاز'));
  }

  Future<void> _locate() async {
    setState(() => _busy = true);
    _snack('جارٍ تحديد موقعكِ…');
    final result = await ref
        .read(prayerLocationServiceProvider)
        .getCurrentLocation();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.isSuccess) {
      _snack('تعذّر الوصول للموقع — اختاري المدينة يدويًا');
      await _openCity();
      return;
    }
    ref
        .read(userStateControllerProvider.notifier)
        .updateQibla(
          (q) => q.copyWith(
            lat: result.latitude,
            lng: result.longitude,
            city: _myLocation,
          ),
        );
    _snack('تم تحديد موقعكِ');
    unawaited(_startCompass(quiet: true));
  }

  Future<void> _openCity() async {
    final state = ref.read(userAppStateProvider);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CitySheet(
        initialCity: state.qibla.city == _myLocation ? '' : state.qibla.city,
        initialCountry: state.prayer.country,
      ),
    );
    if (saved == true && mounted) unawaited(_startCompass(quiet: true));
  }

  @override
  Widget build(BuildContext context) {
    final qibla = ref.watch(userAppStateProvider.select((s) => s.qibla));
    final hasLocation = qibla.lat != null && qibla.lng != null;
    final bearing = hasLocation
        ? QiblaMath.qiblaBearing(qibla.lat!, qibla.lng!)
        : null;
    final distance = hasLocation
        ? QiblaMath.distanceToMakkah(qibla.lat!, qibla.lng!)
        : null;
    final heading = _reading?.heading ?? 0;

    return PremiumScaffold(
      style: PremiumScaffoldStyle.photo,
      backgroundImage: AppAssets.pageQibla,
      appBar: AppBar(
        foregroundColor: Colors.white,
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('القبلة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: ResponsiveContent(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              Text(
                qibla.city.isNotEmpty
                    ? qibla.city
                    : 'حدّدي موقعكِ لإظهار اتجاه القبلة',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: Icons.my_location_rounded,
                    label: 'تحديث الموقع',
                    onTap: _busy ? null : _locate,
                  ),
                  _Chip(
                    icon: Icons.location_city_rounded,
                    label: 'اختيار المدينة',
                    onTap: _openCity,
                  ),
                  _Chip(
                    icon: Icons.explore_outlined,
                    label: _sub == null ? 'تفعيل البوصلة' : 'البوصلة تعمل',
                    onTap: _sub == null ? () => _startCompass() : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Semantics(
                  label: bearing == null
                      ? 'لم يُحدَّد الموقع بعد'
                      : 'اتجاه القبلة ${arabicDigits(bearing.round())} درجة من الشمال',
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: _Compass(bearing: bearing, heading: heading),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Readout(
                    value: bearing == null
                        ? '—'
                        : '${arabicDigits(bearing.round())}°',
                    label: 'زاوية القبلة',
                  ),
                  const SizedBox(width: 10),
                  _Readout(
                    value: distance == null
                        ? '—'
                        : '${arabicDigits(distance)} كم',
                    label: 'المسافة إلى مكة',
                  ),
                ],
              ),
              if (_reading?.needsCalibration ?? false) ...[
                const SizedBox(height: 10),
                const _Hint(
                  'لمعايرة البوصلة، حرّكي الهاتف على شكل الرقم 8 عدّة مرّات.',
                ),
              ],
              if (_sub != null && _reading == null) ...[
                const SizedBox(height: 10),
                const _Hint(
                  'لا تصل قراءات من بوصلة هذا الجهاز. على الحاسوب تظهر الزاوية فقط؛ استخدمي الهاتف لتدوير السهم.',
                ),
              ],
              const SizedBox(height: 22),
              const TasbeehCounter(),
              const SizedBox(height: 22),
              const MosqueDuas(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Compass extends StatelessWidget {
  const _Compass({required this.bearing, required this.heading});

  final double? bearing;
  final double heading;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 300);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface.withValues(alpha: 0.92),
            border: Border.all(color: colors.gold.withValues(alpha: 0.6)),
          ),
        ),
        AnimatedRotation(
          turns: -heading / 360,
          duration: duration,
          child: CustomPaint(
            size: const Size.square(260),
            painter: _DialPainter(
              tick: colors.muted,
              major: colors.gold,
              label: colors.inkSoft,
            ),
          ),
        ),
        if (bearing != null)
          AnimatedRotation(
            turns: (bearing! - heading) / 360,
            duration: duration,
            child: SizedBox(
              width: 24,
              height: 236,
              child: CustomPaint(painter: _NeedlePainter()),
            ),
          ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.oliveDeep,
          ),
          child: const Icon(Icons.mosque_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

/// Legacy `qiblaDialSVG` + `qiblaDirsHTML`: ticks every 5°, numbered every
/// 30°, and the eight direction names.
class _DialPainter extends CustomPainter {
  _DialPainter({required this.tick, required this.major, required this.label});

  final Color tick;
  final Color major;
  final Color label;

  static const _dirs = [
    (0, 'شمال'),
    (45, 'شمال شرق'),
    (90, 'شرق'),
    (135, 'جنوب شرق'),
    (180, 'جنوب'),
    (225, 'جنوب غرب'),
    (270, 'غرب'),
    (315, 'شمال غرب'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    for (var d = 0; d < 360; d += 5) {
      final isMajor = d % 30 == 0;
      final a = (d - 90) * math.pi / 180;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * r;
      final p2 =
          c + Offset(math.cos(a), math.sin(a)) * (r - (isMajor ? 13 : 7));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = isMajor ? major : tick.withValues(alpha: 0.4)
          ..strokeWidth = isMajor ? 2 : 1,
      );
      if (isMajor) {
        _text(
          canvas,
          '$d',
          c + Offset(math.cos(a), math.sin(a)) * (r - 25),
          10.5,
          label,
          false,
        );
      }
    }
    for (final (deg, name) in _dirs) {
      final a = (deg - 90) * math.pi / 180;
      _text(
        canvas,
        name,
        c + Offset(math.cos(a), math.sin(a)) * (r - 48),
        deg % 90 == 0 ? 12.5 : 10,
        deg == 0 ? major : label,
        deg % 90 == 0,
      );
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    double size,
    Color color,
    bool bold,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.tick != tick || old.major != major || old.label != label;
}

/// Legacy golden arrow (`M12 0 L22 40 L15 36 L15 118 L9 118 L9 36 L2 40 Z`),
/// scaled to point from the centre outwards.
class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / 2;
    final sx = size.width / 24;
    final sy = h / 118;
    final path = Path()
      ..moveTo(12 * sx, 0)
      ..lineTo(22 * sx, 40 * sy)
      ..lineTo(15 * sx, 36 * sy)
      ..lineTo(15 * sx, 118 * sy)
      ..lineTo(9 * sx, 118 * sy)
      ..lineTo(9 * sx, 36 * sy)
      ..lineTo(2 * sx, 40 * sy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8C878), Color(0xFF9A7B3A)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => false;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // A plain button, not a chip: screen readers announced the chips as
    // checkboxes.
    final colors = context.barakahColors;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.ink,
        side: BorderSide(color: colors.line),
        shape: const StadiumBorder(),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.oliveDeep,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: colors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xB312160F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.explore_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy `openQiblaCity`: city + country, geocoded through Aladhan.
class _CitySheet extends ConsumerStatefulWidget {
  const _CitySheet({required this.initialCity, required this.initialCountry});

  final String initialCity;
  final String initialCountry;

  @override
  ConsumerState<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends ConsumerState<_CitySheet> {
  late final _city = TextEditingController(text: widget.initialCity);
  late final _country = TextEditingController(text: widget.initialCountry);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final city = _city.text.trim();
    final country = _country.text.trim();
    if (city.isEmpty) {
      setState(() => _error = 'اكتبي اسم المدينة');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final g = await geocodeCity(city, country);
    if (!mounted) return;
    if (g == null) {
      setState(() {
        _busy = false;
        _error = 'تعذّر إيجاد المدينة — تحقّقي من الاسم والدولة';
      });
      return;
    }
    ref
        .read(userStateControllerProvider.notifier)
        .updateQibla((q) => q.copyWith(lat: g.lat, lng: g.lng, city: city));
    Navigator.of(context).pop(true);
    showSocialSnack(context, 'تم تحديد القبلة لمدينة $city');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'اختيار المدينة',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'لإظهار اتجاه القبلة من مدينتكِ (المصدر: Open-Meteo). يُحفظ اختياركِ.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(
              labelText: 'المدينة',
              hintText: 'مثال: طرابلس',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _country,
            decoration: const InputDecoration(
              labelText: 'الدولة',
              hintText: 'مثال: Libya',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.danger)),
          ],
          const SizedBox(height: 14),
          PremiumButton(
            label: 'حفظ وإظهار القبلة',
            busy: _busy,
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// Legacy "المسبحة": open count or a 33 / 99 / 100 target, saved in
/// `S.tasbeeh`; every tap is recorded as tasbih activity for the tree.
class TasbeehCounter extends ConsumerWidget {
  const TasbeehCounter({super.key});

  static const targets = [0, 33, 99, 100];

  static String subText(int count, int target) {
    if (target > 0) {
      return 'من ${arabicDigits(target)}'
          '${count > 0 ? ' • دورات: ${arabicDigits(count ~/ target)}' : ''}';
    }
    return 'تسبيح مفتوح${count > 0 ? ' • ${arabicDigits(count)}' : ''}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.barakahColors;
    final t = ref.watch(userAppStateProvider.select((s) => s.tasbeeh));
    final controller = ref.read(userStateControllerProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          Text(
            'المسبحة',
            style: TextStyle(
              fontFamily: 'ReemKufi',
              fontSize: 19,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 10),
          LegacySegmentedTabs(
            dense: true,
            labels: [
              for (final v in targets) v == 0 ? 'مفتوح' : arabicDigits(v),
            ],
            selected: targets.contains(t.target)
                ? targets.indexOf(t.target)
                : 0,
            onSelected: (i) => controller.setTasbeehTarget(targets[i]),
          ),
          const SizedBox(height: 8),
          Text(
            'عدٌّ مفتوح بلا حدّ — يُحفظ العدّاد تلقائياً. اختاري هدفاً اختيارياً إن رغبتِ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: 'سبّحي. العدد ${arabicDigits(t.count)}',
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                controller.tapTasbeeh();
                final next = t.count + 1;
                if (t.target > 0 && next % t.target == 0) {
                  HapticFeedback.mediumImpact();
                  showSocialSnack(
                    context,
                    'اكتمل ${arabicDigits(t.target)} تسبيحة — تقبّل الله',
                  );
                } else {
                  HapticFeedback.selectionClick();
                }
              },
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.oliveSoft,
                  border: Border.all(color: colors.olive, width: 6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      arabicDigits(t.count),
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: colors.oliveDeep,
                      ),
                    ),
                    Text(
                      subText(t.count, t.target),
                      style: TextStyle(fontSize: 12, color: colors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: t.count == 0
                ? null
                : () async {
                    final ok = await confirmAction(
                      context,
                      title: 'تصفير العدّاد',
                      message: 'إعادة عدّاد المسبحة إلى الصفر؟',
                      confirmLabel: 'تصفير',
                      destructive: true,
                    );
                    if (!ok) return;
                    controller.resetTasbeeh();
                    if (context.mounted) showSocialSnack(context, 'تم التصفير');
                  },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('تصفير العدّاد'),
          ),
        ],
      ),
    );
  }
}

/// Legacy `mosqueDuasHTML`.
class MosqueDuas extends StatelessWidget {
  const MosqueDuas({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'أدعية المسجد',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'ReemKufi',
            fontSize: 19,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 10),
        _MosqueDua(
          title: 'دعاء دخول المسجد',
          text: 'اللّهُمَّ افتَحْ لي أبوابَ رحمتِك.',
          source: 'رواه مسلم',
        ),
        _MosqueDua(
          title: 'دعاء الخروج من المسجد',
          text: 'اللّهُمَّ إنِّي أسألُكَ مِن فَضلِك.',
          source: 'رواه مسلم',
        ),
      ],
    );
  }
}

class _MosqueDua extends StatelessWidget {
  const _MosqueDua({
    required this.title,
    required this.text,
    required this.source,
  });

  final String title;
  final String text;
  final String source;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mosque_outlined, size: 18, color: colors.olive),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ReemKufi',
                    fontSize: 15,
                    color: colors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 19,
              height: 1.7,
              color: colors.ink,
            ),
          ),
          Text(source, style: TextStyle(fontSize: 12, color: colors.muted)),
        ],
      ),
    );
  }
}
