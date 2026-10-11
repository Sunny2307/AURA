import 'dart:async';

import 'package:aura/core/models/aura_user.dart';
import 'package:aura/core/models/friendship.dart';
import 'package:aura/core/models/public_profile.dart';
import 'package:aura/features/auth/data/auth_repository.dart';
import 'package:aura/features/auth/data/user_repository.dart';
import 'package:aura/features/friends/data/friendship_repository.dart';
import 'package:aura/features/friends/data/public_profile_repository.dart';
import 'package:aura/features/safety/data/account_deletion_service.dart';
import 'package:aura/features/safety/data/safety_repository.dart';

/// In-memory stand-ins for the two repositories the signup flow writes through.
///
/// These exist because [AuthRepository] and [UserRepository] are interfaces, and
/// this file is the reason they are. A widget test that had to talk to Firebase
/// would need an emulator, a network, and a JDK, and would still be unable to
/// produce the interesting cases on demand — a handle taken by someone else half
/// a second ago, an email that already has an account, a dropped connection
/// mid-write. Those are the paths worth pinning down, so they are made cheap.
///
/// Deliberately not generated mocks. The behaviour under test is stateful — claim
/// a handle, then find it taken — and a call-verification mock expresses that
/// worse than twenty lines of a real, tiny implementation.
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({Set<String>? existingEmails, this.failWith})
    : _existingEmails = {...?existingEmails};

  final Set<String> _existingEmails;

  /// When set, every sign-up and sign-in throws this instead of succeeding. How
  /// the configuration-fault path ([AuthProblem.operationNotAllowed]) gets
  /// exercised without switching a provider off in a real Firebase console.
  AuthProblem? failWith;

  /// Broadcast, because both [authStateChanges] and the providers layered on it
  /// may listen. A single-subscription stream would throw on the second listen
  /// and the failure would look like a bug in the screen.
  final _authState = StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;

  /// Every uid handed out, in order. Lets a test assert that a second pass over
  /// the password step did *not* create a second account.
  final List<String> createdUids = [];

  int _nextUid = 1;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    // Starts with the current value, like Firebase does. A stream that only
    // emitted future changes would leave every listener null until something
    // happened, which is the opposite of what the splash screen needs.
    yield _currentUser;
    yield* _authState.stream;
  }

  @override
  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (failWith case final problem?) throw AuthFailure(problem);

    final normalised = email.trim().toLowerCase();
    if (_existingEmails.contains(normalised)) {
      throw const AuthFailure(AuthProblem.emailAlreadyInUse);
    }

    _existingEmails.add(normalised);
    final user = AuthUser(uid: 'uid-${_nextUid++}', email: normalised);
    createdUids.add(user.uid);
    _emit(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (failWith case final problem?) throw AuthFailure(problem);

    final normalised = email.trim().toLowerCase();
    if (!_existingEmails.contains(normalised)) {
      throw const AuthFailure(AuthProblem.wrongPassword);
    }
    final user = AuthUser(uid: 'uid-${_nextUid++}', email: normalised);
    _emit(user);
    return user;
  }

  @override
  Future<void> signOut() async => _emit(null);

  @override
  Future<void> deleteCurrentUser() async {
    if (_currentUser?.email case final email?) _existingEmails.remove(email);
    _emit(null);
  }

  /// Signs a user in without going through sign-up. For tests of the resumed
  /// signup path, where the auth account already exists before the screen builds.
  AuthUser signInDirectly({String uid = 'uid-existing'}) {
    final user = AuthUser(uid: uid, email: 'existing@example.com');
    _emit(user);
    return user;
  }

  void _emit(AuthUser? user) {
    _currentUser = user;
    if (!_authState.isClosed) _authState.add(user);
  }

  void dispose() => _authState.close();
}

final class FakeUserRepository implements UserRepository {
  FakeUserRepository({Set<String>? takenUsernames})
    : takenUsernames = {...?takenUsernames};

  /// Handles already claimed. Mutable so a test can simulate someone else
  /// claiming a name *between* the availability read and the transaction, which
  /// is the race the real repository's transaction exists to lose safely.
  final Set<String> takenUsernames;

