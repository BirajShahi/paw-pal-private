import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pops when possible; otherwise navigates to [fallbackRoute].
void popOrGo(BuildContext context, String fallbackRoute) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackRoute);
  }
}

/// Standard Material back leading for secondary PawPal screens.
Widget appBackLeading(BuildContext context, {required String fallbackRoute}) {
  return IconButton(
    icon: const Icon(Icons.arrow_back),
    tooltip: 'Back',
    onPressed: () => popOrGo(context, fallbackRoute),
  );
}
