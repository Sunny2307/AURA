import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prototype/prototype_runtime.dart';

class ProfilePhoto extends ConsumerWidget {
  const ProfilePhoto({super.key, required this.url, required this.size});
  final String url;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = Uri.tryParse(url);
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.person_outline),
        );
    if (ref.watch(prototypeEnabledProvider) && uri?.scheme != 'file') {
      return fallback(context, StateError('Local photos only'), null);
    }
    final image = uri?.scheme == 'file'
        ? Image.file(
            File.fromUri(uri!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: fallback,
          )
        : Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: fallback,
          );
    return ClipOval(child: image);
  }
}
