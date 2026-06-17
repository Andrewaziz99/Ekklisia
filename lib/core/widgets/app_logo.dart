// lib/core/widgets/app_logo.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reusable app-logo widget.
//
// Usage:
//   AppLogo(size: 120)                 // bare image, no container
//   AppLogo(size: 80, contained: true) // circular gold-border container
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../theme/brightness_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 80,
    this.contained = false,
  });

  /// Diameter of the logo image (and container, when [contained] is true).
  final double size;

  /// Wrap the image in a circular container with a gold border + glow.
  final bool contained;

  static const _asset = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gold       = Theme.of(context).primaryColor;
    final goldBorder = BrightnessColors.goldBorder(brightness);
    final bgDeep     = BrightnessColors.bgDeep(brightness);

    final image = Image.asset(
      _asset,
      width:  size,
      height: size,
      fit:    BoxFit.contain,
    );

    if (!contained) return image;

    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgDeep.withOpacity(0.6),
        border: Border.all(color: goldBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color:       gold.withOpacity(0.15),
            blurRadius:  24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipOval(child: image),
    );
  }
}
