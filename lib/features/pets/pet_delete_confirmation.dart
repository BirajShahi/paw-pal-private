import 'package:flutter/material.dart';

/// Confirmation dialog before permanently deleting a pet.
///
/// When [onConfirmed] is provided, it runs after the user taps Delete and
/// before the dialog closes. The dialog cannot be dismissed while that work
/// is in progress.
Future<bool> showDeletePetConfirmationDialog(
  BuildContext context, {
  required String petName,
  Future<void> Function()? onConfirmed,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _DeletePetConfirmationDialog(
        petName: petName,
        onConfirmed: onConfirmed,
      );
    },
  );

  return result ?? false;
}

class _DeletePetConfirmationDialog extends StatefulWidget {
  const _DeletePetConfirmationDialog({required this.petName, this.onConfirmed});

  final String petName;
  final Future<void> Function()? onConfirmed;

  @override
  State<_DeletePetConfirmationDialog> createState() =>
      _DeletePetConfirmationDialogState();
}

class _DeletePetConfirmationDialogState
    extends State<_DeletePetConfirmationDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _onDeletePressed() async {
    if (_isDeleting) return;

    if (widget.onConfirmed == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _errorMessage = null;
      _isDeleting = true;
    });

    try {
      await widget.onConfirmed!();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: Text('Delete ${widget.petName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This pet profile and its care information will be permanently '
              'removed.\n\nThis action cannot be undone.',
            ),
            if (_isDeleting) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isDeleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _isDeleting ? null : _onDeletePressed,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
