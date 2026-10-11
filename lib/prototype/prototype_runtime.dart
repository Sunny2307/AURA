import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/aura_user.dart';
import '../core/models/friendship.dart';
import '../core/models/public_profile.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/user_repository.dart';
import '../features/friends/application/friends_providers.dart';
import '../features/friends/data/friendship_repository.dart';
import '../features/friends/data/public_profile_repository.dart';
import '../features/safety/application/safety_providers.dart';
import '../features/safety/data/safety_repository.dart';
import '../features/safety/data/account_deletion_service.dart';
import '../features/send/data/aura_api.dart';
import '../features/profile/data/photo_repository.dart';
import 'prototype_store.dart';

const prototypeMode = bool.fromEnvironment(
  'AURA_PROTOTYPE',
  defaultValue: true,
);
final prototypeEnabledProvider = Provider<bool>((ref) => false);
final prototypeStoreProvider = Provider<PrototypeStore>(
  (ref) => throw StateError('Prototype store must be supplied at startup'),
);

Future<PrototypeStore> loadPrototype() async {
  final prefs = SharedPreferencesAsync();
  return PrototypeStore(
    restored: await prefs.getString('aura.prototype.v1'),
    save: (data) => prefs.setString('aura.prototype.v1', data),
  );
}

Widget prototypeScope(PrototypeStore store, Widget child) => ProviderScope(
  overrides: [
    prototypeEnabledProvider.overrideWithValue(true),
    prototypeStoreProvider.overrideWithValue(store),
    authRepositoryProvider.overrideWithValue(LocalAuth(store)),
    userRepositoryProvider.overrideWithValue(LocalUsers(store)),
    publicProfileRepositoryProvider.overrideWithValue(LocalProfiles(store)),
    friendshipRepositoryProvider.overrideWithValue(LocalFriends(store)),
    safetyRepositoryProvider.overrideWithValue(LocalSafety(store)),
    accountDeletionServiceProvider.overrideWithValue(LocalDeletion(store)),
    auraApiProvider.overrideWithValue(LocalAura(store)),
  ],
  child: child,
);

Future<T> _guard<T>(
  Future<T> Function() action,
  Exception Function(String) error,
) async {
  try {
    return await action();
  } on PrototypeFailure catch (failure) {
    throw error(failure.code);
  } on IOException {
    throw error('network');
  }
}

T _enum<T extends Enum>(List<T> values, String code, T fallback) =>
    values.where((v) => v.name == code).firstOrNull ?? fallback;

class LocalAuth implements AuthRepository {
  LocalAuth(this.store);
  final PrototypeStore store;
  @override
  AuthUser? get currentUser => store.currentUid == null
      ? null
      : AuthUser(
          uid: store.currentUid!,
          email: store.emailFor(store.currentUid!),
        );
  @override
  Stream<AuthUser?> authStateChanges() =>
      store.watch(() => currentUser).distinct();
  @override
  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
  }) => _guard(
    () async {
      if (password.length < 8) {
        throw const PrototypeFailure(
          'weakPassword',
          'choose a longer demo password.',
        );
      }
      final uid = await store.signUp(email);
      return AuthUser(uid: uid, email: store.emailFor(uid));
    },
    (code) => AuthFailure(_enum(AuthProblem.values, code, AuthProblem.unknown)),
  );
  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(
    () async {
      final account = store.accounts
          .where((a) => store.emailFor(a.uid) == email.trim().toLowerCase())
          .firstOrNull;
      if (account == null) {
        throw const PrototypeFailure('userNotFound', 'demo account not found.');
      }
      await store.resume(account.uid);
      return currentUser!;
    },
    (code) => AuthFailure(_enum(AuthProblem.values, code, AuthProblem.unknown)),
  );
  @override
  Future<void> signOut() => store.signOut();
  @override
  Future<void> deleteCurrentUser() async {
    if (store.currentUid != null) await store.deleteAccount(store.currentUid!);
  }
}

class LocalUsers implements UserRepository {
  LocalUsers(this.store);
  final PrototypeStore store;
  Exception _error(String code) => AccountFailure(
    _enum(AccountProblem.values, code, AccountProblem.unknown),
  );
  @override
  Future<bool> isUsernameAvailable(String username) async =>
      store.available(username);
  @override
  Future<AuraUser> createAccount({
    required String uid,
    required String username,
    required int birthYear,
    required bool isMinor,
  }) => _guard(
    () => store.createAccount(uid, username, birthYear, isMinor),
    _error,
  );
  @override
  Stream<AuraUser?> watchUser(String uid) => store.watch(() => store.user(uid));
  @override
  Future<AuraUser?> fetchUser(String uid) async => store.user(uid);
  @override
  Future<void> updatePrivacy({
    required String uid,
    required AuraPrivacy privacy,
  }) => _guard(() => store.privacy(uid, privacy), _error);
}

class LocalProfiles implements PublicProfileRepository {
  LocalProfiles(this.store);
  final PrototypeStore store;
  @override
  Future<PublicProfile?> findByUsername(String username) async =>
      store.find(username);
  @override
  Future<PublicProfile?> fetch(String uid) async => store.profile(uid);
  @override
  Stream<PublicProfile?> watch(String uid) =>
      store.watch(() => store.profile(uid));
}

