import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../send/data/aura_api.dart';
import '../data/account_deletion_service.dart';
import '../data/safety_repository.dart';

/// Overridden with a fake in tests — the reason it is an interface.
final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return FirestoreSafetyRepository();
});

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return FirestoreAccountDeletionService(
    ref.watch(authRepositoryProvider),
    ref.watch(auraApiProvider),
  );
});

/// The uids you have blocked, newest first.
///
/// Emits an empty list when signed out rather than erroring — a signed-out
/// viewer has no block list in the only sense the settings screen cares about,
/// and treating it as a failure would flash an error on the way to onboarding.
final blockedUidsProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(safetyRepositoryProvider).watchBlocked(uid);
});
