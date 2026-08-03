import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_card.dart';
import 'package:barakah40_flutter/shared/widgets/premium_fields.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';
import 'package:barakah40_flutter/shared/widgets/responsive_content.dart';
import 'package:barakah40_flutter/shared/widgets/animated_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (ok && mounted) {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _google() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (ok && mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(authControllerProvider);
    final busy = formState.isSubmitting;
    final colors = context.barakahColors;

    return PremiumScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          enabled: !busy,
          onPressed: () => context.go(AppRoutes.welcome),
        ),
        title: const Text('تسجيل الدخول'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: ResponsiveContent(
                child: PageEntrance(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      const Center(child: AnimatedLogoMark(size: 56)),
                      const SizedBox(height: AppSpacing.lg),
                      PremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(
                              title: 'مرحباً بعودتك',
                              subtitle: 'ادخلي بحسابك لمتابعة مزامنة تقدّمك.',
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
                            const SizedBox(height: AppSpacing.sm),
                            PremiumPasswordField(
                              controller: _passwordController,
                              enabled: !busy,
                              label: 'كلمة المرور',
                              autofillHints: const [AutofillHints.password],
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: busy
                                    ? null
                                    : () =>
                                          context.go(AppRoutes.forgotPassword),
                                child: const Text('نسيتِ كلمة المرور؟'),
                              ),
                            ),
                            ErrorBanner(
                              message: formState.message,
                              isSuccess:
                                  formState.status == AuthFormStatus.success,
                            ),
                            LoadingButton(
                              label: 'دخول',
                              busy: busy,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(child: Divider(color: colors.line)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                  ),
                                  child: Text(
                                    'أو',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                                Expanded(child: Divider(color: colors.line)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            PremiumButton(
                              label: 'المتابعة مع Google',
                              variant: PremiumButtonVariant.secondary,
                              icon: Icons.g_mobiledata,
                              busy: busy,
                              onPressed: busy ? null : _google,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => context.go(AppRoutes.register),
                        child: const Text('ليس لديكِ حساب؟ أنشئي حسابًا'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
