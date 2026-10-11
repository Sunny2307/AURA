import 'dart:async';
import 'dart:convert';

import '../core/models/aura_user.dart';
import '../core/models/friendship.dart';
import '../core/models/public_profile.dart';
import '../core/rules/aura_rules.dart';
import '../core/validation/username_rules.dart';
import '../core/models/report_reason.dart';

class PrototypeFailure implements Exception {
  const PrototypeFailure(this.code, this.message);
  final String code;
  final String message;
}

/// Device-only state. Save completes before observers see a successful action.
class PrototypeStore {
  PrototypeStore({required this.save, String? restored}) {
    _data = restored == null ? _empty() : _decode(restored);
    if (restored == null) _seedPeople();
  }

  final Future<void> Function(String value) save;
  late Map<String, dynamic> _data;
  final _changes = StreamController<void>.broadcast(sync: true);
  Future<void> _pending = Future.value();
  static const demoUid = 'demo';
  static const demoPeople = ['sam', 'maya', 'alex', 'jordan'];

  static Map<String, dynamic> _empty() => {
    'version': 1,
    'session': null,
    'emails': <String, dynamic>{},
    'users': <String, dynamic>{},
    'claims': <String, dynamic>{},
    'friends': <String, dynamic>{},
    'blocks': <String, dynamic>{},
    'reports': <dynamic>[],
    'sends': <String, dynamic>{},
  };

