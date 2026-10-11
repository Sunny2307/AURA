import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../features/auth/application/auth_providers.dart';
import '../core/theme/aura_spacing.dart';
import '../shared/widgets/aura_orb.dart';
import '../shared/widgets/profile_photo.dart';
import 'prototype_runtime.dart';

class LocalPhotoStep extends ConsumerStatefulWidget {
  const LocalPhotoStep({super.key, required this.onContinue});
  final VoidCallback onContinue;
  @override
  ConsumerState<LocalPhotoStep> createState() => _LocalPhotoStepState();
}

class _LocalPhotoStepState extends ConsumerState<LocalPhotoStep> {
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_recoverPhoto());
  }

  Future<void> _recoverPhoto() async {
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.files?.isNotEmpty == true && mounted) {
        await _save(response.files!.first);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'could not restore the selected photo. choose it again.',
        );
      }
    }
  }

  Future<void> _save(XFile picked) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    if (await picked.length() > 5 * 1024 * 1024) {
      throw StateError('photo too large');
    }
    await LocalPhotos(ref.read(prototypeStoreProvider)).uploadProfilePhoto(
      uid: uid,
      bytes: await picked.readAsBytes(),
      contentType: picked.mimeType ?? 'image/jpeg',
    );
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) await _save(picked);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'could not save that photo. choose an image under 5 MB or keep the orb.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentUserProvider).value;
    if (account == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(AuraSpacing.screenPadding),
      children: [
        Text('add a photo?', style: Theme.of(context).textTheme.headlineMedium),
        const Text(
          'Your photo stays on this device. You can also keep the orb.',
        ),
        const SizedBox(height: AuraSpacing.xl),
        Center(
          child: account.photoUrl == null
              ? AuraOrb(score: account.score, size: 160)
              : ProfilePhoto(url: account.photoUrl!, size: 160),
        ),
        const SizedBox(height: AuraSpacing.lg),
        Center(child: Text(account.handle)),
        const SizedBox(height: AuraSpacing.xl),
        FilledButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(_busy ? 'saving…' : 'choose a photo'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        TextButton(
          onPressed: _busy ? null : widget.onContinue,
          child: Text(account.photoUrl == null ? 'keep the orb' : 'continue'),
        ),
      ],
    );
  }
}
