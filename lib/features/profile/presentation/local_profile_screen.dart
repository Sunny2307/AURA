import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../prototype/local_social_providers.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../../shared/widgets/aura_identity.dart';
import '../../../shared/widgets/aura_card.dart';
import '../../../shared/widgets/profile_photo.dart';
import '../../feed/presentation/feed_screen.dart';

class LocalProfileScreen extends ConsumerWidget {
  const LocalProfileScreen({super.key, required this.uid});
  final String uid;
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final store = ref.read(prototypeStoreProvider);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _BioEditor(initial: store.bio(uid)),
    );
    if (value != null && context.mounted) {
      await localAction(context, () => store.editBio(uid, value));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localRevisionProvider);
    final store = ref.watch(prototypeStoreProvider);
    final account = store.canViewProfile(uid) ? store.user(uid) : null;
    final own = store.currentUid == uid;
    final moments = store
        .momentsFor(uid)
        .where((m) => m.recipient == uid)
        .toList();
    final positive = moments.where((m) => m.points > 0).toList()
      ..sort((a, b) => b.points.compareTo(a.points));
    final negative = moments.where((m) => m.points < 0).toList()
      ..sort((a, b) => a.points.compareTo(b.points));
    return Scaffold(
      appBar: AppBar(
        leading: const AuraBackButton(),
        title: Text(own ? 'your profile' : 'friend profile'),
      ),
      body: SafeArea(
        child: account == null
            ? const Center(child: Text('this profile is unavailable.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AuraCard(
                    color: AuraColors.lilac,
                    large: true,
                    child: Column(
                      children: [
                        if (account.photoUrl != null)
                          ProfilePhoto(url: account.photoUrl!, size: 88)
                        else
                          AuraOrbit(score: account.score, size: 130),
                        const SizedBox(height: 16),
                        Text(account.handle, style: AuraType.headingMedium),
                        Text(
                          '${account.score} aura',
                          style: AuraType.scoreLarge,
                        ),
                        if (store.bio(uid).isNotEmpty)
                          Text(store.bio(uid), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            if (own)
                              OutlinedButton(
                                onPressed: () => unawaited(_edit(context, ref)),
                                child: const Text('edit bio'),
                              ),
                            if (own)
                              OutlinedButton(
                                onPressed: () =>
                                    AppRouter.pushTo(context, AuraRoutes.photo),
                                child: const Text('edit photo'),
                              ),
                            if (!own)
                              FilledButton(
                                onPressed: () => AppRouter.pushTo(
                                  context,
                                  '${AuraRoutes.sendAura}?to=${Uri.encodeQueryComponent(uid)}',
                                ),
                                child: const Text('send aura'),
                              ),
                            if (own)
                              FilledButton.icon(
                                onPressed: () => AppRouter.pushTo(
                                  context,
                                  AuraRoutes.exportCard,
                                ),
                                icon: const Icon(Icons.ios_share),
                                label: const Text('share your aura'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('your last 30 days', style: AuraType.headingMedium),
                  const SizedBox(height: 12),
                  AuraCard(
                    child: ScoreHistory(values: store.scoreHistory(uid)),
                  ),
                  const SizedBox(height: 24),
                  Text('top moments', style: AuraType.headingMedium),
                  const SizedBox(height: 12),
                  if (moments.isEmpty)
                    const Text(
                      'your story is just getting started. received moments will appear here.',
                    ),
                  for (final m in [...positive.take(3), ...negative.take(3)])
                    MomentCard(moment: m),
                ],
              ),
      ),
    );
  }
}

class _BioEditor extends StatefulWidget {
  const _BioEditor({required this.initial});
  final String initial;
  @override
  State<_BioEditor> createState() => _BioEditorState();
}

class _BioEditorState extends State<_BioEditor> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('a little about you'),
    content: TextField(
      controller: _controller,
      maxLength: 160,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'bio'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('save bio'),
      ),
    ],
  );
}

class ScoreHistory extends StatelessWidget {
  const ScoreHistory({super.key, required this.values});
  final List<int> values;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (values.isNotEmpty)
        Text(
          '${values.first} → ${values.last} aura',
          style: AuraType.bodyStrong,
        ),
      const SizedBox(height: 16),
      Semantics(
        label: values.isEmpty
            ? 'no score history'
            : '30 day score history, ${values.first} to ${values.last} aura',
        child: SizedBox(
          height: 120,
          child: CustomPaint(painter: _HistoryPainter(values)),
        ),
      ),
      const SizedBox(height: 8),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text('30 days ago'), Text('today')],
      ),
      const SizedBox(height: 8),
      const Text(
        'Reconstructed from saved local transactions.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter(this.values);
  final List<int> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final span = math.max(1, high - low);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * size.width / (values.length - 1);
      final y = 10 + (size.height - 20) * (1 - (values[i] - low) / span);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AuraColors.action
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HistoryPainter oldDelegate) =>
      oldDelegate.values != values;
}
