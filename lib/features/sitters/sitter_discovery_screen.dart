import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../services/service_model.dart';
import '../services/service_providers.dart';
import '../services/sitter_service_model.dart';
import '../services/sitter_services_screen.dart';
import 'discoverable_sitter.dart';
import 'discoverable_sitter_providers.dart';

class SitterDiscoveryScreen extends ConsumerStatefulWidget {
  const SitterDiscoveryScreen({super.key});

  @override
  ConsumerState<SitterDiscoveryScreen> createState() =>
      _SitterDiscoveryScreenState();
}

class _SitterDiscoveryScreenState extends ConsumerState<SitterDiscoveryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedServiceId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(discoverableSittersProvider);
    ref.invalidate(activeServicesProvider);
    await Future.wait([
      ref.read(discoverableSittersProvider.future),
      ref.read(activeServicesProvider.future),
    ]);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedServiceId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sittersAsync = ref.watch(discoverableSittersProvider);
    final servicesAsync = ref.watch(activeServicesProvider);

    return SafeArea(
      child: sittersAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading providers…'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorMessage(
              message: error.toString(),
              onRetry: () => ref.invalidate(discoverableSittersProvider),
            ),
          ),
        ),
        data: (sitters) {
          final catalogue =
              servicesAsync.asData?.value ?? const <ServiceModel>[];
          final filtered = filterDiscoverableSitters(
            sitters,
            serviceId: _selectedServiceId,
            query: _searchQuery,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final useGrid = constraints.maxWidth >= 800;

              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: AppContentContainer(
                        maxWidth: AppContentWidth.page,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Find Pet Care',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                if (kIsWeb)
                                  IconButton(
                                    tooltip: 'Refresh',
                                    onPressed: _refresh,
                                    icon: const Icon(Icons.refresh),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Browse PawPal providers and the services '
                              'they currently offer.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            _FilterPanel(
                              searchController: _searchController,
                              onSearchChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                              services: catalogue,
                              selectedServiceId: _selectedServiceId,
                              onServiceSelected: (serviceId) {
                                setState(() => _selectedServiceId = serviceId);
                              },
                            ),
                            const SizedBox(height: 20),
                            if (sitters.isEmpty)
                              const _EmptyProvidersState()
                            else if (filtered.isEmpty)
                              _FilteredEmptyState(onClear: _clearFilters)
                            else if (useGrid)
                              LayoutBuilder(
                                builder: (context, inner) {
                                  final gap = 12.0;
                                  final itemWidth = (inner.maxWidth - gap) / 2;
                                  return Wrap(
                                    spacing: gap,
                                    runSpacing: gap,
                                    children: [
                                      for (final sitter in filtered)
                                        SizedBox(
                                          width: itemWidth,
                                          child: _SitterDiscoveryCard(
                                            sitter: sitter,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              )
                            else
                              Column(
                                children: [
                                  for (var i = 0; i < filtered.length; i++) ...[
                                    if (i > 0) const SizedBox(height: 12),
                                    _SitterDiscoveryCard(sitter: filtered[i]),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.searchController,
    required this.onSearchChanged,
    required this.services,
    required this.selectedServiceId,
    required this.onServiceSelected,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<ServiceModel> services;
  final String? selectedServiceId;
  final ValueChanged<String?> onServiceSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search by provider or suburb',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: scheme.surface,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 10),
            _ServiceFilterChips(
              services: services,
              selectedServiceId: selectedServiceId,
              onSelected: onServiceSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceFilterChips extends StatelessWidget {
  const _ServiceFilterChips({
    required this.services,
    required this.selectedServiceId,
    required this.onSelected,
  });

  final List<ServiceModel> services;
  final String? selectedServiceId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All Services'),
              selected: selectedServiceId == null || selectedServiceId!.isEmpty,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final service in services)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(service.name),
                selected: selectedServiceId == service.id,
                onSelected: (_) => onSelected(service.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SitterDiscoveryCard extends StatelessWidget {
  const _SitterDiscoveryCard({required this.sitter});

  final DiscoverableSitter sitter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final location = _locationLabel(sitter.suburb, sitter.postcode);
    final description = sitter.serviceDescription;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(
                    _initials(sitter.fullName),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sitter.fullName, style: theme.textTheme.titleMedium),
                      if (location != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 10),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            if (sitter.offerings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < sitter.offerings.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                _OfferingRow(offering: sitter.offerings[i]),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  static String? _locationLabel(String? suburb, String? postcode) {
    final trimmedSuburb = suburb?.trim();
    final trimmedPostcode = postcode?.trim();
    final hasSuburb = trimmedSuburb != null && trimmedSuburb.isNotEmpty;
    final hasPostcode = trimmedPostcode != null && trimmedPostcode.isNotEmpty;

    if (hasSuburb && hasPostcode) {
      return '$trimmedSuburb $trimmedPostcode';
    }
    if (hasSuburb) return trimmedSuburb;
    if (hasPostcode) return trimmedPostcode;
    return null;
  }
}

class _OfferingRow extends StatelessWidget {
  const _OfferingRow({required this.offering});

  final SitterServiceModel offering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serviceName = offering.service?.name;
    if (serviceName == null || serviceName.isEmpty) {
      return const SizedBox.shrink();
    }

    final duration = offering.estimatedDurationMinutes;
    final priceLabel = SitterServicesScreen.formatPrice(offering.price);
    final details = duration == null
        ? priceLabel
        : '$priceLabel • ${SitterServicesScreen.formatDuration(duration)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(details, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.push(AppRoutes.bookingNew(offering.id)),
            child: const Text('Book'),
          ),
        ],
      ),
    );
  }
}

class _EmptyProvidersState extends StatelessWidget {
  const _EmptyProvidersState();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.pets_outlined,
      title: 'No providers yet',
      message: 'No active PawPal providers are available yet.',
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.search_off_outlined,
      title: 'No matches',
      message: 'No providers match your current search or service filter.',
      actionLabel: 'Clear Filters',
      onAction: onClear,
    );
  }
}
