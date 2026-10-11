import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/aura_colors.dart';
import 'firebase_options.dart';
import 'prototype/prototype_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localStore = prototypeMode ? await loadPrototype() : null;
  if (!prototypeMode) await _initializeFirebase();

  // Light edge-to-edge canvas with readable dark system icons.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AuraColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    localStore == null
        ? const ProviderScope(child: AuraApp())
        : prototypeScope(localStore, const AuraApp()),
  );
}

/// Brings up Firebase before the first frame.
///
/// This is awaited deliberately: every repository behind the app assumes a live
/// [FirebaseApp], and letting the first frame render before that is true means
/// the splash screen would query auth state that does not exist yet.
///
/// The duplicate-app catch is not defensive noise. On hot restart the Dart VM
/// re-runs `main` while the native side keeps the app it already registered, so
/// a second [Firebase.initializeApp] throws `duplicate-app`. Rethrowing anything
/// else matters — a wrong API key or a missing `google-services.json` must fail
/// loudly rather than boot into an app whose every write silently fails.
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') rethrow;
  }
}
