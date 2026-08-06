import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_providers.dart';
import 'auth_role.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AuthRole _role = AuthRole.owner;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final role = _role;

    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            fullName: fullName,
            email: email,
            password: password,
            role: role,
          );

      if (!mounted) return;

      if (role == AuthRole.owner) {
        context.go(AppRoutes.owner);
      } else {
        context.go(AppRoutes.sitterDashboard);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Registration failed. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Join PawPal',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create an account to connect with pet care.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        AppTextField(
                          controller: _fullNameController,
                          labelText: 'Full name',
                          textInputAction: TextInputAction.next,
                          enabled: !_isSubmitting,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _emailController,
                          labelText: 'Email address',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !_isSubmitting,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Email is required';
                            }
                            if (!_emailPattern.hasMatch(email)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          enabled: !_isSubmitting,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _confirmPasswordController,
                          labelText: 'Confirm password',
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          enabled: !_isSubmitting,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                            tooltip: _obscureConfirmPassword
                                ? 'Show password'
                                : 'Hide password',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Account role',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<AuthRole>(
                          segments: const [
                            ButtonSegment<AuthRole>(
                              value: AuthRole.owner,
                              label: Text('Pet Owner'),
                              icon: Icon(Icons.pets_outlined),
                            ),
                            ButtonSegment<AuthRole>(
                              value: AuthRole.sitter,
                              label: Text('Pet Sitter'),
                              icon: Icon(Icons.handshake_outlined),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: _isSubmitting
                              ? null
                              : (selection) {
                                  setState(() => _role = selection.first);
                                },
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null) ...[
                          ErrorMessage(message: _errorMessage!),
                          const SizedBox(height: 16),
                        ],
                        if (_isSubmitting) ...[
                          const LoadingIndicator(message: 'Creating account…'),
                          const SizedBox(height: 16),
                        ],
                        PrimaryButton(
                          label: 'Create account',
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _submit,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => context.go(AppRoutes.login),
                          child: const Text('Already have an account? Log in'),
                        ),
                      ],
                    ),
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
