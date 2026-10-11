import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_providers.dart';
import 'prototype_runtime.dart';

/// One revision stream for prototype consumers. Session changes also re-scope reads.
final localRevisionProvider = StreamProvider<int>((ref) {
  ref.watch(authStateProvider);
  if (!ref.watch(prototypeEnabledProvider)) return Stream.value(0);
  var revision = 0;
  return ref.watch(prototypeStoreProvider).watch(() => revision++);
});
