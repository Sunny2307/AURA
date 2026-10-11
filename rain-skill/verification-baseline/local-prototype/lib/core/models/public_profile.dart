/// The only shape of another person this app lets you see before you are
/// friends: a handle and a photo.
///
/// Stored at `publicProfiles/{uid}`, separate from `users/{uid}`, because that
/// document carries `birthYear`, `isMinor` and privacy settings and is readable
/// only by its owner. Discovery needs *something* readable, and the safe answer
/// is a document that contains nothing worth protecting.
///
/// ### Why there is no score here
///
/// This document is written by the client. Anything in it is something a
/// decompiled app can lie about, and a score it could lie about would appear in
/// every search result and friend list as if it were real. The score therefore
/// stays on `users/{uid}`, which no client can write. The cost is visible and
/// deliberate: **friends cannot see each other's scores yet.** That needs a
/// server-side read path, which needs Cloud Functions, which needs the Blaze
/// plan. Slice 6.
///
/// The handle, by contrast, *cannot* be lied about: the security rules only
/// accept a public profile whose `username` matches `users/{uid}.username`,
/// which is itself pinned to a permanent `usernames/{name}` claim.
final class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.username,
    required this.photoUrl,
  });

  /// Reads a document body. [uid] comes from the document id rather than a
  /// field, for the same reason it does on `AuraUser` — storing it twice invites
  /// the two to disagree.
  factory PublicProfile.fromMap(String uid, Map<String, Object?> map) {
    return PublicProfile(
      uid: uid,
      username: switch (map[fieldUsername]) {
        final String v => v,
        _ => '',
      },
      photoUrl: switch (map[fieldPhotoUrl]) {
        final String v when v.isNotEmpty => v,
        _ => null,
      },
    );
  }

  static const String fieldUsername = 'username';
  static const String fieldPhotoUrl = 'photoUrl';

  final String uid;
  final String username;
  final String? photoUrl;

  /// `@username`, for display. Centralised so the `@` is never hand-typed.
  String get handle => '@$username';

  /// The document written at signup. `photoUrl` is always present, as `null`
  /// when there is no photo, because the rules list it as an allowed key and an
  /// absent key would make a later "set my photo" an add rather than a change.
  Map<String, Object?> toCreateMap() {
    return {fieldUsername: username, fieldPhotoUrl: photoUrl};
  }

  @override
  bool operator ==(Object other) =>
      other is PublicProfile &&
      other.uid == uid &&
      other.username == username &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(uid, username, photoUrl);
}
