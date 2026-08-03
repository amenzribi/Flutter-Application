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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (ok && mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(authControllerProvider);
    final busy = formState.isSubmitting;

    return PremiumScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          enabled: !busy,
          onPressed: () => context.go(AppRoutes.welcome),
        ),
        title: const Text('إنشاء حساب'),
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
                              title: 'انضمّي إلى بركة 40',
                              subtitle:
                                  'أنشئي حساباً لحفظ تقدّمك ومزامنته بين الأجهزة.',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PremiumTextField(
                              controller: _nameController,
                              enabled: !busy,
                              label: 'الاسم (يظهر لصديقاتك)',
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: AppSpacing.sm),
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
                              label: 'كلمة المرور (6 أحرف على الأقل)',
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ErrorBanner(
                              message: formState.message,
                              isSuccess:
                                  formState.status == AuthFormStatus.success,
                            ),
                            LoadingButton(
                              label: 'إنشاء الحساب',
                              busy: busy,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => context.go(AppRoutes.login),
                        child: const Text('لديكِ حساب؟ سجّلي الدخول'),
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
