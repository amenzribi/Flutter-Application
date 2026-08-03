import 'package:flutter/material.dart';

import 'package:barakah40_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:barakah40_flutter/shared/widgets/premium_fields.dart';

/// Legacy wrapper — prefer [ErrorBanner].
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    super.key,
    this.message,
    this.status = AuthFormStatus.idle,
  });

  final String? message;
  final AuthFormStatus status;

  @override
  Widget build(BuildContext context) {
    return ErrorBanner(
      message: message,
      isSuccess: status == AuthFormStatus.success,
    );
  }
}