  /// Thrown by [isUsernameAvailable] when set — the unreachable-network case, as
  /// distinct from a taken name. The UI must not conflate the two.
  AccountProblem? failAvailabilityWith;

  /// Thrown by [createAccount] when set.
  AccountProblem? failCreateWith;

  final Map<String, AuraUser> users = {};

  /// Public profiles published alongside each account. The real repository
  /// writes this in the same transaction as the user document, and the security
  /// rules reject a create that omits it — so a test that asserts signup
  /// succeeded should be able to assert this landed too.
  final Map<String, PublicProfile> publicProfiles = {};

  final _userStream = StreamController<AuraUser?>.broadcast();

  /// Usernames passed to [createAccount], in order. Asserts the *normalised*
  /// value reaches the write, not whatever was typed.
  final List<String> createAttempts = [];

  @override
  Future<bool> isUsernameAvailable(String username) async {
    if (failAvailabilityWith case final problem?) throw AccountFailure(problem);
    return !takenUsernames.contains(username);
  }

  @override
  Future<AuraUser> createAccount({
    required String uid,
    required String username,
    required int birthYear,
    required bool isMinor,
  }) async {
    createAttempts.add(username);

    if (failCreateWith case final problem?) throw AccountFailure(problem);
    if (takenUsernames.contains(username)) {
      throw const AccountFailure(AccountProblem.usernameTaken);
    }
    if (users.containsKey(uid)) {
      throw const AccountFailure(AccountProblem.accountAlreadyExists);
    }

    final user = AuraUser.newAccount(
      uid: uid,
      username: username,
      birthYear: birthYear,
      isMinor: isMinor,
      // Fixed rather than `DateTime.now()`, so nothing that renders this can
      // become time-dependent.
      createdAt: DateTime.utc(2026, 1, 1),
    );

    takenUsernames.add(username);
    users[uid] = user;
    publicProfiles[uid] = PublicProfile(
      uid: uid,
      username: username,
      photoUrl: user.photoUrl,
    );
    if (!_userStream.isClosed) _userStream.add(user);
    return user;
  }

  @override
  Stream<AuraUser?> watchUser(String uid) async* {
    yield users[uid];
    yield* _userStream.stream.map((_) => users[uid]);
  }

  @override
  Future<AuraUser?> fetchUser(String uid) async => users[uid];

  @override
  Future<void> updatePrivacy({
    required String uid,
    required AuraPrivacy privacy,
  }) async {
    final existing = users[uid];
    if (existing == null) {
      throw const AccountFailure(AccountProblem.unknown);
    }
    // Mirrors the security rule rather than trusting the caller: a minor can
    // never switch leaderboards on. A fake that allowed it would let a settings
    // test pass against behaviour the backend rejects.
    if (existing.isMinor && privacy.appearOnLeaderboards) {
      throw const AccountFailure(AccountProblem.permissionDenied);
    }
    users[uid] = existing.copyWith(privacy: privacy);
    if (!_userStream.isClosed) _userStream.add(users[uid]);
  }

  void dispose() => _userStream.close();
}

/// In-memory blocks and reports.
///
/// One fake for both, matching the real [SafetyRepository] — the security rules
/// require a report and its block to commit together, so modelling them apart
/// here would let a test pass against something the backend refuses.
final class FakeSafetyRepository implements SafetyRepository {
  FakeSafetyRepository({this.friendships});

  /// Optional. When given, blocking also severs the friendship, exactly as the
  /// real repository's single batch does — so a test can assert that blocking
  /// someone actually removes them from the friend list.
  final FakeFriendshipRepository? friendships;

  /// Blocker uid -> the uids they have blocked, newest last.
  final Map<String, List<String>> blocked = {};

  /// Every report filed, as `'<reporter>:<reported>:<reason>'`.
  final List<String> reports = [];

  /// Thrown by every action when set.
  SafetyProblem? failWith;

  final _changes = StreamController<void>.broadcast();

  @override
  Future<void> block({
    required String viewerUid,
    required String blockedUid,
  }) async {
    if (viewerUid == blockedUid) {
      throw const SafetyFailure(SafetyProblem.cannotActOnYourself);
    }
    if (failWith case final problem?) throw SafetyFailure(problem);
    _applyBlock(viewerUid, blockedUid);
  }

