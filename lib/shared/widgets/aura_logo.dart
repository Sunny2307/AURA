import 'package:flutter/material.dart';

/// The approved Aura artwork, shared by every in-app brand surface.
class AuraLogo extends StatelessWidget {
  const AuraLogo({super.key, this.size = 40});

  static const assetPath = 'assets/branding/aura-logo.png';
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Aura logo',
    image: true,
    excludeSemantics: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}
