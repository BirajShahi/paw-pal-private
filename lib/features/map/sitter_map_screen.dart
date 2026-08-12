import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import '../services/service_filter_chip_bar.dart';
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
                  final horizontalPadding = constraints.maxWidth >= 1000
                      ? 40.0
                      : constraints.maxWidth >= 600
                      ? 24.0
                      : 12.0;
                  final filterReserve = constraints.maxWidth < 600
                      ? 72.0
                      : 100.0;
                  final mapHeight = constraints.maxHeight < 420
                      ? constraints.maxHeight * 0.72
                      : constraints.maxHeight - filterReserve;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          6,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Card(
                              elevation: 0,
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ServiceFilterChipBar(
                                        services: catalogue,
                                        selectedServiceId: _selectedServiceId,
                                        onSelected: (serviceId) {
                                          setState(
                                            () =>
                                                _selectedServiceId = serviceId,
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
                                      borderRadius: BorderRadius.circular(16),
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
          constraints: BoxConstraints(
            maxWidth: maxSheetWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        child: Text(
                          _initials(sitter.fullName),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sitter.fullName,
                              style: theme.textTheme.titleLarge,
                            ),
                            if (location != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: theme.textTheme.bodySmall,
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
                  const SizedBox(height: 16),
                  for (var i = 0; i < sitter.offerings.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 340;
        final detailsColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              serviceName,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(details, style: theme.textTheme.bodyMedium),
          ],
        );
        final bookButton = FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push(AppRoutes.bookingNew(offering.id));
          },
          child: const Text('Book'),
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              detailsColumn,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: bookButton),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: detailsColumn),
            const SizedBox(width: 8),
            bookButton,
          ],
        );
      },
    );
  }
}

class _NoProvidersState extends StatelessWidget {
  const _NoProvidersState();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.pets_outlined,
      title: 'No providers yet',
      message: 'No active PawPal providers are available yet.',
    );
  }
}

class _NoLocationState extends StatelessWidget {
  const _NoLocationState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.map_outlined,
                  size: 36,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No provider map locations are available yet.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You can still browse available providers from Find Pet Care.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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
