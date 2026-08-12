import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import 'profile_model.dart';
import 'profile_providers.dart';
import 'profile_repository.dart';

class SitterProfileScreen extends ConsumerStatefulWidget {
  const SitterProfileScreen({super.key});

  @override
  ConsumerState<SitterProfileScreen> createState() =>
      _SitterProfileScreenState();
}

class _SitterProfileScreenState extends ConsumerState<SitterProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _suburbController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _serviceDescriptionController = TextEditingController();
  final _hourlyPriceController = TextEditingController();

  ProfileModel? _loadedProfile;
  bool _fieldsInitialised = false;
  bool _isSaving = false;
  String? _updateError;

  static final _postcodePattern = RegExp(r'^\d{4}$');

  @override
  void dispose() {
    _fullNameController.dispose();
    _suburbController.dispose();
    _postcodeController.dispose();
    _serviceDescriptionController.dispose();
    _hourlyPriceController.dispose();
    super.dispose();
  }

  void _prefill(ProfileModel profile) {
    if (_fieldsInitialised) return;
    _loadedProfile = profile;
    _fullNameController.text = profile.fullName;
    _suburbController.text = profile.suburb ?? '';
    _postcodeController.text = profile.postcode ?? '';
    _serviceDescriptionController.text = profile.serviceDescription ?? '';
    _hourlyPriceController.text = profile.hourlyPrice == null
        ? ''
        : profile.hourlyPrice!.toStringAsFixed(
            profile.hourlyPrice! % 1 == 0 ? 0 : 2,
          );
    _fieldsInitialised = true;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() => _updateError = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final price = double.parse(_hourlyPriceController.text.trim());

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateSitterProfile(
            fullName: _fullNameController.text.trim(),
            suburb: _suburbController.text.trim(),
            postcode: _postcodeController.text.trim(),
            serviceDescription: _serviceDescriptionController.text.trim(),
            hourlyPrice: price,
            latitude: _loadedProfile?.latitude,
            longitude: _loadedProfile?.longitude,
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
      appBar: AppBar(
        leading: appBackLeading(
          context,
          fallbackRoute: AppRoutes.sitterDashboard,
        ),
        title: const Text('Edit profile'),
      ),
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

            return SingleChildScrollView(
              child: AppContentContainer(
                maxWidth: AppContentWidth.form,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppFormSection(
                        title: 'Basic Details',
                        icon: Icons.person_outline,
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
                          AppTextField(
                            controller: _suburbController,
                            labelText: 'Service area suburb',
                            textInputAction: TextInputAction.next,
                            enabled: !_isSaving,
                            validator: (value) {
                              final suburb = value?.trim() ?? '';
                              if (suburb.isEmpty) {
                                return 'Suburb is required';
                              }
                              if (suburb.length < 2) {
                                return 'Suburb must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          AppTextField(
                            controller: _postcodeController,
                            labelText: 'Postcode',
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppFormSection(
                        title: 'Service Details',
                        icon: Icons.handyman_outlined,
                        children: [
                          AppTextField(
                            controller: _serviceDescriptionController,
                            labelText: 'Service description',
                            hintText:
                                'Describe your services, experience and pets accepted',
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            enabled: !_isSaving,
                            validator: (value) {
                              final description = value?.trim() ?? '';
                              if (description.isEmpty) {
                                return 'Service description is required';
                              }
                              if (description.length < 20) {
                                return 'Description must be at least 20 characters';
                              }
                              if (description.length > 500) {
                                return 'Description must be at most 500 characters';
                              }
                              return null;
                            },
                          ),
                          AppTextField(
                            controller: _hourlyPriceController,
                            labelText: 'Hourly price (AUD)',
                            prefixText: '\$ ',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            enabled: !_isSaving,
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) {
                                return 'Hourly price is required';
                              }
                              final price = double.tryParse(raw);
                              if (price == null) {
                                return 'Enter a valid number';
                              }
                              if (price <= 0) {
                                return 'Hourly price must be greater than 0';
                              }
                              if (price > 500) {
                                return 'Hourly price cannot exceed \$500';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_updateError != null) ...[
                        ErrorMessage(message: _updateError!),
                        const SizedBox(height: 12),
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
            );
          },
        ),
      ),
    );
  }
}
