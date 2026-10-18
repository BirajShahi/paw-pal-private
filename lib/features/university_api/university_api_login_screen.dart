import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/pawpal_app_bar.dart';
import '../../core/widgets/primary_button.dart';
import 'university_api_client.dart';
import 'university_api_config.dart';
import 'university_api_providers.dart';

/// Login form for the NIT3213 API.
///
/// The student ID is sent as `username` and the first name as `password`.
/// Neither value is hardcoded.
class UniversityApiLoginScreen extends ConsumerStatefulWidget {
  const UniversityApiLoginScreen({super.key, this.client});

  /// Optional client so tests can substitute responses. When this is empty,
  /// the screen reads [universityApiClientProvider].
  final UniversityApiClient? client;

  @override
  ConsumerState<UniversityApiLoginScreen> createState() =>
      _UniversityApiLoginScreenState();
}

class _UniversityApiLoginScreenState
    extends ConsumerState<UniversityApiLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  /// A test client wins. Otherwise use the shared Riverpod client.
  UniversityApiClient get _client =>
      widget.client ?? ref.read(universityApiClientProvider);

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Signing in...';
    });

    try {
      // Step 1: exchange the typed details for a keypass.
      final keypass = await _client.login(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;

      // Step 2: use that keypass to load the dashboard entities.
      setState(() => _statusMessage = 'Loading entities...');
      final entities = await _client.fetchEntities(keypass);
      if (!mounted) return;

      // Do not keep the first name in the form after a successful login.
      _passwordController.clear();
      await context.push(AppRoutes.universityApiEntities, extra: entities);
    } on UniversityApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const PawPalAppBar(title: 'University API Demo', showBack: true),
      body: SafeArea(
        child: AppContentContainer(
          maxWidth: AppContentWidth.form,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign in to the university API',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This demo is separate from your PawPal account. '
                    'Enter your student ID as the username and your first '
                    'name as the password.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Class location: ${UniversityApiConfig.classLocation}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    controller: _usernameController,
                    labelText: 'Student ID',
                    hintText: 'Username',
                    textInputAction: TextInputAction.next,
                    enabled: !_isSubmitting,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your student ID.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordController,
                    labelText: 'First name',
                    hintText: 'Password',
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    enabled: !_isSubmitting,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show first name'
                          : 'Hide first name',
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your first name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Sign in',
                    icon: Icons.login,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    ErrorMessage(message: _errorMessage!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
