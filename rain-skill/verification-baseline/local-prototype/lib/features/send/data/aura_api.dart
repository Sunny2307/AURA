import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The API stays on this computer during development. Android Emulator reaches
/// the host through 10.0.2.2; a USB phone uses adb reverse and 127.0.0.1.
const auraApiBaseUrl = String.fromEnvironment(
  'AURA_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8787',
);

final auraApiProvider = Provider<AuraApi>((ref) => const HttpAuraApi());

final class AuraApiFailure implements Exception {
  const AuraApiFailure(this.message, {this.code});
  final String message;
  final String? code;
}

abstract interface class AuraApi {
  /// Sends one aura transaction. Reuse the same key when retrying the same send.
  Future<void> send({
    required String recipientUid,
    required int points,
    required String reason,
    required String visibility,
    required String idempotencyKey,
    String? chipId,
  });

  /// Purges this account's aura history before profile/Auth deletion.
  Future<void> purgeForDeletion();
}

final class HttpAuraApi implements AuraApi {
  const HttpAuraApi();

  @override
  Future<void> send({
    required String recipientUid,
    required int points,
    required String reason,
    required String visibility,
    required String idempotencyKey,
    String? chipId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const AuraApiFailure('sign in again.');
    final token = await user.getIdToken();
    if (token == null) throw const AuraApiFailure('sign in again.');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(Uri.parse('$auraApiBaseUrl/v1/aura'));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final payload = <String, Object>{
        'recipientUid': recipientUid,
        'points': points,
        'reason': reason,
        'visibility': visibility,
        'idempotencyKey': idempotencyKey,
      };
      if (chipId != null) payload['chipId'] = chipId;
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 12));
      if (response.statusCode == 200 || response.statusCode == 201) return;
      final decoded = jsonDecode(body);
      final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
      final message = error is Map<String, dynamic> ? error['message'] : null;
      final code = error is Map<String, dynamic> ? error['code'] : null;
      throw AuraApiFailure(message is String ? message : 'could not send aura.',
          code: code is String ? code : null);
    } on SocketException {
      throw const AuraApiFailure('cannot reach the local aura server.');
    } on TimeoutException {
      throw const AuraApiFailure('the local aura server took too long.');
    } on FormatException {
      throw const AuraApiFailure('the server sent an unreadable response.');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> purgeForDeletion() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw const AuraApiFailure('sign in again.');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.deleteUrl(Uri.parse('$auraApiBaseUrl/v1/me/aura-data'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        final decoded = jsonDecode(body);
        final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
        final code = error is Map<String, dynamic> ? error['code'] : null;
        throw AuraApiFailure('could not remove aura history. try again.',
            code: code is String ? code : null);
      }
    } on SocketException {
      throw const AuraApiFailure('cannot reach the local aura server.');
    } on TimeoutException {
      throw const AuraApiFailure('the local aura server took too long.');
    } on FormatException {
      throw const AuraApiFailure('the server sent an unreadable response.');
    } finally {
      client.close(force: true);
    }
  }
}
