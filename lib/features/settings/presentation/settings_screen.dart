import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/utils/auth_error_mapper.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_providers.dart';
import 'package:barakah40_flutter/features/home/presentation/providers/home_providers.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/presentation/providers/adhan_alert_provider.dart';
import 'package:barakah40_flutter/features/settings/presentation/legal_texts.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

/// Legacy settings sheet and account page (`openSettings`, `openAccount`)
/// as one page: account actions, journal, help and legal pages, restart.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final colors = context.barakahColors;
    final isPassword = user?.isPasswordUser ?? false;

    void info(InfoPageContent c) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => InfoPage(content: c)));

    return PremiumScaffold(
      style: PremiumScaffoldStyle.photo,
      backgroundImage: ref.watch(dayPeriodProvider).backgroundAsset,
      appBar: AppBar(
        foregroundColor: Colors.white,
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('الإعدادات'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: ResponsiveContent(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _Group(
                title: 'حسابك',
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.oliveSoft,
                      child: Icon(
                        Icons.person_outline,
                        color: colors.oliveDeep,
                      ),
                    ),
                    title: Text(
                      (user?.displayName ?? '').trim().isEmpty
                          ? 'بدون اسم'
                          : user!.displayName!,
                    ),
                    subtitle: Text(
                      user?.email ?? '',
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  _Row(
                    icon: Icons.edit_outlined,
                    label: 'تعديل الاسم',
                    onTap: () => _editName(context, ref),
                  ),
                  if (isPassword)
                    _Row(
                      icon: Icons.lock_outline,
                      label: 'تغيير كلمة المرور',
                      onTap: () => _changePassword(context, ref),
                    ),
                  _Row(
                    icon: Icons.logout_rounded,
                    label: 'تسجيل الخروج',
                    onTap: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                    },
                  ),
                ],
              ),
              _Group(
                title: 'دفتري',
                children: [
                  _Row(
                    icon: Icons.edit_note_rounded,
                    label: 'دفتر المشاعر',
                    subtitle: 'اكتبي ما شعرتِ به بعد القراءة',
                    onTap: () => context.push(AppRoutes.journal),
                  ),
                ],
              ),
              const _AdhanGroup(),
              _Group(
                title: 'عن التطبيق',
                children: [
                  _Row(
                    icon: Icons.help_outline,
                    label: 'المساعدة',
                    onTap: () => info(helpContent),
                  ),
                  _Row(
                    icon: Icons.info_outline,
                    label: 'عن التطبيق',
                    onTap: () => info(aboutContent),
                  ),
                  _Row(
                    icon: Icons.shield_outlined,
                    label: 'الخصوصية',
                    onTap: () => info(privacyContent),
                  ),
                  _Row(
                    icon: Icons.description_outlined,
                    label: 'الشروط',
                    onTap: () => info(termsContent),
                  ),
                  _Row(
                    icon: Icons.mail_outline,
                    label: 'تواصل معنا',
                    onTap: () => info(contactContent),
                  ),
                ],
              ),
              _Group(
                title: 'إجراءات نهائية',
                children: [
                  _Row(
                    icon: Icons.restart_alt_rounded,
                    label: 'إعادة التحدّي',
                    subtitle: 'يمسح كل التقدّم',
                    danger: true,
                    onTap: () => _restart(context, ref),
                  ),
                  _Row(
                    icon: Icons.delete_forever_outlined,
                    label: 'حذف الحساب',
                    subtitle: 'إجراء نهائي',
                    danger: true,
                    onTap: () => _deleteAccount(context, ref, isPassword),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final current = ref.read(currentUserProvider)?.displayName ?? '';
    final name = await _askText(
      context,
      title: 'الاسم الظاهر',
      initial: current,
      hint: 'يظهر لصديقاتكِ',
    );
    if (name == null) return;
    if (name.trim().length < 2) {
      if (context.mounted) showSocialSnack(context, 'اكتبي حرفين على الأقل');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(name);
      if (context.mounted) showSocialSnack(context, 'تم تحديث الاسم');
    } catch (e) {
      if (context.mounted) showSocialSnack(context, 'تعذّر تحديث الاسم');
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PasswordSheet(),
    );
    if (result == null) return;
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(currentPassword: result.$1, newPassword: result.$2);
      if (context.mounted) showSocialSnack(context, 'تم تغيير كلمة المرور');
    } catch (e) {
      if (context.mounted) showSocialSnack(context, AuthErrorMapper.map(e));
    }
  }

  Future<void> _restart(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'إعادة البدء من جديد',
      message:
          'سيتم تصفير كل التقدّم والنقاط والشجرة والإنجازات. لن يُحذف حسابك ولا أصدقاؤك ولا الإعدادات. هل أنتِ متأكدة؟',
      confirmLabel: 'نعم، ابدأ من جديد',
      destructive: true,
    );
    if (!ok) return;
    ref.read(userStateControllerProvider.notifier).restartChallenge();
    if (context.mounted) {
      showSocialSnack(context, 'تمّت إعادة البدء — عاد كل شيء من الصفر');
      context.go(AppRoutes.home);
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    bool isPassword,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'حذف الحساب',
      message:
          'سيُحذف حسابك وكل بياناتك نهائياً ولا يمكن التراجع: التقدّم، الصداقات، التحديات التي أنشأتِها. تبقى رسائلكِ المرسلة عند من استلمها. هل أنتِ متأكدة؟',
      confirmLabel: 'حذف نهائي',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    String? password;
    if (isPassword) {
      password = await _askText(
        context,
        title: 'أدخلي كلمة المرور الحالية للمتابعة',
        obscure: true,
      );
      if (password == null || password.isEmpty || !context.mounted) return;
    }
    final me = ref.read(socialIdentityProvider);
    final auth = ref.read(authRepositoryProvider);
    final social = ref.read(socialRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.reauthenticate(password: password);
      if (me != null) await social.removeMySocialData(me);
      await auth.deleteAccount();
      messenger.showSnackBar(const SnackBar(content: Text('تم حذف الحساب')));
    } on SocialException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AuthErrorMapper.map(e))));
    }
  }
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  bool obscure = false,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: obscure,
        maxLength: obscure ? null : 60,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  void _submit() {
    if (_current.text.isEmpty) {
      setState(() => _error = 'أدخلي كلمة المرور الحالية');
      return;
    }
    if (_next.text.length < 6) {
      setState(() => _error = 'كلمة المرور الجديدة 6 أحرف على الأقل');
      return;
    }
    Navigator.of(context).pop((_current.text, _next.text));
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
            'تغيير كلمة المرور',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الجديدة (6 أحرف على الأقل)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.danger)),
          ],
          const SizedBox(height: 14),
          PremiumButton(label: 'حفظ', onPressed: _submit),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'ReemKufi',
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
          // A Material surface (not a decorated box) so tapping a row shows
          // its ripple.
          Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// Adhan alert switch (legacy `S.reminder.prayer`) and a test button.
