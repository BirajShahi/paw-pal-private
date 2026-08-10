import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../services/service_model.dart';
import '../services/service_providers.dart';
import '../services/sitter_service_model.dart';
import '../services/sitter_services_screen.dart';
import '../sitters/discoverable_sitter.dart';
import '../sitters/discoverable_sitter_providers.dart';

/// Owner map of active providers with stored coordinates.
class SitterMapScreen extends ConsumerStatefulWidget {
  const SitterMapScreen({super.key});

  static const osmUserAgentPackageName = 'com.birajshahi.paw_pal';

  @override
  ConsumerState<SitterMapScreen> createState() => _SitterMapScreenState();
}

class _SitterMapScreenState extends ConsumerState<SitterMapScreen> {
  String? _selectedServiceId;

  Future<void> _refresh() async {
    ref.invalidate(discoverableSittersProvider);
    await ref.read(discoverableSittersProvider.future);
  }

  void _clearFilter() {
    setState(() => _selectedServiceId = null);
  }

  Future<void> _showSitterDetails(DiscoverableSitter sitter) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _SitterMapDetailsSheet(sitter: sitter);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoveryAsync = ref.watch(discoverableSittersProvider);
    final servicesAsync = ref.watch(activeServicesProvider);

    return SafeArea(
      child: discoveryAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading map…'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorMessage(
              message: error.toString(),
              onRetry: () => ref.invalidate(discoverableSittersProvider),
            ),
          ),
        ),
        data: (allSitters) {
          if (allSitters.isEmpty) {
            return const _NoProvidersState();
          }

          final mapSittersAsync = ref.watch(mapSittersProvider);
          return mapSittersAsync.when(
            loading: () => const LoadingIndicator(message: 'Loading map…'),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorMessage(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(discoverableSittersProvider),
                ),
              ),
            ),
            data: (mapSitters) {
              if (mapSitters.isEmpty) {
                return const _NoLocationState();
              }

              final catalogue =
                  servicesAsync.asData?.value ?? const <ServiceModel>[];
              final visible = filterDiscoverableSitters(
                mapSitters,
                serviceId: _selectedServiceId,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth > 600
                      ? 48.0
                      : 12.0;
                  final mapHeight = constraints.maxHeight < 420
                      ? constraints.maxHeight * 0.7
                      : constraints.maxHeight - 120;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          8,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ServiceFilterChips(
                                    services: catalogue,
                                    selectedServiceId: _selectedServiceId,
                                    onSelected: (serviceId) {
                                      setState(
                                        () => _selectedServiceId = serviceId,
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Refresh',
                                  onPressed: _refresh,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (visible.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 8,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: _FilteredEmptyBanner(
                                onClear: _clearFilter,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            0,
                            horizontalPadding,
                            12,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 960,
                                minHeight: 240,
                                maxHeight: mapHeight.isFinite ? mapHeight : 480,
                              ),
                              child: visible.isEmpty
                                  ? const SizedBox.expand()
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _ProvidersMap(
                                        sitters: visible,
                                        onMarkerTap: _showSitterDetails,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ProvidersMap extends StatelessWidget {
  const _ProvidersMap({required this.sitters, required this.onMarkerTap});

  final List<DiscoverableSitter> sitters;
  final ValueChanged<DiscoverableSitter> onMarkerTap;

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      for (final sitter in sitters) LatLng(sitter.latitude!, sitter.longitude!),
    ];

    final MapOptions options;
    if (points.length == 1) {
      options = MapOptions(initialCenter: points.first, initialZoom: 13);
    } else {
      options = MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(48),
          maxZoom: 14,
        ),
      );
    }

    return FlutterMap(
      options: options,
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: SitterMapScreen.osmUserAgentPackageName,
        ),
        MarkerLayer(
          markers: [
            for (final sitter in sitters)
              Marker(
                point: LatLng(sitter.latitude!, sitter.longitude!),
                width: 48,
                height: 48,
                child: GestureDetector(
                  onTap: () => onMarkerTap(sitter),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
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

class _SitterMapDetailsSheet extends StatelessWidget {
  const _SitterMapDetailsSheet({required this.sitter});

  final DiscoverableSitter sitter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _locationLabel(sitter.suburb, sitter.postcode);
    final description = sitter.serviceDescription;
    final maxSheetWidth = MediaQuery.sizeOf(context).width > 720
        ? 560.0
        : double.infinity;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxSheetWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sitter.fullName, style: theme.textTheme.titleLarge),
                  if (location != null) ...[
                    const SizedBox(height: 4),
                    Text(location, style: theme.textTheme.bodySmall),
                  ],
                  if (description != null) ...[
                    const SizedBox(height: 8),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 16),
                  for (var i = 0; i < sitter.offerings.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _OfferingRow(offering: sitter.offerings[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

    return Row(
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
          onPressed: () {
            Navigator.of(context).pop();
            context.push(AppRoutes.bookingNew(offering.id));
          },
          child: const Text('Book'),
        ),
      ],
    );
  }
}

class _NoProvidersState extends StatelessWidget {
  const _NoProvidersState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No active PawPal providers are available yet.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _NoLocationState extends StatelessWidget {
  const _NoLocationState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No provider map locations are available yet.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You can still browse available providers from Find Pet Care.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.sitters),
                child: const Text('Browse Providers'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilteredEmptyBanner extends StatelessWidget {
  const _FilteredEmptyBanner({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'No map providers currently offer this service.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Clear Filter'),
            ),
          ],
        ),
      ),
    );
  }
}
