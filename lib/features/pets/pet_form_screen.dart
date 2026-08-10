import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import 'pet_delete_confirmation.dart';
import 'pet_model.dart';
import 'pet_providers.dart';
import 'pet_repository.dart';

class PetFormScreen extends ConsumerStatefulWidget {
  const PetFormScreen({super.key, this.petId});

  /// When null, the screen creates a new pet.
  final String? petId;

  bool get isEditing => petId != null;

  @override
  ConsumerState<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends ConsumerState<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _coatTypeController = TextEditingController();
  final _medicalNotesController = TextEditingController();
  final _behaviourNotesController = TextEditingController();
  final _careNotesController = TextEditingController();

  String? _size;
  bool _fieldsInitialised = false;
  bool _isSaving = false;
  String? _saveError;

  bool get _isBusy => _isSaving;

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _coatTypeController.dispose();
    _medicalNotesController.dispose();
    _behaviourNotesController.dispose();
    _careNotesController.dispose();
    super.dispose();
  }

  void _prefill(PetModel pet) {
    if (_fieldsInitialised) return;
    _nameController.text = pet.name;
    _speciesController.text = pet.species;
    _breedController.text = pet.breed ?? '';
    _ageController.text = pet.ageYears == null
        ? ''
        : (pet.ageYears! % 1 == 0
              ? pet.ageYears!.toInt().toString()
              : pet.ageYears!.toString());
    _size = pet.size;
    _coatTypeController.text = pet.coatType ?? '';
    _medicalNotesController.text = pet.medicalNotes ?? '';
    _behaviourNotesController.text = pet.behaviourNotes ?? '';
    _careNotesController.text = pet.careNotes ?? '';
    _fieldsInitialised = true;
  }

  Future<void> _save() async {
    if (_isBusy) return;

    setState(() => _saveError = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final ageText = _ageController.text.trim();
    final ageYears = ageText.isEmpty ? null : double.parse(ageText);

    try {
      final repository = ref.read(petRepositoryProvider);

      if (widget.isEditing) {
        await repository.updatePet(
          petId: widget.petId!,
          name: _nameController.text.trim(),
          species: _speciesController.text.trim(),
          breed: _breedController.text.trim(),
          ageYears: ageYears,
          size: _size,
          coatType: _coatTypeController.text.trim(),
          medicalNotes: _medicalNotesController.text.trim(),
          behaviourNotes: _behaviourNotesController.text.trim(),
          careNotes: _careNotesController.text.trim(),
        );
        ref.invalidate(petByIdProvider(widget.petId!));
      } else {
        await repository.createPet(
          name: _nameController.text.trim(),
          species: _speciesController.text.trim(),
          breed: _breedController.text.trim(),
          ageYears: ageYears,
          size: _size,
          coatType: _coatTypeController.text.trim(),
          medicalNotes: _medicalNotesController.text.trim(),
          behaviourNotes: _behaviourNotesController.text.trim(),
          careNotes: _careNotesController.text.trim(),
        );
      }

      ref.invalidate(currentOwnerPetsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Pet updated successfully.'
                : 'Pet added successfully.',
          ),
        ),
      );
      context.go(AppRoutes.pets);
    } on PetException catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = error.message;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = 'Could not save this pet. Please try again.';
        _isSaving = false;
      });
    }
  }

  Future<void> _deletePet() async {
    if (_isBusy || !widget.isEditing) return;

    final petName = _nameController.text.trim().isEmpty
        ? 'this pet'
        : _nameController.text.trim();
    final petId = widget.petId!;

    setState(() => _saveError = null);

    final deleted = await showDeletePetConfirmationDialog(
      context,
      petName: petName,
      onConfirmed: () => ref.read(petRepositoryProvider).deletePet(petId),
    );

    if (!deleted || !mounted) {
      return;
    }

    ref.invalidate(currentOwnerPetsProvider);
    ref.invalidate(petByIdProvider(petId));

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$petName was deleted.')));
    context.go(AppRoutes.pets);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return _buildScaffold(body: _buildForm());
    }

    final petAsync = ref.watch(petByIdProvider(widget.petId!));

    return _buildScaffold(
      body: petAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading pet…'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorMessage(
              message: error.toString(),
              onRetry: () {
                _fieldsInitialised = false;
                ref.invalidate(petByIdProvider(widget.petId!));
              },
            ),
          ),
        ),
        data: (pet) {
          _prefill(pet);
          return _buildForm();
        },
      ),
    );
  }

  Widget _buildScaffold({required Widget body}) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit pet' : 'Add pet')),
      body: SafeArea(child: body),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: AppContentContainer(
        maxWidth: AppContentWidth.form,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppFormSection(
                title: 'Pet Details',
                icon: Icons.pets_outlined,
                children: [
                  AppTextField(
                    controller: _nameController,
                    labelText: 'Pet name',
                    textInputAction: TextInputAction.next,
                    enabled: !_isBusy,
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.length < 2 || name.length > 60) {
                        return 'Name must be between 2 and 60 characters';
                      }
                      return null;
                    },
                  ),
                  AppTextField(
                    controller: _speciesController,
                    labelText: 'Species',
                    hintText: 'e.g. Dog, Cat',
                    textInputAction: TextInputAction.next,
                    enabled: !_isBusy,
                    validator: (value) {
                      final species = value?.trim() ?? '';
                      if (species.length < 2 || species.length > 40) {
                        return 'Species must be between 2 and 40 characters';
                      }
                      return null;
                    },
                  ),
                  AppTextField(
                    controller: _breedController,
                    labelText: 'Breed (optional)',
                    textInputAction: TextInputAction.next,
                    enabled: !_isBusy,
                    validator: (value) {
                      final breed = value?.trim() ?? '';
                      if (breed.length > 80) {
                        return 'Breed may contain up to 80 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppFormSection(
                title: 'Physical Details',
                icon: Icons.straighten_outlined,
                children: [
                  AppTextField(
                    controller: _ageController,
                    labelText: 'Age in years (optional)',
                    hintText: 'e.g. 1, 2, 0.5',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    enabled: !_isBusy,
                    validator: (value) {
                      final raw = value?.trim() ?? '';
                      if (raw.isEmpty) return null;
                      final age = double.tryParse(raw);
                      if (age == null) {
                        return 'Enter a valid number';
                      }
                      if (age < 0 || age > 100) {
                        return 'Age must be between 0 and 100';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: _size,
                    decoration: const InputDecoration(labelText: 'Size'),
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Not specified'),
                      ),
                      DropdownMenuItem(value: 'small', child: Text('Small')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'large', child: Text('Large')),
                    ],
                    onChanged: _isBusy
                        ? null
                        : (value) => setState(() => _size = value),
                  ),
                  AppTextField(
                    controller: _coatTypeController,
                    labelText: 'Coat type (optional)',
                    hintText: 'e.g. Short, Long, Double coat',
                    textInputAction: TextInputAction.next,
                    enabled: !_isBusy,
                    validator: (value) {
                      final coat = value?.trim() ?? '';
                      if (coat.length > 80) {
                        return 'Coat type may contain up to 80 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const AppInfoBanner(
                icon: Icons.auto_awesome,
                message:
                    'PawPal uses these details to provide more personalised '
                    'service recommendations. Later, these details can help '
                    'recommend services such as Full Grooming, Wash and Dry, '
                    'De-shedding Treatment, Nail Clipping and Senior Pet Grooming.',
              ),
              const SizedBox(height: 16),
              AppFormSection(
                title: 'Care & Behaviour',
                icon: Icons.favorite_outline,
                children: [
                  AppTextField(
                    controller: _medicalNotesController,
                    labelText: 'Medical notes (optional)',
                    maxLines: 3,
                    enabled: !_isBusy,
                    validator: (value) {
                      final notes = value?.trim() ?? '';
                      if (notes.length > 1000) {
                        return 'Medical notes may contain up to 1000 characters';
                      }
                      return null;
                    },
                  ),
                  AppTextField(
                    controller: _behaviourNotesController,
                    labelText: 'Behaviour notes (optional)',
                    maxLines: 3,
                    enabled: !_isBusy,
                    validator: (value) {
                      final notes = value?.trim() ?? '';
                      if (notes.length > 1000) {
                        return 'Behaviour notes may contain up to 1000 characters';
                      }
                      return null;
                    },
                  ),
                  AppTextField(
                    controller: _careNotesController,
                    labelText: 'Care instructions (optional)',
                    maxLines: 3,
                    enabled: !_isBusy,
                    validator: (value) {
                      final notes = value?.trim() ?? '';
                      if (notes.length > 1000) {
                        return 'Care notes may contain up to 1000 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_saveError != null) ...[
                ErrorMessage(message: _saveError!),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: widget.isEditing ? 'Save changes' : 'Add pet',
                isLoading: _isSaving,
                onPressed: _isBusy ? null : _save,
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : _deletePet,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Delete pet'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
