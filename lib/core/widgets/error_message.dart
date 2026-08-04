import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Displays an error message with optional retry action.
class ErrorMessage extends StatelessWidget {
  const ErrorMessage({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          color: AppColors.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onErrorContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
