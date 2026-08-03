import 'package:flutter/material.dart';

import 'package:barakah40_flutter/shared/widgets/premium_fields.dart';

/// Legacy wrapper — prefer [LoadingButton].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LoadingButton(label: label, busy: busy, onPressed: onPressed);
  }
}
