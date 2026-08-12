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
import 'auth_repository.dart';
import 'auth_role.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final authRepository = ref.read(authRepositoryProvider);

    try {
      await authRepository.logIn(email: email, password: password);
      final role = await authRepository.getCurrentUserRole();

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
    } on ProfileRoleException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Sign in failed. Please try again.';
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
              return AppContentContainer(
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
                            headline:
                                'Better care starts with understanding your pet.',
                            supportingText:
                                'Find trusted local care, get personalised '
                                'service recommendations and manage everything '
                                'in one place.',
                            benefits: _benefits,
                            illustrationKind: PetIllustrationKind.ownerWithPet,
                          ),
                        ),
                        const SizedBox(width: 40),
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: _buildFormCard(theme),
                            ),
                          ),
                        ),
                      ],
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
                'Welcome back',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in to continue to PawPal.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
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
                textInputAction: TextInputAction.done,
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
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                ErrorMessage(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: 'Log in',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => context.go(AppRoutes.register),
                child: const Text('Need an account? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