  @override
  Future<void> unblock({
    required String viewerUid,
    required String blockedUid,
  }) async {
    if (failWith case final problem?) throw SafetyFailure(problem);
    blocked[viewerUid]?.remove(blockedUid);
    _emit();
  }

  @override
  Future<void> report({
    required String viewerUid,
    required String reportedUid,
    required String reason,
  }) async {
    if (viewerUid == reportedUid) {
      throw const SafetyFailure(SafetyProblem.cannotActOnYourself);
    }
    if (failWith case final problem?) throw SafetyFailure(problem);
    reports.add('$viewerUid:$reportedUid:$reason');
    // Always, never optionally. The rules reject a report whose block is not in
    // the same commit.
    _applyBlock(viewerUid, reportedUid);
  }

  @override
  Stream<List<String>> watchBlocked(String viewerUid) async* {
    List<String> current() =>
        List.unmodifiable((blocked[viewerUid] ?? const []).reversed);
    yield current();
    yield* _changes.stream.map((_) => current());
  }

  bool hasBlocked(String viewerUid, String blockedUid) =>
      blocked[viewerUid]?.contains(blockedUid) ?? false;

  void _applyBlock(String viewerUid, String blockedUid) {
    final list = blocked.putIfAbsent(viewerUid, () => []);
    if (!list.contains(blockedUid)) list.add(blockedUid);
    friendships?.byPairId.remove(
      Friendship.pairIdFor(viewerUid, blockedUid),
    );
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() => _changes.close();
}

/// In-memory `publicProfiles/{uid}`.
///
/// Seeded directly rather than through a signup, because the screens under test
/// care about *finding* people who already exist, not about how they got there.
final class FakePublicProfileRepository implements PublicProfileRepository {
  FakePublicProfileRepository({Iterable<PublicProfile>? profiles}) {
    for (final profile in profiles ?? const <PublicProfile>[]) {
      add(profile);
    }
  }

  final Map<String, PublicProfile> byUid = {};
  final _changes = StreamController<void>.broadcast();

  /// Thrown by every read when set — the unreachable-network case, which a
  /// search screen must tell apart from "no such handle".
  AccountProblem? failWith;

  /// Handles passed to [findByUsername], in order. Lets a test assert the
  /// normalised handle reached the read, and that a malformed one never did.
  final List<String> lookups = [];

  void add(PublicProfile profile) {
    byUid[profile.uid] = profile;
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<PublicProfile?> findByUsername(String username) async {
    lookups.add(username);
    if (failWith case final problem?) throw AccountFailure(problem);
    for (final profile in byUid.values) {
      if (profile.username == username) return profile;
    }
    return null;
  }

  @override
  Future<PublicProfile?> fetch(String uid) async {
    if (failWith case final problem?) throw AccountFailure(problem);
    return byUid[uid];
  }

  @override
  Stream<PublicProfile?> watch(String uid) async* {
    yield byUid[uid];
    yield* _changes.stream.map((_) => byUid[uid]);
  }

  void dispose() => _changes.close();
}

/// In-memory `friendships/{pairId}`.
///
/// Keyed by the same derived pair id the real repository and the security rules
/// use, so a test that gets the ordering wrong fails here rather than passing
/// against a fake that is more forgiving than the backend.
final class FakeFriendshipRepository implements FriendshipRepository {
  final Map<String, Friendship> byPairId = {};
  final _changes = StreamController<void>.broadcast();

  /// Thrown by [request] when set.
  FriendshipProblem? failRequestWith;

  /// Thrown by [accept] when set.
  FriendshipProblem? failAcceptWith;

  /// Every write, in order, as `'<verb>:<pairId>'`. Lets a test assert that
  /// tapping Accept twice only wrote once.
  final List<String> writes = [];

  int _clock = 0;

  /// Puts a friendship in place without going through request/accept.
  void seed({
    required String from,
    required String to,
    FriendshipStatus status = FriendshipStatus.pending,
  }) {
    final id = Friendship.pairIdFor(from, to);
    byPairId[id] = Friendship(
      id: id,
      members: [from, to]..sort(),
      requestedBy: from,
      status: status,
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: _clock++)),
      respondedAt: status == FriendshipStatus.accepted
          ? DateTime.utc(2026, 1, 2)
          : null,
    );
    _emit();
  }

