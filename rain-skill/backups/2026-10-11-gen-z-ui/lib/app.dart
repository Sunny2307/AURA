import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prototype/prototype_runtime.dart';

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
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aura',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AuraTheme.dark,
      // Dark only, deliberately — see AuraTheme. `darkTheme` is set to the same
      // value so nothing can fall through to a default light theme.
      darkTheme: AuraTheme.dark,
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        // Aura's numbers are large by design; letting the OS text scale run to
        // 2x breaks the score layout. Clamped rather than ignored, because
        // ignoring it entirely locks out anyone who needs bigger text.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: Consumer(
            builder: (context, ref, _) => ref.watch(prototypeEnabledProvider)
                ? Banner(
                    message: 'LOCAL DEMO',
                    location: BannerLocation.topEnd,
                    child: child ?? const SizedBox.shrink(),
                  )
                : child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
