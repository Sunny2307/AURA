/// A friendship between two people, stored as **one** document at
/// `friendships/{pairId}`.
///
/// ### Why one document and not two
///
/// The MVP plan's data model specifies mirrored `users/{uid}/friends/{friendUid}`
/// entries, one under each person. That was rejected during slice 2 for two
/// reasons:
///
/// 1. Accepting a request would mean writing into *another user's* document
///    tree. On the Spark plan there is no Cloud Function to do it, so the client
///    would have to, and the security rules would have to permit a write path
///    into someone else's data — the widest surface in the app, for a feature
///    that does not need it.
/// 2. Two documents that must agree will eventually disagree. A crash between
///    the two writes leaves a friendship that exists for one person and not the
///    other, and nothing in the system would ever notice.
///
/// One document cannot half-exist.
///
/// ### Why the id is derived rather than random
///
/// [pairIdFor] sorts the two uids and joins them. That makes the document id a
/// pure function of who is involved, which means:
///
/// * Two people who request each other at the same instant collide on one id.
///   One write wins, the other fails, and nobody ends up with two competing
///   friendships. This is the same trick `usernames/{name}` uses to make handles
///   unique without a unique index.
/// * "Are we already friends?" is a document read, not a query.
///
/// The security rules re-derive the id from `members` and reject any document
/// whose id does not match, so a client cannot park a second friendship for the
/// same pair under an id of its own choosing.
enum FriendshipStatus {
  /// Requested by one side, not yet answered by the other.
  pending,

  accepted;

  String get wireValue => name;

  /// Unknown values read as [pending] rather than [accepted]. If a document is
  /// corrupt or written by a newer version, the safe interpretation is the one
  /// that grants nothing — an unreadable status must never be treated as
  /// consent that was never given.
  static FriendshipStatus fromWire(Object? value) {
    return switch (value) {
      'accepted' => FriendshipStatus.accepted,
      _ => FriendshipStatus.pending,
    };
  }
}

final class Friendship {
  const Friendship({
    required this.id,
    required this.members,
    required this.requestedBy,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
  });

  factory Friendship.fromMap(
    String id,
    Map<String, Object?> map, {
    required DateTime Function(Object? value) parseTimestamp,
  }) {
    return Friendship(
      id: id,
      members: switch (map[fieldMembers]) {
        final List<Object?> v => v.whereType<String>().toList(growable: false),
        _ => const <String>[],
      },
      requestedBy: switch (map[fieldRequestedBy]) {
        final String v => v,
        _ => '',
      },
      status: FriendshipStatus.fromWire(map[fieldStatus]),
      createdAt: parseTimestamp(map[fieldCreatedAt]),
      respondedAt: map[fieldRespondedAt] == null
          ? null
          : parseTimestamp(map[fieldRespondedAt]),
    );
  }

  static const String fieldMembers = 'members';
  static const String fieldRequestedBy = 'requestedBy';
  static const String fieldStatus = 'status';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldRespondedAt = 'respondedAt';

  /// The document id: the two uids, sorted, joined with `_`.
  ///
  /// Sorting uses Dart's [String.compareTo], which orders by UTF-16 code unit,
  /// while the security rules use Firestore's `<`, which orders by UTF-8 byte.
  /// The two can disagree — but only above the ASCII range, and Firebase Auth
  /// uids are 28 characters of `[A-Za-z0-9]`. Within that set the orderings are
  /// identical, so the client and the rules always derive the same id.
  static String pairIdFor(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  final String id;

  /// Both uids, sorted. Sorted rather than `[requester, target]` because the
  /// order has to be derivable from the id, and because the friend-list query
  /// is `members array-contains <me>`, which does not care about order.
  final List<String> members;

  final String requestedBy;
  final FriendshipStatus status;
  final DateTime createdAt;

  /// When the request was accepted. Null while pending.
  final DateTime? respondedAt;

  /// The other person, from [viewerUid]'s point of view.
  ///
  /// Returns an empty string if [viewerUid] is not a member, which only happens
  /// for a corrupt document — the rules make it unreadable otherwise.
  String otherMember(String viewerUid) {
    // The membership check comes first deliberately. Without it, calling this
    // with a uid that is not part of the friendship returns the *first* member,
    // which is a real person's uid — so a mis-keyed call would silently name
    // somebody, and the caller would have no way to tell that from a correct
    // answer.
    if (!members.contains(viewerUid)) return '';
    for (final uid in members) {
      if (uid != viewerUid) return uid;
    }
    return '';
  }

  bool involves(String uid) => members.contains(uid);

  /// Whether [viewerUid] is the one being asked, and so the one who may accept.
  /// Mirrors the security rule exactly: the sender cannot accept their own
  /// request, or request-and-accept would be a single unilateral action.
  bool isIncomingFor(String viewerUid) =>
      status == FriendshipStatus.pending &&
      involves(viewerUid) &&
      requestedBy != viewerUid;

  bool isOutgoingFor(String viewerUid) =>
      status == FriendshipStatus.pending && requestedBy == viewerUid;

  @override
  bool operator ==(Object other) =>
      other is Friendship &&
      other.id == id &&
      other.requestedBy == requestedBy &&
      other.status == status;

  @override
  int get hashCode => Object.hash(id, requestedBy, status);
}
