import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/error_message.dart';
import '../../core/widgets/loading_indicator.dart';
import 'sitter_service_model.dart';
import 'sitter_service_providers.dart';

class SitterServicesScreen extends ConsumerWidget {
  const SitterServicesScreen({super.key});

  static String formatPrice(double price) => '\$${price.toStringAsFixed(2)}';

  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    }
    if (minutes == 60) {
      return '1 hour';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    final hourLabel = hours == 1 ? '1 hour' : '$hours hours';

    if (remainingMinutes == 0) {
      return hourLabel;
    }

    return '$hourLabel $remainingMinutes minutes';
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentSitterServicesProvider);
    await ref.read(currentSitterServicesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsAsync = ref.watch(currentSitterServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My services')),
      body: SafeArea(
        child: offeringsAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading services…'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorMessage(
                message: error.toString(),
                onRetry: () => ref.invalidate(currentSitterServicesProvider),
              ),
            ),
          ),
          data: (offerings) {
            if (offerings.isEmpty) {
              return _EmptyServicesState(
                onRefresh: () => ref.invalidate(currentSitterServicesProvider),
                onAdd: () => context.go(AppRoutes.sitterServiceNew),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: AppContentContainer(
                          maxWidth: AppContentWidth.narrow,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Services you offer',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              if (kIsWeb)
                                IconButton(
                                  tooltip: 'Refresh',
                                  onPressed: () => _refresh(ref),
                                  icon: const Icon(Icons.refresh),
                                ),
                              IconButton(
                                tooltip: 'Add service',
                                onPressed: () =>
                                    context.go(AppRoutes.sitterServiceNew),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: AppContentContainer(
                          maxWidth: AppContentWidth.narrow,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            children: [
                              for (var i = 0; i < offerings.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _ServiceOfferingCard(
                                    offering: offerings[i],
                                  ),
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
      ),
    );
  }
}

class _EmptyServicesState extends StatelessWidget {
  const _EmptyServicesState({required this.onRefresh, required this.onAdd});

  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.handyman_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No services yet',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Add the exact services you offer so pet owners can find and '
                'book you for care such as Full Grooming, Wash and Dry, '
                'De-shedding Treatment and Nail Clipping.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Service'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceOfferingCard extends StatelessWidget {
  const _ServiceOfferingCard({required this.offering});

  final SitterServiceModel offering;

  @override
  Widget build(BuildContext context) {
    final service = offering.service;
    final serviceName = service?.name ?? 'Unknown service';
    final categoryName = service?.category.displayName ?? 'Uncategorised';
    // Kept for later AI matching against catalogue codes.
    final serviceCode = service?.code;

    final theme = Theme.of(context);
    final duration = offering.estimatedDurationMinutes;

    return Opacity(
      opacity: offering.isActive ? 1 : 0.72,
      child: Card(
        elevation: offering.isActive ? 0 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: offering.isActive
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        // serviceCode retained on [offering.service] for later AI matching.
        key: ValueKey(serviceCode ?? offering.id),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.go(AppRoutes.sitterServiceEdit(offering.id));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(serviceName, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            categoryName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(offering.isActive ? 'Active' : 'Inactive'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: offering.isActive
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        color: offering.isActive
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  SitterServicesScreen.formatPrice(offering.price),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (duration != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Estimated duration: ${SitterServicesScreen.formatDuration(duration)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (offering.serviceNotes != null &&
                    offering.serviceNotes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    offering.serviceNotes!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
