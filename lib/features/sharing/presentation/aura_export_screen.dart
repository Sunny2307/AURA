import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/aura_colors.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../../prototype/local_social_providers.dart';
import '../../../shared/widgets/aura_identity.dart';
import '../../../shared/widgets/aura_logo.dart';

enum AuraExportTemplate { score, moment, rank }

final auraCardShareProvider =
    Provider<Future<ShareResult> Function(ShareParams)>(
      (_) => SharePlus.instance.share,
    );

/// Render the actual share image; the preview displays these same PNG bytes.
Future<Uint8List> renderAuraCard({
  required String handle,
  required int score,
  required AuraExportTemplate template,
  String? moment,
  int? points,
  int? rank,
}) async {
  final logoData = await rootBundle.load(AuraLogo.assetPath);
  final logoCodec = await ui.instantiateImageCodec(
    logoData.buffer.asUint8List(logoData.offsetInBytes, logoData.lengthInBytes),
    targetWidth: 144,
    targetHeight: 144,
  );
  final ui.Image logo;
  try {
    logo = (await logoCodec.getNextFrame()).image;
  } finally {
    logoCodec.dispose();
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xfffff8ec), BlendMode.src);
  final fill = Paint()
    ..color = template == AuraExportTemplate.moment
        ? AuraColors.peach
        : AuraColors.lilac;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(60, 60, 960, 1800),
      const Radius.circular(72),
    ),
    fill,
  );
  final orbit = Paint()
    ..color = AuraColors.action.withValues(alpha: .2)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;
  canvas.drawCircle(const Offset(540, 650), 300, orbit);
  canvas.drawOval(const Rect.fromLTWH(160, 530, 760, 240), orbit);
  canvas.drawCircle(
    const Offset(540, 650),
    205,
    Paint()
      ..shader = ui.Gradient.radial(const Offset(540, 650), 205, [
        const Color(0xffddd1ff),
        const Color(0xff7954d9),
      ]),
  );
  void text(
    String value,
    double y,
    double size, {
    int maxLines = 2,
    FontWeight weight = FontWeight.w800,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: size,
          fontWeight: weight,
          color: AuraColors.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      ellipsis: '…',
    );
    painter.layout(maxWidth: 820);
    painter.paint(canvas, Offset((1080 - painter.width) / 2, y));
  }

  canvas.save();
  canvas.clipRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(468, 130, 144, 144),
      const Radius.circular(34),
    ),
  );
  canvas.drawImage(logo, const Offset(468, 130), Paint());
  canvas.restore();
  logo.dispose();
  text('aura', 292, 48);
  text('your reputation, remixed', 355, 30, weight: FontWeight.w500);
  text(handle, 930, 54);
  switch (template) {
    case AuraExportTemplate.score:
      text('$score', 1070, 150);
      text('aura points', 1270, 44);
    case AuraExportTemplate.moment:
      text(
        points == null
            ? 'a story in the making'
            : '${points > 0 ? '+' : ''}$points aura',
        1080,
        72,
      );
      text(
        moment ?? 'your first moment is still ahead.',
        1260,
        46,
        maxLines: 4,
      );
    case AuraExportTemplate.rank:
      text(rank == null ? 'off the grid' : '#$rank', 1070, 140);
      text(
        rank == null ? 'keeping my energy private' : 'in my friend circle',
        1270,
        44,
      );
      text('$score aura', 1400, 40);
  }
  text('made by your people.', 1610, 36);
  text('aura · local demo', 1740, 28, weight: FontWeight.w500);
  final picture = recorder.endRecording();
  final image = await picture.toImage(1080, 1920);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not render card');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

class AuraExportScreen extends ConsumerStatefulWidget {
  const AuraExportScreen({super.key});
  @override
  ConsumerState<AuraExportScreen> createState() => _AuraExportScreenState();
}

class _AuraExportScreenState extends ConsumerState<AuraExportScreen> {
  AuraExportTemplate _template = AuraExportTemplate.score;
  bool _busy = false;
  String? _message, _signature;
  Future<Uint8List>? _image;
  Future<void> _export(bool share, BuildContext buttonContext) async {
    if (_busy || _image == null) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bytes = await _image!;
      if (share) {
        final result = await ref.read(auraCardShareProvider)(
          ShareParams(
            files: [XFile.fromData(bytes, mimeType: 'image/png')],
            fileNameOverrides: ['aura-card.png'],
            sharePositionOrigin: origin,
          ),
        );
        _message = result.status == ShareResultStatus.dismissed
            ? 'sharing cancelled.'
            : result.status == ShareResultStatus.success
            ? 'card shared.'
            : 'share sheet opened.';
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
          _message =
              'Allow saving photos in your device settings, then try again.';
        } else {
          await Gal.putImageBytes(
            bytes,
            name: 'aura-${DateTime.now().millisecondsSinceEpoch}',
          );
          _message = 'saved to photos.';
        }
      } else {
        final location = await getSaveLocation(
          suggestedName: 'aura-card.png',
          acceptedTypeGroups: [
            const XTypeGroup(label: 'PNG image', extensions: ['png']),
          ],
        );
        if (location == null) {
          _message = 'saving cancelled.';
        } else {
          await XFile.fromData(
            bytes,
            mimeType: 'image/png',
          ).saveTo(location.path);
          _message = 'card saved.';
        }
      }
    } catch (_) {
      _message = 'could not export this card. check permissions and try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localRevisionProvider);
    final store = ref.watch(prototypeStoreProvider);
    final user = store.currentUid == null
        ? null
        : store.user(store.currentUid!);
    if (user != null) {
      final top =
          store
              .momentsFor(user.uid)
              .where((m) => m.recipient == user.uid)
              .toList()
            ..sort((a, b) => b.points.compareTo(a.points));
      final moment = top.firstOrNull;
      final signature =
          '${user.uid}:${user.score}:$_template:${store.rank}:${moment?.id}';
      if (signature != _signature) {
        _signature = signature;
        _image = renderAuraCard(
          handle: user.handle,
          score: user.score,
          template: _template,
          moment: moment?.reason,
          points: moment?.points,
          rank: store.rank,
        );
      }
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AuraBackButton(),
        title: const Text('share your aura'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AuraIntro(
              label: 'let your energy travel',
              title: 'made to be shared.',
              body: 'Pick your vibe. Save a sharp Stories-sized card or open your device’s share sheet.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in AuraExportTemplate.values)
                  ChoiceChip(
                    label: Text(template.name),
                    selected: _template == template,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _template = template),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (user == null)
              const Text('sign in to export your card.')
            else
              FutureBuilder<Uint8List>(
                future: _image,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'could not render the preview. choose another template.',
                    );
                  }
                  return AspectRatio(
                    aspectRatio: 9 / 16,
                    child: snapshot.hasData
                        ? Image.memory(
                            snapshot.data!,
                            key: const Key('aura-export-preview'),
                            semanticLabel: 'Aura Card preview',
                            gaplessPlayback: true,
                          )
                        : const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            const SizedBox(height: 16),
            Builder(
              builder: (buttonContext) => FilledButton.icon(
                onPressed: _busy || user == null
                    ? null
                    : () => unawaited(_export(true, buttonContext)),
                icon: const Icon(Icons.ios_share),
                label: Text(_busy ? 'preparing…' : 'share card'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _busy || user == null
                  ? null
                  : () => unawaited(_export(false, context)),
              icon: const Icon(Icons.download_rounded),
              label: const Text('save image'),
            ),
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
          ],
        ),
      ),
    );
  }
}
