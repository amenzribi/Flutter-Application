import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_fields.dart';

/// Manual city/country entry + "استخدم موقعي" (legacy `openCity`'s sheet).
class PrayerCitySheet extends StatefulWidget {
  const PrayerCitySheet({
    super.key,
    required this.initialCity,
    required this.initialCountry,
    required this.onSave,
    required this.onUseLocation,
  });

  final String initialCity;
  final String initialCountry;
  final void Function(String city, String country) onSave;
  final VoidCallback onUseLocation;

  @override
  State<PrayerCitySheet> createState() => _PrayerCitySheetState();
}

class _PrayerCitySheetState extends State<PrayerCitySheet> {
  late final TextEditingController _cityController = TextEditingController(
    text: widget.initialCity,
  );
  late final TextEditingController _countryController = TextEditingController(
    text: widget.initialCountry,
  );
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      setState(() => _error = 'اكتبي اسم المدينة');
      return;
    }
    widget.onSave(city, _countryController.text.trim());
    Navigator.of(context).pop();
  }

  void _handleUseLocation() {
    widget.onUseLocation();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.mosque_outlined, color: colors.oliveDeep),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'مدينة الصلاة',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'تُحسب أوقات الصلاة حسب مدينتك (المصدر: Aladhan). يُحفظ اختيارك '
            'ويتزامن.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_error != null) ...[
            ErrorBanner(message: _error),
            const SizedBox(height: AppSpacing.xs),
          ],
          PremiumTextField(
            controller: _cityController,
            label: 'المدينة (مثال: طرابلس)',
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumTextField(
            controller: _countryController,
            label: 'الدولة (مثال: Libya)',
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumButton(label: 'حفظ وجلب الأوقات', onPressed: _handleSave),
          const SizedBox(height: AppSpacing.sm),
          PremiumButton(
            label: 'استخدام موقعي الحالي',
            icon: Icons.my_location_rounded,
            variant: PremiumButtonVariant.secondary,
            onPressed: _handleUseLocation,
          ),
        ],
      ),
    );
  }
}