  static Map<String, dynamic> _decode(String value) {
    final data = jsonDecode(value) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unknown prototype version');
    }
    for (final key in [
      'emails',
      'users',
      'claims',
      'friends',
      'blocks',
      'sends',
    ]) {
      if (data[key] is! Map<String, dynamic>) {
        throw FormatException('Invalid $key');
      }
    }
    if (data['reports'] is! List ||
        (data['session'] != null && data['session'] is! String)) {
      throw const FormatException('Invalid prototype state');
    }
    return data;
  }

  Map<String, dynamic> _map(String key) => _data[key] as Map<String, dynamic>;
  String? get currentUid => _data['session'] as String?;
  String? emailFor(String uid) {
    for (final entry in _map('emails').entries) {
      if (entry.value == uid) return entry.key;
    }
    return null;
  }

  List<AuraUser> get accounts =>
      _map('emails').values
          .cast<String>()
          .map(user)
          .whereType<AuraUser>()
          .toList();

  AuraUser? user(String uid) {
    final map = _map('users')[uid];
    return map == null
        ? null
        : AuraUser.fromMap(
            uid,
            map as Map<String, dynamic>,
            parseTimestamp: (v) => DateTime.parse(v as String),
          );
  }

  PublicProfile? profile(String uid) {
    final account = user(uid);
    return account == null
        ? null
        : PublicProfile(
            uid: uid,
            username: account.username,
            photoUrl: account.photoUrl,
          );
  }

  PublicProfile? find(String name) =>
      profile(_map('claims')[name] as String? ?? '');
  bool available(String name) => !_map('claims').containsKey(name);
  List<Map<String, dynamic>> get history =>
      _map('sends').values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where(
            (v) => v['sender'] == currentUid || v['recipient'] == currentUid,
          )
          .toList()
        ..sort((a, b) => (b['at'] as String).compareTo(a['at'] as String));

  Stream<T> watch<T>(T Function() read) => Stream<T>.multi((out) {
    final subscription = _changes.stream.listen(
      (_) => out.add(read()),
      onError: out.addError,
    );
    out.add(read());
    out.onCancel = subscription.cancel;
  });

  Future<T> _mutate<T>(T Function() change) {
    final completer = Completer<T>();
    _pending = _pending.then((_) async {
      final before = jsonEncode(_data);
      try {
        final result = change();
        await save(jsonEncode(_data));
        _changes.add(null);
        completer.complete(result);
      } catch (error, stack) {
        _data = _decode(before);
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  void _put(AuraUser account) => _map('users')[account.uid] = {
    ...account.toCreateMap(),
    'createdAt': account.createdAt.toIso8601String(),
  };

  void _seedPeople() {
    for (final name in demoPeople) {
      final uid = 'sample-$name';
      if (user(uid) != null) continue;
      _put(
        AuraUser.newAccount(
          uid: uid,
          username: name,
          birthYear: 2000,
          isMinor: false,
          createdAt: DateTime(2026, 1),
        ),
      );
      _map('claims')[name] = uid;
      _map('emails')['$name@example.test'] = uid;
    }
  }

  void _seedFriends(String uid) {
    for (final name in ['sam', 'maya', 'alex']) {
      final other = 'sample-$name';
      if (user(other) == null) continue;
      final id = Friendship.pairIdFor(uid, other);
      final accepted = name != 'alex';
      _map('friends')[id] = {
        'members': [uid, other]..sort(),
        'requestedBy': other,
        'status': accepted ? 'accepted' : 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'respondedAt': accepted ? DateTime.now().toIso8601String() : null,
      };
    }
  }

  Future<String> signUp(String email) => _mutate(() {
    final normal = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normal)) {
      throw const PrototypeFailure('invalidEmail', 'enter an email address.');
    }
    if (_map('emails').containsKey(normal)) {
      throw const PrototypeFailure(
        'emailAlreadyInUse',
        'that demo account already exists.',
      );
    }
    final uid = 'local-${DateTime.now().microsecondsSinceEpoch}';
    _map('emails')[normal] = uid;
    _data['session'] = uid;
    return uid;
  });

  Future<void> resume(String uid) => _mutate(() {
    if (!_map('emails').containsValue(uid) || user(uid) == null) {
      throw const PrototypeFailure(
        'userNotFound',
        'that demo account no longer exists.',
      );
    }
    _data['session'] = uid;
  });

  Future<void> signOut() => _mutate(() {
    _data['session'] = null;
  });

  Future<void> openDemo() => _mutate(() {
    var uid = _data['demoAccount'] as String? ?? demoUid;
    if (user(uid) == null) {
      if (_map('claims').containsValue(uid)) {
        uid = 'demo-${DateTime.now().microsecondsSinceEpoch}';
      }
      var name = 'aura_demo';
      var suffix = 2;
      while (!available(name)) {
        name = 'aura_demo_${suffix++}';
      }
      _put(
        AuraUser.newAccount(
          uid: uid,
          username: name,
          birthYear: 2000,
          isMinor: false,
          createdAt: DateTime.now(),
        ),
      );
      _map('claims')[name] = uid;
      _map('emails')['$uid@example.test'] = uid;
      _seedFriends(uid);
    }
    _data['demoAccount'] = uid;
    _data['session'] = uid;
  });

  Future<void> reset() => _mutate(() {
    _data = _empty();
    _seedPeople();
  });

  void requireSelf(String uid) {
    if (currentUid == null || currentUid != uid) {
      throw const PrototypeFailure('permissionDenied', 'sign in again.');
    }
  }

  Future<AuraUser> createAccount(
    String uid,
    String name,
    int year,
    bool minor,
  ) => _mutate(() {
    requireSelf(uid);
    if (user(uid) != null) {
      throw const PrototypeFailure(
        'accountAlreadyExists',
        'account already exists.',
      );
    }
    final checked = UsernameRules.check(name);
    if (checked is! UsernameValid || !available(checked.normalised)) {
      throw const PrototypeFailure('usernameTaken', 'choose another username.');
    }
    final age = evaluateAgeGate(birthYear: year, today: DateTime.now());
    if (!age.canCreateAccount || age.isMinor != minor) {
      throw const PrototypeFailure(
        'permissionDenied',
        'check your birth year.',
      );
    }
    final account = AuraUser.newAccount(
      uid: uid,
      username: checked.normalised,
      birthYear: year,
      isMinor: minor,
      createdAt: DateTime.now(),
    );
    _put(account);
    _map('claims')[checked.normalised] = uid;
    _seedFriends(uid);
    return account;
  });

  Future<void> privacy(String uid, AuraPrivacy value) => _mutate(() {
    requireSelf(uid);
    final account = user(uid);
    if (account == null || (account.isMinor && value.appearOnLeaderboards)) {
      throw const PrototypeFailure(
        'permissionDenied',
        'that change is not allowed.',
      );
    }
    _put(account.copyWith(privacy: value));
  });

  Future<void> photo(String uid, String? path) => _mutate(() {
    requireSelf(uid);
    final account = user(uid);
    if (account == null) {
      throw const PrototypeFailure('permissionDenied', 'account missing.');
    }
    final map = _map('users')[uid] as Map<String, dynamic>;
    map['photoUrl'] = path;
  });

  Friendship? friendship(String a, String b) {
    final id = Friendship.pairIdFor(a, b);
    final value = _map('friends')[id];
    return value == null
        ? null
        : Friendship.fromMap(
            id,
            value as Map<String, dynamic>,
            parseTimestamp: (v) => DateTime.parse(v as String),
          );
  }

  List<Friendship> friends(String uid, FriendshipStatus status) =>
      _map('friends').entries
          .map(
            (e) => Friendship.fromMap(
              e.key,
              e.value as Map<String, dynamic>,
              parseTimestamp: (v) => DateTime.parse(v as String),
            ),
          )
          .where((f) => f.involves(uid) && f.status == status)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<String> blocked(String uid) =>
      (_map('blocks')[uid] as List? ?? []).cast<String>();
  bool _blockedPair(String a, String b) =>
      blocked(a).contains(b) || blocked(b).contains(a);

  Future<void> request(String from, String to) => _mutate(() {
    requireSelf(from);
    if (from == to) {
      throw const PrototypeFailure(
        'cannotBefriendYourself',
        'choose someone else.',
      );
    }
    if (user(from) == null ||
        user(to) == null ||
        _blockedPair(from, to) ||
        user(to)!.privacy.whoCanSendAura == WhoCanSendAura.nobody) {
      throw const PrototypeFailure(
        'permissionDenied',
        'that request is not allowed.',
      );
    }
    if (friendship(from, to) != null) {
      throw const PrototypeFailure('alreadyExists', 'request already exists.');
    }
    _map('friends')[Friendship.pairIdFor(from, to)] = {
      'members': [from, to]..sort(),
      'requestedBy': from,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'respondedAt': null,
    };
  });

  Future<void> accept(String viewer, String other) => _mutate(() {
    requireSelf(viewer);
    final f = friendship(viewer, other);
    if (f == null) {
      throw const PrototypeFailure('noLongerExists', 'request is gone.');
    }
    if (!f.isIncomingFor(viewer)) {
      throw const PrototypeFailure(
        'notYoursToAccept',
        'only the recipient can accept.',
      );
    }
    if (_blockedPair(viewer, other)) {
      throw const PrototypeFailure('permissionDenied', 'account is blocked.');
    }
    final map = _map('friends')[f.id] as Map<String, dynamic>;
    map['status'] = 'accepted';
    map['respondedAt'] = DateTime.now().toIso8601String();
  });

  Future<void> remove(String viewer, String other) => _mutate(() {
    requireSelf(viewer);
    _map('friends').remove(Friendship.pairIdFor(viewer, other));
  });

  void _block(String viewer, String other) {
    requireSelf(viewer);
    if (viewer == other) {
      throw const PrototypeFailure(
        'cannotActOnYourself',
        'choose someone else.',
      );
    }
    final list = blocked(viewer).toList()
      ..remove(other)
      ..insert(0, other);
    _map('blocks')[viewer] = list;
    _map('friends').remove(Friendship.pairIdFor(viewer, other));
  }

  Future<void> block(String viewer, String other) =>
      _mutate(() => _block(viewer, other));
  Future<void> unblock(String viewer, String other) => _mutate(() {
    requireSelf(viewer);
    _map('blocks')[viewer] = blocked(viewer).toList()..remove(other);
  });
  Future<void> report(String viewer, String other, String reason) =>
      _mutate(() {
        if (!ReportReason.values.any((v) => v.wireValue == reason)) {
          throw const PrototypeFailure(
            'permissionDenied',
            'choose a report reason.',
          );
        }
        _block(viewer, other);
        (_data['reports'] as List).add({
          'viewer': viewer,
          'reported': other,
          'reason': reason,
        });
      });

  Future<void> send({
    required String recipient,
    required int points,
    required String reason,
    required String visibility,
    required String key,
    String? chip,
  }) => _mutate(() {
    final sender = currentUid;
    final account = sender == null ? null : user(sender);
    final target = user(recipient);
    if (account == null || target == null) {
      throw const PrototypeFailure('permissionDenied', 'sign in again.');
    }
    final recordKey = '${sender}_$key';
    final payload = {
      'sender': sender,
      'recipient': recipient,
      'points': points,
      'reason': reason.trim(),
      'visibility': visibility,
      'chip': chip,
    };
    final existing = _map('sends')[recordKey] as Map<String, dynamic>?;
    if (existing != null) {
      for (final entry in payload.entries) {
        if (existing[entry.key] != entry.value) {
          throw const PrototypeFailure(
            'idempotency-conflict',
            'retry with unchanged details.',
          );
        }
      }
      return;
    }
    if (!account.pointCaps.allows(points) ||
        reason.trim().isEmpty ||
        reason.trim().runes.length > AuraRules.maxCustomReasonLength ||
        !['private', 'friends'].contains(visibility) ||
        key.isEmpty) {
      throw const PrototypeFailure(
        'invalid-send',
        'check your points and reason.',
      );
    }
    if (sender == recipient ||
        _blockedPair(sender!, recipient) ||
        friendship(sender, recipient)?.status != FriendshipStatus.accepted ||
        target.privacy.whoCanSendAura == WhoCanSendAura.nobody) {
      throw const PrototypeFailure(
        'permissionDenied',
        'you cannot send aura to this person.',
      );
    }
    if (points < 0) {
      final since = DateTime.now().subtract(AuraRules.negativeRateLimitWindow);
      final count = _map('sends').values
          .cast<Map<String, dynamic>>()
          .where(
            (v) =>
                v['sender'] == sender &&
                v['recipient'] == recipient &&
                (v['points'] as int) < 0 &&
                DateTime.parse(v['at'] as String).isAfter(since),
          )
          .length;
      if (count >= AuraRules.maxNegativesToSamePersonPerWindow) {
        throw const PrototypeFailure(
          'rate-limited',
          'too many negative sends to this friend today.',
        );
      }
    }
    _put(target.copyWith(score: target.score + points));
    _map('sends')[recordKey] = {
      ...payload,
      'at': DateTime.now().toIso8601String(),
    };
  });

  Future<void> deleteAccount(String uid) => _mutate(() {
    requireSelf(uid);
    _map('friends').removeWhere(
      (_, v) => ((v as Map<String, dynamic>)['members'] as List).contains(uid),
    );
    _map('sends').removeWhere((_, v) {
      final map = v as Map<String, dynamic>;
      return map['sender'] == uid || map['recipient'] == uid;
    });
    (_data['reports'] as List).removeWhere((v) {
      final map = v as Map<String, dynamic>;
      return map['viewer'] == uid || map['reported'] == uid;
    });
    _map('blocks').remove(uid);
    _map('users').remove(uid);
    _map('emails').removeWhere((_, v) => v == uid);
    _data['session'] = null;
  });

  Future<void> purge(String uid) => _mutate(() {
    requireSelf(uid);
    _map('sends').removeWhere((_, v) {
      final map = v as Map<String, dynamic>;
      return map['sender'] == uid || map['recipient'] == uid;
    });
  });

  Future<void> dispose() async {
    await _pending;
    await _changes.close();
  }
}
