import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Which flat illustration to show.
enum PetIllustrationKind {
  /// Owner kneeling beside a pet (auth panels).
  ownerWithPet,

  /// Sitter with pet and care symbols (sitter dashboard).
  sitterWithPet,

  /// Owner and pet with heart/paw accents (owner dashboard).
  ownerCare,
}

/// Simple flat pet-care illustration built with CustomPaint (no assets).
class SimplePetIllustration extends StatelessWidget {
  const SimplePetIllustration({super.key, required this.kind, this.size = 180});

  final PetIllustrationKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.85,
      child: CustomPaint(
        painter: _PetIllustrationPainter(kind: kind),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PetIllustrationPainter extends CustomPainter {
  _PetIllustrationPainter({required this.kind});

  final PetIllustrationKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final teal = AppColors.primary;
    final tealSoft = AppColors.primaryLight;
    final coral = AppColors.secondary;
    final cream = AppColors.primaryContainer;

    switch (kind) {
      case PetIllustrationKind.ownerWithPet:
        _paintOwnerWithPet(canvas, size, teal, tealSoft, coral, cream);
      case PetIllustrationKind.sitterWithPet:
        _paintSitterWithPet(canvas, size, teal, tealSoft, coral, cream);
      case PetIllustrationKind.ownerCare:
        _paintOwnerCare(canvas, size, teal, tealSoft, coral, cream);
    }
  }

  void _paintOwnerWithPet(
    Canvas canvas,
    Size size,
    Color teal,
    Color tealSoft,
    Color coral,
    Color cream,
  ) {
    final w = size.width;
    final h = size.height;

    // Soft ground oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.88),
        width: w * 0.72,
        height: h * 0.12,
      ),
      Paint()..color = cream.withValues(alpha: 0.85),
    );

    // Person (simple torso + head)
    final personPaint = Paint()..color = teal;
    canvas.drawCircle(Offset(w * 0.32, h * 0.28), w * 0.08, personPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.32, h * 0.52),
          width: w * 0.18,
          height: h * 0.32,
        ),
        Radius.circular(w * 0.06),
      ),
      personPaint,
    );
    // Kneeling leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.68, w * 0.22, h * 0.08),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = tealSoft,
    );

    // Dog body
    final petPaint = Paint()..color = coral.withValues(alpha: 0.9);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.62, h * 0.62),
        width: w * 0.34,
        height: h * 0.22,
      ),
      petPaint,
    );
    // Dog head
    canvas.drawCircle(Offset(w * 0.78, h * 0.48), w * 0.09, petPaint);
    // Ear
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.74, h * 0.38),
        width: w * 0.05,
        height: h * 0.1,
      ),
      Paint()..color = AppColors.secondaryDark,
    );
    // Tail
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.46, h * 0.55),
        width: w * 0.06,
        height: h * 0.12,
      ),
      petPaint,
    );
    // Small paw accent
    _drawPaw(canvas, Offset(w * 0.18, h * 0.18), w * 0.045, tealSoft);
  }

  void _paintSitterWithPet(
    Canvas canvas,
    Size size,
    Color teal,
    Color tealSoft,
    Color coral,
    Color cream,
  ) {
    final w = size.width;
    final h = size.height;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.9),
        width: w * 0.7,
        height: h * 0.1,
      ),
      Paint()..color = cream.withValues(alpha: 0.85),
    );

    // Standing person
    final personPaint = Paint()..color = teal;
    canvas.drawCircle(Offset(w * 0.38, h * 0.22), w * 0.075, personPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.38, h * 0.48),
          width: w * 0.16,
          height: h * 0.36,
        ),
        Radius.circular(w * 0.05),
      ),
      personPaint,
    );
    // Legs
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, h * 0.66, w * 0.055, h * 0.18),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = tealSoft,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.4, h * 0.66, w * 0.055, h * 0.18),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = tealSoft,
    );

    // Cat / small pet
    final petPaint = Paint()..color = coral.withValues(alpha: 0.92);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.68, h * 0.68),
        width: w * 0.22,
        height: h * 0.16,
      ),
      petPaint,
    );
    canvas.drawCircle(Offset(w * 0.78, h * 0.56), w * 0.07, petPaint);
    // Ears (triangles as paths)
    final ear = Path()
      ..moveTo(w * 0.72, h * 0.52)
      ..lineTo(w * 0.74, h * 0.4)
      ..lineTo(w * 0.78, h * 0.5)
      ..close();
    canvas.drawPath(ear, Paint()..color = AppColors.secondaryDark);
    final ear2 = Path()
      ..moveTo(w * 0.8, h * 0.5)
      ..lineTo(w * 0.84, h * 0.4)
      ..lineTo(w * 0.86, h * 0.52)
      ..close();
    canvas.drawPath(ear2, Paint()..color = AppColors.secondaryDark);

    // Walk / care symbols
    _drawSmallCircle(canvas, Offset(w * 0.18, h * 0.28), w * 0.04, tealSoft);
    _drawSmallCircle(canvas, Offset(w * 0.22, h * 0.4), w * 0.03, coral);
    _drawPaw(canvas, Offset(w * 0.82, h * 0.22), w * 0.04, teal);
  }

  void _paintOwnerCare(
    Canvas canvas,
    Size size,
    Color teal,
    Color tealSoft,
    Color coral,
    Color cream,
  ) {
    final w = size.width;
    final h = size.height;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.88),
        width: w * 0.68,
        height: h * 0.11,
      ),
      Paint()..color = cream.withValues(alpha: 0.85),
    );

    // Person
    final personPaint = Paint()..color = teal;
    canvas.drawCircle(Offset(w * 0.35, h * 0.26), w * 0.08, personPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.35, h * 0.5),
          width: w * 0.17,
          height: h * 0.34,
        ),
        Radius.circular(w * 0.05),
      ),
      personPaint,
    );

    // Dog
    final petPaint = Paint()..color = coral.withValues(alpha: 0.9);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.65, h * 0.62),
        width: w * 0.3,
        height: h * 0.2,
      ),
      petPaint,
    );
    canvas.drawCircle(Offset(w * 0.78, h * 0.48), w * 0.085, petPaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.74, h * 0.38),
        width: w * 0.045,
        height: h * 0.09,
      ),
      Paint()..color = AppColors.secondaryDark,
    );

    // Heart accent
    _drawHeart(canvas, Offset(w * 0.22, h * 0.2), w * 0.055, coral);
    _drawPaw(canvas, Offset(w * 0.85, h * 0.28), w * 0.04, tealSoft);
  }

  void _drawPaw(Canvas canvas, Offset center, double r, Color color) {
    final paint = Paint()..color = color;
    canvas.drawCircle(center, r * 0.7, paint);
    canvas.drawCircle(center + Offset(-r * 0.7, -r * 0.75), r * 0.35, paint);
    canvas.drawCircle(center + Offset(0, -r * 0.95), r * 0.35, paint);
    canvas.drawCircle(center + Offset(r * 0.7, -r * 0.75), r * 0.35, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.35)
      ..cubicTo(
        center.dx - size,
        center.dy - size * 0.15,
        center.dx - size * 0.55,
        center.dy - size,
        center.dx,
        center.dy - size * 0.45,
      )
      ..cubicTo(
        center.dx + size * 0.55,
        center.dy - size,
        center.dx + size,
        center.dy - size * 0.15,
        center.dx,
        center.dy + size * 0.35,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawSmallCircle(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant _PetIllustrationPainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}
