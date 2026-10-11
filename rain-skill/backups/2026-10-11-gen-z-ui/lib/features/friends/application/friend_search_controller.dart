import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/public_profile.dart';
import '../../../core/validation/username_rules.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_repository.dart';
import 'friends_providers.dart';

/// Every state the find-a-friend screen can be in.
///
/// A sealed set rather than a bag of nullable fields, so the screen's `switch`
/// is exhaustive and a new state cannot be added without the UI being forced to
/// say what it looks like. The states that matter most are the three that are
/// easy to collapse into one and must not be: a handle that is *malformed*, a
/// handle that is *free*, and a lookup that *failed*. Showing "no such user" for
/// a dropped connection would send someone off to ask their friend to re-check
/// a handle that was correct all along.
sealed class FriendSearchState {
  const FriendSearchState();
}

final class FriendSearchIdle extends FriendSearchState {
  const FriendSearchIdle();
}

/// The handle cannot be valid, decided offline while typing. No read happens.
final class FriendSearchInvalid extends FriendSearchState {
  const FriendSearchInvalid(this.problem);

  final UsernameProblem problem;
}

final class FriendSearchBusy extends FriendSearchState {
  const FriendSearchBusy();
}

final class FriendSearchFound extends FriendSearchState {
  const FriendSearchFound(this.profile);

  final PublicProfile profile;
}

final class FriendSearchNotFound extends FriendSearchState {
  const FriendSearchNotFound(this.username);

  final String username;
}

/// You searched for your own handle. Its own state because "add yourself" is a
/// dead end the rules reject, and silently showing your own profile with an Add
/// button would be worse than saying so.
final class FriendSearchYourself extends FriendSearchState {
  const FriendSearchYourself();
}

final class FriendSearchFailed extends FriendSearchState {
  const FriendSearchFailed(this.problem);

  final AccountProblem problem;
}

final friendSearchControllerProvider =
    NotifierProvider<FriendSearchController, FriendSearchState>(
      FriendSearchController.new,
    );

final class FriendSearchController extends Notifier<FriendSearchState> {
  @override
  FriendSearchState build() => const FriendSearchIdle();

  /// Clears back to idle. Called when the field empties, so a stale "no such
  /// user" does not sit under a box the user has already started retyping.
  void clear() => state = const FriendSearchIdle();

  /// Looks up one exact handle.
  ///
  /// Shape is checked offline first, and a malformed handle never reaches
  /// Firestore. That is not only a cost saving: `usernames/{name}` is readable
  /// without auth by design, so every avoidable read of it is one less way to
  /// probe the collection.
  Future<void> search(String raw) async {
    final check = UsernameRules.check(raw);
    if (check case UsernameInvalid(:final problem)) {
      state = FriendSearchInvalid(problem);
      return;
    }

    final username = (check as UsernameValid).normalised;
    final myUid = ref.read(authStateProvider).value?.uid;

    state = const FriendSearchBusy();
    try {
      final profile = await ref
          .read(publicProfileRepositoryProvider)
          .findByUsername(username);

      if (profile == null) {
        state = FriendSearchNotFound(username);
        return;
      }
      // Checked against the uid rather than the typed handle, so it still holds
      // if someone's handle and their account ever diverge.
      if (profile.uid == myUid) {
        state = const FriendSearchYourself();
        return;
      }
      state = FriendSearchFound(profile);
    } on AccountFailure catch (failure) {
      state = FriendSearchFailed(failure.problem);
    }
  }
}
