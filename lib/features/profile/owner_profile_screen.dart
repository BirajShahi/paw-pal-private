import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import 'profile_model.dart';
import 'profile_providers.dart';
import 'profile_repository.dart';

class OwnerProfileScreen extends ConsumerStatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  ConsumerState<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends ConsumerState<OwnerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _suburbController = TextEditingController();
  final _postcodeController = TextEditingController();

  bool _fieldsInitialised = false;
  bool _isSaving = false;
  String? _updateError;

  static final _postcodePattern = RegExp(r'^\d{4}$');

  @override
  void dispose() {
    _fullNameController.dispose();
    _suburbController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  void _prefill(ProfileModel profile) {
    if (_fieldsInitialised) return;
    _fullNameController.text = profile.fullName;
    _suburbController.text = profile.suburb ?? '';
    _postcodeController.text = profile.postcode ?? '';
    _fieldsInitialised = true;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() => _updateError = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateOwnerProfile(
            fullName: _fullNameController.text.trim(),
            suburb: _suburbController.text.trim(),
            postcode: _postcodeController.text.trim(),
          );

      ref.invalidate(currentProfileProvider);

      if (!mounted) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully.')),
      );
    } on ProfileException catch (error) {
      if (!mounted) return;
      setState(() {
        _updateError = error.message;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _updateError = 'Could not save your profile. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading profile…'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorMessage(
                message: error.toString(),
                onRetry: () {
                  _fieldsInitialised = false;
                  ref.invalidate(currentProfileProvider);
                },
              ),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return ErrorMessage(
                message: 'Your profile could not be found.',
                onRetry: () {
                  _fieldsInitialised = false;
                  ref.invalidate(currentProfileProvider);
                },
              );
            }

            _prefill(profile);

            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth > 600
                    ? 48.0
                    : 24.0;

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
                            AppTextField(
                              controller: _fullNameController,
                              labelText: 'Full name',
                              textInputAction: TextInputAction.next,
                              enabled: !_isSaving,
                              validator: (value) {
                                final name = value?.trim() ?? '';
                                if (name.isEmpty) {
                                  return 'Full name is required';
                                }
                                if (name.length < 2) {
                                  return 'Full name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _suburbController,
                              labelText: 'Suburb',
                              textInputAction: TextInputAction.next,
                              enabled: !_isSaving,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Suburb is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _postcodeController,
                              labelText: 'Postcode',
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              enabled: !_isSaving,
                              validator: (value) {
                                final postcode = value?.trim() ?? '';
                                if (postcode.isEmpty) {
                                  return 'Postcode is required';
                                }
                                if (!_postcodePattern.hasMatch(postcode)) {
                                  return 'Enter a valid 4-digit Australian postcode';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            if (_updateError != null) ...[
                              ErrorMessage(message: _updateError!),
                              const SizedBox(height: 16),
                            ],
                            PrimaryButton(
                              label: 'Save profile',
                              isLoading: _isSaving,
                              onPressed: _isSaving ? null : _save,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