class _AdhanGroup extends ConsumerWidget {
  const _AdhanGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.barakahColors;
    final notifier = ref.watch(adhanNotifierProvider);
    final on = ref.watch(adhanAlertsEnabledProvider) && notifier.granted;
    final hasPlace = ref.watch(
      userAppStateProvider.select(
        (s) => s.prayer.city.trim().isNotEmpty || s.prayer.extra['lat'] is num,
      ),
    );

    void say(String text) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));

    Future<void> toggle(bool value) async {
      final controller = ref.read(userStateControllerProvider.notifier);
      if (!value) {
        controller.updateReminder((r) => r.copyWith(prayer: false));
        return;
      }
      final allowed = await notifier.requestPermission();
      if (!allowed) {
        say(
          'اسمحي بالإشعارات لهذا الموقع من إعدادات المتصفح ثم أعيدي المحاولة',
        );
        return;
      }
      controller.updateReminder((r) => r.copyWith(enabled: true, prayer: true));
      if (!hasPlace) say('اختاري مدينتكِ في صفحة الصلاة لتصلكِ التنبيهات');
    }

    return _Group(
      title: 'التنبيهات',
      children: [
        SwitchListTile(
          secondary: Icon(
            Icons.notifications_active_outlined,
            color: colors.olive,
          ),
          title: Text('تنبيه الأذان', style: TextStyle(color: colors.ink)),
          subtitle: Text(
            notifier.supported
                ? 'إشعار عند دخول وقت كل صلاة ما دام التطبيق مفتوحًا'
                : 'متاح حاليًا في نسخة المتصفح فقط',
          ),
          value: on,
          onChanged: notifier.supported ? toggle : null,
        ),
        if (on)
          _Row(
            icon: Icons.campaign_outlined,
            label: 'تجربة التنبيه الآن',
            onTap: () => notifier.show(
              title: adhanTitle(PrayerName.dhuhr),
              body: adhanBody,
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final color = danger ? colors.danger : colors.ink;
    return ListTile(
      leading: Icon(icon, color: danger ? colors.danger : colors.olive),
      title: Text(label, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(Icons.chevron_left, color: colors.muted),
      onTap: onTap,
    );
  }
}

/// Plain reading page for help, about, privacy, terms and contact.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.content});

  final InfoPageContent content;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(content.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            for (final s in content.sections) ...[
              if (s.heading != null) ...[
                Text(
                  s.heading!,
                  style: TextStyle(
                    fontFamily: 'ReemKufi',
                    fontSize: 16,
                    color: colors.oliveDeep,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (s.body == contactEmail)
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        s.body,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.oliveDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'نسخ البريد',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(text: contactEmail),
                        );
                        showSocialSnack(context, 'نُسخ البريد');
                      },
                    ),
                  ],
                )
              else
                Text(
                  s.body,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.8,
                    color: colors.ink,
                  ),
                ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}
