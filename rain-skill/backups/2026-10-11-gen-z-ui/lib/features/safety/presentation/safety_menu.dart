import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/report_reason.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../auth/application/auth_providers.dart';
import '../application/safety_providers.dart';
import '../data/safety_repository.dart';
import '../../../prototype/prototype_runtime.dart';

/// The block / report overflow, attached to anyone who is not you.
///
/// One widget so the two actions are always offered together and always behave
/// the same wherever a person appears. Reporting someone you cannot also block
/// would be a dead end, and the security rules enforce that pairing anyway.
class SafetyMenu extends ConsumerWidget {
  const SafetyMenu({
    super.key,
    required this.otherUid,
    required this.handle,
    this.onDecline,
  });

  final String otherUid;

  /// Optional "decline" item, shown first when given.
  ///
  /// The friends screen passes this for an incoming request, where there is not
  /// room in the row for a separate decline button. Declining, blocking and
  /// reporting are all ways to make somebody go away, so grouping them reads
  /// better than it sounds.
  final VoidCallback? onDecline;

  /// `@name`, used in confirmation copy so the person knows exactly who this
  /// is about before confirming something irreversible-feeling.
  final String handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).value?.uid;
    if (myUid == null || myUid == otherUid) return const SizedBox.shrink();

    return PopupMenuButton<_SafetyAction>(
      tooltip: 'more',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => switch (action) {
        _SafetyAction.decline => onDecline?.call(),
        _SafetyAction.block => _confirmBlock(context, ref, myUid),
        _SafetyAction.report => _openReportSheet(context, ref, myUid),
      },
      itemBuilder: (context) => [
        if (onDecline != null)
          const PopupMenuItem(
            value: _SafetyAction.decline,
            child: Text('decline'),
          ),
        const PopupMenuItem(value: _SafetyAction.block, child: Text('block')),
        const PopupMenuItem(value: _SafetyAction.report, child: Text('report')),
      ],
    );
  }

  Future<void> _confirmBlock(
    BuildContext context,
    WidgetRef ref,
    String myUid,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuraColors.surface,
        title: Text('block $handle?', style: AuraType.headingMedium),
        content: Text(
          // Says the two things people actually want to know: it ends the
          // friendship, and they are not told.
          'they will be removed from your friends and will not be able to '
          'reach you. they are not told.',
          style: AuraType.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'block',
              style: TextStyle(color: AuraColors.negative),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await _run(
      context,
      () => ref
          .read(safetyRepositoryProvider)
          .block(viewerUid: myUid, blockedUid: otherUid),
      success: '$handle blocked.',
    );
  }

  Future<void> _openReportSheet(
    BuildContext context,
    WidgetRef ref,
    String myUid,
  ) async {
    final reason = await showModalBottomSheet<ReportReason>(
      context: context,
      backgroundColor: AuraColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AuraRadius.sheetTop),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpacing.screenPadding,
                  AuraSpacing.xl,
                  AuraSpacing.screenPadding,
                  AuraSpacing.sm,
                ),
                child: Text('report $handle', style: AuraType.headingMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpacing.screenPadding,
                ),
                // Honest about what happens. There is no review queue yet, and
                // implying one would be a promise the product does not keep.
                child: Text(
                  ref.read(prototypeEnabledProvider)
                      ? 'this demo report is saved only on your device. reporting also blocks them.'
                      : 'reporting also blocks them. we look at reports, but not '
                            'instantly — blocking is what protects you right now.',
                  style: AuraType.caption.copyWith(color: AuraColors.textMuted),
                ),
              ),
              const SizedBox(height: AuraSpacing.lg),
              for (final reason in ReportReason.values)
                ListTile(
                  minVerticalPadding: AuraSpacing.md,
                  title: Text(reason.label, style: AuraType.body),
                  onTap: () => Navigator.of(context).pop(reason),
                ),
              const SizedBox(height: AuraSpacing.lg),
            ],
          ),
        ),
      ),
    );

    if (reason == null || !context.mounted) return;

    await _run(
      context,
      () => ref
          .read(safetyRepositoryProvider)
          .report(
            viewerUid: myUid,
            reportedUid: otherUid,
            reason: reason.wireValue,
          ),
      success: 'reported. $handle is now blocked.',
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    required String success,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on SafetyFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (failure.problem) {
            SafetyProblem.network => 'no connection. try again.',
            SafetyProblem.cannotActOnYourself => 'that one is you.',
            _ => 'could not do that. try again.',
          }),
        ),
      );
    }
  }
}

enum _SafetyAction { decline, block, report }