  @override
  Future<void> request({
    required String fromUid,
    required String toUid,
  }) async {
    if (fromUid == toUid) {
      throw const FriendshipFailure(FriendshipProblem.cannotBefriendYourself);
    }
    if (failRequestWith case final problem?) throw FriendshipFailure(problem);

    final id = Friendship.pairIdFor(fromUid, toUid);
    writes.add('request:$id');
    if (byPairId.containsKey(id)) {
      throw const FriendshipFailure(FriendshipProblem.alreadyExists);
    }
    seed(from: fromUid, to: toUid);
  }

  @override
  Future<void> accept({
    required String viewerUid,
    required String otherUid,
  }) async {
    if (failAcceptWith case final problem?) throw FriendshipFailure(problem);

    final id = Friendship.pairIdFor(viewerUid, otherUid);
    writes.add('accept:$id');
    final existing = byPairId[id];
    if (existing == null) {
      throw const FriendshipFailure(FriendshipProblem.noLongerExists);
    }
    // Mirrors the security rule. A fake that let the sender accept would make
    // the consent model untested exactly where it matters.
    if (existing.requestedBy == viewerUid) {
      throw const FriendshipFailure(FriendshipProblem.notYoursToAccept);
    }

    byPairId[id] = Friendship(
      id: id,
      members: existing.members,
      requestedBy: existing.requestedBy,
      status: FriendshipStatus.accepted,
      createdAt: existing.createdAt,
      respondedAt: DateTime.utc(2026, 1, 2),
    );
    _emit();
  }

  @override
  Future<void> remove({
    required String viewerUid,
    required String otherUid,
  }) async {
    final id = Friendship.pairIdFor(viewerUid, otherUid);
    writes.add('remove:$id');
    byPairId.remove(id);
    _emit();
  }

  @override
  Stream<List<Friendship>> watchFriends(String viewerUid) {
    return _watch(viewerUid, FriendshipStatus.accepted);
  }

  @override
  Stream<List<Friendship>> watchPending(String viewerUid) {
    return _watch(viewerUid, FriendshipStatus.pending);
  }

  @override
  Stream<Friendship?> watchWith({
    required String viewerUid,
    required String otherUid,
  }) async* {
    final id = Friendship.pairIdFor(viewerUid, otherUid);
    yield byPairId[id];
    yield* _changes.stream.map((_) => byPairId[id]);
  }

  Stream<List<Friendship>> _watch(String viewerUid, FriendshipStatus status) {
    List<Friendship> current() {
      final matches =
          byPairId.values
              .where((f) => f.involves(viewerUid) && f.status == status)
              .toList()
            // Newest first, matching the Firestore query's orderBy.
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List.unmodifiable(matches);
    }

    return () async* {
      yield current();
      yield* _changes.stream.map((_) => current());
    }();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() => _changes.close();
}

/// In-memory account deletion.
///
/// Records what it was asked to delete rather than simulating the real
/// multi-batch unwind — the ordering and atomicity of that unwind is the
/// *rules'* business and is covered by the emulator suite. What a widget test
/// needs to know is whether the screen called it exactly once, with the right
/// uid, and routed afterwards.
final class FakeAccountDeletionService implements AccountDeletionService {
  FakeAccountDeletionService({this.auth, this.users});

  /// Optional. When given, deletion clears the account from both, so a test can
  /// assert the app lands somewhere sensible with no user left.
  final FakeAuthRepository? auth;
  final FakeUserRepository? users;

  /// Every uid passed to [deleteAccount], in order. Length is the assertion
  /// that matters: a double tap must not delete twice.
  final List<String> deleted = [];

  SafetyProblem? failWith;

  @override
  Future<void> deleteAccount(String uid) async {
    deleted.add(uid);
    if (failWith case final problem?) throw SafetyFailure(problem);
    users?.users.remove(uid);
    users?.publicProfiles.remove(uid);
    await auth?.deleteCurrentUser();
  }
}
