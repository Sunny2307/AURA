import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/friendship.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../auth/application/auth_providers.dart';
import '../application/friends_providers.dart';
import '../data/friendship_repository.dart';

/// The one control that knows every state two people can be in.
///
/// There is deliberately a single widget for this rather than an Add button on
/// one screen and an Accept button on another. The states are mutually
/// exclusive and the transitions between them are live — if someone accepts
/// your request while you are looking at their profile, the button must become
/// "friends" without a refresh. One widget watching one stream does that; two
/// screens each guessing do not.
class FriendActionButton extends ConsumerStatefulWidget {
  const FriendActionButton({
    super.key,
    required this.otherUid,
    required this.handle,
    this.compact = false,
  });

  final String otherUid;

  /// Renders only the primary action, leaving the secondary one to the caller.
  ///
  /// A list row has room for about one button. Showing accept *and* decline
  /// *and* the safety overflow in a `ListTile.trailing` squeezes the handle —
  /// the one piece of information the row exists to show — down to nothing on a
  /// normal phone. In compact mode the friends screen puts decline in the
  /// overflow menu beside block and report, which is where it belongs anyway:
  /// they are all ways to make somebody go away.
  final bool compact;

  /// `@name`, used only in confirmation copy. Passed in rather than looked up
  /// again here — every caller already has the profile in hand, and a second
  /// lookup would mean a second document read per row in a list.
  final String handle;

  @override
  ConsumerState<FriendActionButton> createState() =>
      _FriendActionButtonState();
}

class _FriendActionButtonState extends ConsumerState<FriendActionButton> {
  /// Guards against a double tap firing two writes. Local rather than in a
  /// provider because it is about this button's press, not about the data.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateProvider).value?.uid;
    final friendship = ref.watch(friendshipWithProvider(widget.otherUid));

    if (myUid == null) return const SizedBox.shrink();

    return switch (friendship) {
      AsyncData(value: null) => _button(
        label: 'add',
        onPressed: () => _run(
          () => ref
              .read(friendshipRepositoryProvider)
              .request(fromUid: myUid, toUid: widget.otherUid),
        ),
      ),

      AsyncData(value: final Friendship f)
          when f.status == FriendshipStatus.accepted =>
        _secondary(
          label: 'friends',
          onPressed: () => _confirmRemove(
            title: 'remove ${widget.handle}?',
            body: 'you will both stop seeing each other in your friend lists.',
            myUid: myUid,
          ),
        ),

      AsyncData(value: final Friendship f) when f.isIncomingFor(myUid) =>
        widget.compact
            ? _button(
                label: 'accept',
                onPressed: () => _run(
                  () => ref
                      .read(friendshipRepositoryProvider)
                      .accept(viewerUid: myUid, otherUid: widget.otherUid),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _button(
                    label: 'accept',
                    onPressed: () => _run(
                      () => ref
                          .read(friendshipRepositoryProvider)
                          .accept(viewerUid: myUid, otherUid: widget.otherUid),
                    ),
                  ),
                  const SizedBox(width: AuraTouch.minGap),
                  _secondary(
                    label: 'decline',
                    onPressed: () => _run(
                      () => ref
                          .read(friendshipRepositoryProvider)
                          .remove(viewerUid: myUid, otherUid: widget.otherUid),
                    ),
                  ),
                ],
              ),

      // Outgoing and still pending. Tapping cancels — the label says "requested"
      // rather than "cancel" because the state is the information; the action is
      // secondary and confirmed anyway.
      AsyncData(value: Friendship()) => _secondary(
        label: 'requested',
        onPressed: () => _confirmRemove(
          title: 'cancel the request?',
          body: 'they will not be told either way.',
          myUid: myUid,
        ),
      ),

      AsyncError() => _secondary(label: 'unavailable', onPressed: null),

      _ => const SizedBox(
        height: AuraTouch.minTarget,
        width: AuraTouch.minTarget,
        child: Center(
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    };
  }

  Widget _button({required String label, required VoidCallback? onPressed}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AuraTouch.minTarget),
      child: FilledButton(
        onPressed: _busy ? null : onPressed,
        child: Text(label),
      ),
    );
  }

  Widget _secondary({required String label, required VoidCallback? onPressed}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AuraTouch.minTarget),
      child: OutlinedButton(
        onPressed: _busy ? null : onPressed,
        child: Text(label),
      ),
    );
  }

  Future<void> _confirmRemove({
    required String title,
    required String body,
    required String myUid,
  }) async {
    // Unfriending and cancelling are both irreversible from the other side's
    // point of view — a re-request is a new notification — so neither happens
    // on a single tap.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuraColors.surface,
        title: Text(title, style: AuraType.headingMedium),
        content: Text(body, style: AuraType.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'remove',
              style: TextStyle(color: AuraColors.negative),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _run(
      () => ref
          .read(friendshipRepositoryProvider)
          .remove(viewerUid: myUid, otherUid: widget.otherUid),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on FriendshipFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFor(failure.problem))),
      );
    } finally {
      // The widget can be disposed mid-write — a friend list rebuilds the moment
      // the listener fires, which can happen before this returns.
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Copy lives here, not in the repository. The repository's job is to name
  /// *what* went wrong; saying it in the app's voice is the screen's.
  String _messageFor(FriendshipProblem problem) {
    return switch (problem) {
      FriendshipProblem.alreadyExists => 'you already have a request with them.',
      FriendshipProblem.noLongerExists => 'that request is gone.',
      FriendshipProblem.notYoursToAccept =>
        'they have to accept this one, not you.',
      FriendshipProblem.cannotBefriendYourself => 'that one is you.',
      FriendshipProblem.permissionDenied => 'not allowed.',
      FriendshipProblem.network => 'no connection. try again.',
      FriendshipProblem.unknown => 'something went wrong.',
    };
  }
}
