import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/pawpal_app_bar.dart';
import 'university_entity.dart';

/// Shows every property on one university entity, including description.
class UniversityEntityDetailScreen extends StatelessWidget {
  const UniversityEntityDetailScreen({super.key, required this.entity});

  final UniversityEntity? entity;

  @override
  Widget build(BuildContext context) {
    final entity = this.entity;
    final theme = Theme.of(context);
    final entries = entity?.properties.entries.toList() ?? const [];

    return Scaffold(
      appBar: const PawPalAppBar(title: 'University API Demo', showBack: true),
      body: SafeArea(
        child: entity == null
            ? AppEmptyState(
                icon: Icons.info_outline,
                title: 'Entity unavailable',
                message: 'Open an entity from the list to see its details.',
                actionLabel: 'Back to API login',
                onAction: () => context.go(AppRoutes.universityApi),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final isDescription =
                      entry.key.toLowerCase() == 'description';

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppContentWidth.narrow,
                      ),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                universityPropertyLabel(entry.key),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                universityPropertyValue(entry.value),
                                style: isDescription
                                    ? theme.textTheme.bodyLarge
                                    : theme.textTheme.bodyMedium,
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
