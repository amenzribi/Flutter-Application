import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:barakah40_flutter/shared/widgets/animated_logo.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';
import 'package:barakah40_flutter/shared/widgets/premium_fields.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .resetPassword(email: _emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(authControllerProvider);
    final busy = formState.isSubmitting;
    final sent =
        formState.status == AuthFormStatus.success &&
        (formState.message?.isNotEmpty ?? false);

    return PremiumScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          enabled: !busy,
          onPressed: () => context.go(AppRoutes.login),
        ),
        title: const Text('استعادة كلمة المرور'),
      ),
      body: ResponsiveContent(
        child: PageEntrance(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              const AnimatedLogoMark(size: 56),
              const SizedBox(height: AppSpacing.lg),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'إعادة التعيين',
                      subtitle:
                          'أدخلي بريدك الإلكتروني وسنرسل رابطاً آمناً لإعادة تعيين كلمة المرور.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumTextField(
                      controller: _emailController,
                      enabled: !busy,
                      label: 'البريد الإلكتروني',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ErrorBanner(
                      message: formState.message,
                      isSuccess: formState.status == AuthFormStatus.success,
                    ),
                    LoadingButton(
                      label: sent ? 'إعادة الإرسال' : 'إرسال الرابط',
                      busy: busy,
                      onPressed: _submit,
                    ),
                    if (sent) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'تحقّقي من البريد ومجلد الرسائل غير المرغوبة إن لزم.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
