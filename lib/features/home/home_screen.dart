import 'package:flutter/material.dart';

import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';

/// Temporary home screen demonstrating core UI components.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  bool _showLoading = false;
  bool _showError = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onPrimaryPressed() {
    setState(() {
      _showLoading = true;
      _showError = false;
    });

    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _showLoading = false;
        _showError = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PawPal')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 600 ? 48.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome to PawPal',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connecting pet owners with trusted sitters.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      AppTextField(
                        controller: _nameController,
                        labelText: 'Your name',
                        hintText: 'Enter your name',
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Get started',
                        isLoading: _showLoading,
                        onPressed: _onPrimaryPressed,
                      ),
                      const SizedBox(height: 32),
                      if (_showLoading)
                        const LoadingIndicator(message: 'Loading…'),
                      if (_showError)
                        ErrorMessage(
                          message: 'Something went wrong. Please try again.',
                          onRetry: () {
                            setState(() => _showError = false);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
