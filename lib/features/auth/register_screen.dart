import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/auth_brand_panel.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/simple_pet_illustration.dart';
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

  static const _benefits = <(IconData, String)>[
    (Icons.auto_awesome_outlined, 'Personalised service recommendations'),
    (Icons.verified_outlined, 'Trusted local pet care'),
    (Icons.event_available_outlined, 'Simple booking management'),
  ];

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;

            if (wide) {
              return SingleChildScrollView(
                child: AppContentContainer(
                  maxWidth: AppContentWidth.auth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 32,
                  ),
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 64,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(
                            flex: 5,
                            child: AuthBrandPanel(
                              headline: 'Join PawPal',
                              supportingText:
                                  'Create an account and make pet care easier. '
                                  'Connect with trusted local care and manage '
                                  'everything in one place.',
                              benefits: _benefits,
                              illustrationKind:
                                  PetIllustrationKind.ownerWithPet,
                            ),
                          ),
                          const SizedBox(width: 40),
                          Expanded(
                            flex: 4,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 480,
                                ),
                                child: _buildFormCard(theme),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              child: AppContentContainer(
                maxWidth: AppContentWidth.form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthBrandPanel(
                      headline: '',
                      supportingText: '',
                      benefits: [],
                      compact: true,
                      illustrationKind: PetIllustrationKind.ownerWithPet,
                    ),
                    const SizedBox(height: 16),
                    _buildFormCard(theme),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create your account',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create an account and make pet care easier.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 14),
              AppTextField(
                controller: _emailController,
                labelText: 'Email',
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
              const SizedBox(height: 14),
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
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
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
              const SizedBox(height: 14),
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
                            _obscureConfirmPassword = !_obscureConfirmPassword;
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
              const SizedBox(height: 18),
              Text('Account role', style: theme.textTheme.titleSmall),
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
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                ErrorMessage(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: 'Create account',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
              const SizedBox(height: 8),
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
    );
  }
}