class LocalFriends implements FriendshipRepository {
  LocalFriends(this.store);
  final PrototypeStore store;
  Exception _error(String code) => FriendshipFailure(
    _enum(FriendshipProblem.values, code, FriendshipProblem.unknown),
  );
  @override
  Future<void> request({required String fromUid, required String toUid}) =>
      _guard(() => store.request(fromUid, toUid), _error);
  @override
  Future<void> accept({required String viewerUid, required String otherUid}) =>
      _guard(() => store.accept(viewerUid, otherUid), _error);
  @override
  Future<void> remove({required String viewerUid, required String otherUid}) =>
      _guard(() => store.remove(viewerUid, otherUid), _error);
  @override
  Stream<List<Friendship>> watchFriends(String viewerUid) =>
      store.watch(() => store.friends(viewerUid, FriendshipStatus.accepted));
  @override
  Stream<List<Friendship>> watchPending(String viewerUid) =>
      store.watch(() => store.friends(viewerUid, FriendshipStatus.pending));
  @override
  Stream<Friendship?> watchWith({
    required String viewerUid,
    required String otherUid,
  }) => store.watch(() => store.friendship(viewerUid, otherUid));
}

class LocalSafety implements SafetyRepository {
  LocalSafety(this.store);
  final PrototypeStore store;
  Exception _error(String code) =>
      SafetyFailure(_enum(SafetyProblem.values, code, SafetyProblem.unknown));
  @override
  Future<void> block({required String viewerUid, required String blockedUid}) =>
      _guard(() => store.block(viewerUid, blockedUid), _error);
  @override
  Future<void> unblock({
    required String viewerUid,
    required String blockedUid,
  }) => _guard(() => store.unblock(viewerUid, blockedUid), _error);
  @override
  Future<void> report({
    required String viewerUid,
    required String reportedUid,
    required String reason,
  }) => _guard(() => store.report(viewerUid, reportedUid, reason), _error);
  @override
  Stream<List<String>> watchBlocked(String viewerUid) =>
      store.watch(() => store.blocked(viewerUid));
}

class LocalAura implements AuraApi {
  LocalAura(this.store);
  final PrototypeStore store;
  @override
  Future<void> send({
    required String recipientUid,
    required int points,
    required String reason,
    required String visibility,
    required String idempotencyKey,
    String? chipId,
  }) async {
    try {
      await store.send(
        recipient: recipientUid,
        points: points,
        reason: reason,
        visibility: visibility,
        key: idempotencyKey,
        chip: chipId,
      );
    } on PrototypeFailure catch (e) {
      throw AuraApiFailure(e.message, code: e.code);
    }
  }

  @override
  Future<void> purgeForDeletion() async {
    final uid = store.currentUid;
    if (uid != null) await store.purge(uid);
  }
}

class LocalDeletion implements AccountDeletionService {
  LocalDeletion(this.store);
  final PrototypeStore store;
  @override
  Future<void> deleteAccount(String uid) => _guard(
    () async {
      final photo = store.user(uid)?.photoUrl;
      await store.deleteAccount(uid);
      await _removeLocalPhoto(photo);
    },
    (code) =>
        SafetyFailure(_enum(SafetyProblem.values, code, SafetyProblem.unknown)),
  );
}

class LocalPhotos implements PhotoRepository {
  LocalPhotos(this.store);
  final PrototypeStore store;
  @override
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    store.requireSelf(uid);
    final previous = store.user(uid)?.photoUrl;
    if (bytes.isEmpty ||
        bytes.length > 5 * 1024 * 1024 ||
        !contentType.startsWith('image/')) {
      throw const PrototypeFailure(
        'invalid-photo',
        'choose an image smaller than 5 MB.',
      );
    }
    final directory = await getApplicationDocumentsDirectory();
    final photos = Directory('${directory.path}/aura-prototype-photos');
    await photos.create(recursive: true);
    final file = File(
      '${photos.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    final uri = file.uri.toString();
    try {
      await store.photo(uid, uri);
    } catch (_) {
      await file.delete();
      rethrow;
    }
    await _removeLocalPhoto(previous);
    return uri;
  }

  @override
  Future<void> deleteProfilePhoto(String uid) async {
    final previous = store.user(uid)?.photoUrl;
    await store.photo(uid, null);
    await _removeLocalPhoto(previous);
  }
}

Future<void> _removeLocalPhoto(String? url) async {
  if (url == null || Uri.tryParse(url)?.scheme != 'file') return;
  try {
    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory('${docs.path}/aura-prototype-photos');
    if (!directory.existsSync()) return;
    final file = File.fromUri(Uri.parse(url));
    if (!file.existsSync()) return;
    final root = await directory.resolveSymbolicLinks();
    final target = await file.resolveSymbolicLinks();
    if (target.startsWith('$root${Platform.pathSeparator}')) {
      await file.delete();
    }
  } on IOException {
    // State has already been committed. A stale local image must not turn a
    // successful deletion into a misleading failed-account message.
  }
}

Future<void> resetPrototype(PrototypeStore store) async {
  final photos = store.accounts
      .map((a) => a.photoUrl)
      .whereType<String>()
      .toList();
  await store.reset();
  for (final photo in photos) {
    await _removeLocalPhoto(photo);
  }
}
