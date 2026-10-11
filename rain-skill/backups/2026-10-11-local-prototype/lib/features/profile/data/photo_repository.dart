import 'dart:typed_data';

/// Profile photo upload — **interface only, deliberately unimplemented.**
///
/// Spec §5.3 ends signup with a camera-first photo upload to Cloud Storage. That
/// cannot be built right now: the project's Storage bucket does not exist.
/// `GET https://firebasestorage.googleapis.com/v0/b/aura-d68c3.firebasestorage.app/o`
/// returns HTTP 404, meaning the bucket has never been provisioned. *I believe*
/// provisioning it requires the paid Blaze plan — treat that as unverified — but
/// the 404 is certain either way: there is nowhere to upload to.
///
/// So this interface exists with no implementation, and the signup photo step is
/// skippable with the orb as the fallback avatar. The alternative — a picker that
/// appears to work and silently drops the image, or writes a `photoUrl` pointing
/// at nothing — would be worse than an honest gap, because it would look finished.
///
/// **To finish this:** upgrade the project to Blaze, provision the default bucket,
/// then add a `FirebaseStoragePhotoRepository` implementing this interface and a
/// `storage.rules` restricting writes to `profile_photos/{uid}` with a size and
/// content-type cap. The signup step needs no changes beyond being un-skipped.
abstract interface class PhotoRepository {
  /// Uploads [bytes] as the profile photo for [uid] and returns the download URL
  /// to store in `users/{uid}.photoUrl`.
  ///
  /// [bytes] rather than a `File` so the same interface works for a camera
  /// capture, a gallery pick, and a test fixture without touching a filesystem.
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> deleteProfilePhoto(String uid);
}

/// Thrown when a photo operation is attempted while Storage is unprovisioned.
///
/// Not a silent no-op: a repository that quietly succeeds without uploading
/// anything is the exact failure this whole file is arranged to avoid. If a
/// future screen wires the picker up before the bucket exists, it fails loudly in
/// a test.
final class PhotoStorageUnavailable implements Exception {
  const PhotoStorageUnavailable();

  @override
  String toString() =>
      'PhotoStorageUnavailable: the aura-d68c3 Storage bucket is not '
      'provisioned (HTTP 404). See PhotoRepository docs.';
}

/// The stand-in registered until Storage exists. Every method throws.
final class UnavailablePhotoRepository implements PhotoRepository {
  const UnavailablePhotoRepository();

  @override
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    throw const PhotoStorageUnavailable();
  }

  @override
  Future<void> deleteProfilePhoto(String uid) async {
    throw const PhotoStorageUnavailable();
  }
}
