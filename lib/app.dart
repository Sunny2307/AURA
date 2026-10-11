import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/aura_colors.dart';

import 'core/router/app_router.dart';
import 'core/theme/aura_theme.dart';

/// Root widget.
class AuraApp extends StatefulWidget {
  const AuraApp({super.key});

  @override
  State<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends State<AuraApp> {
  // Built once and held. Rebuilding a GoRouter loses navigation history.
  late final GoRouter _router = AppRouter.build();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aura',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AuraTheme.light,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return ColoredBox(
          color: AuraColors.background,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
