import 'package:flutter/material.dart';

/// Responsive content width and padding for PawPal screens.
///
/// Mobile: full width with compact padding.
/// Tablet/desktop: centred with a max width suited to content or forms.
class AppContentContainer extends StatelessWidget {
  const AppContentContainer({
    super.key,
    required this.child,
    this.maxWidth = AppContentWidth.page,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontal = padding != null
            ? null
            : (width >= 1100
                  ? 40.0
                  : width >= 700
                  ? 24.0
                  : 16.0);
        final resolvedPadding =
            padding ??
            EdgeInsets.symmetric(horizontal: horizontal!, vertical: 20);

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: resolvedPadding, child: child),
          ),
        );
      },
    );
  }
}

/// Common max-width presets for [AppContentContainer].
abstract final class AppContentWidth {
  static const double form = 600;
  static const double auth = 1180;
  static const double narrow = 720;
  static const double page = 1200;
  static const double wide = 1280;
}
