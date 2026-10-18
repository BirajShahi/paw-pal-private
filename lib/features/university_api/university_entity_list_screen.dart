import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/app_content_container.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/pawpal_app_bar.dart';
import 'university_entity.dart';

/// Shows dashboard entities in a [ListView.builder].
class UniversityEntityListScreen extends StatelessWidget {
  const UniversityEntityListScreen({super.key, required this.entities});

  /// Null when the screen is opened without data, for example after a
  /// browser refresh. The entities are passed in memory from the login screen.
  final List<UniversityEntity>? entities;

  @override
  Widget build(BuildContext context) {
    final entities = this.entities;

    return Scaffold(
      appBar: const PawPalAppBar(title: 'University API Demo', showBack: true),
      body: SafeArea(
        child: entities == null
            ? AppEmptyState(
                icon: Icons.school_outlined,
                title: 'Sign in again',
                message:
                    'The entity list is only available after a successful '
                    'university API login.',
                actionLabel: 'Back to API login',
                onAction: () => context.go(AppRoutes.universityApi),
              )
            : entities.isEmpty
            ? const AppEmptyState(
                icon: Icons.inbox_outlined,
                title: 'No entities',
                message: 'The dashboard did not return any entities.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      '${entities.length} entities',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    // builder creates each row only when it scrolls into view.
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: entities.length,
                      itemBuilder: (context, index) {
                        final entity = entities[index];
                        final description = entity.description;

                        return Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppContentWidth.narrow,
                            ),
                            child: Card(
                              child: ListTile(
                                title: Text(entity.listTitle(index)),
                                subtitle: description == null
                                    ? null
                                    : Text(
                                        description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  context.push(
                                    AppRoutes.universityApiEntity,
                                    extra: entity,
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
