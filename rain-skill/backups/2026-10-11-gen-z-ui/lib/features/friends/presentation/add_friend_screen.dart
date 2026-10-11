import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../core/validation/username_rules.dart';
import '../../../shared/widgets/aura_card.dart';
import '../../auth/data/user_repository.dart';
import '../application/friend_search_controller.dart';
import 'friend_action_button.dart';
import 'friend_tile.dart';

/// Find one person by their exact handle.
///
/// Exact match only — no partial search, no suggestions, no directory. That is
/// a product decision (slice 2 brainstorm) *and* what the backend permits:
/// `list` is denied on both `usernames` and `publicProfiles`, so there is no
/// query here that could enumerate the user base even if a later screen wanted
/// one.
///
/// The other way in is an invite link, which lands on the same profile view —
/// see `AuraRoutes.profileByUsername`.
class AddFriendScreen extends ConsumerStatefulWidget {
  const AddFriendScreen({super.key});

  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('add a friend', style: AuraType.headingMedium)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                // Handles are lowercase a-z, 0-9 and underscore. Filtering at
                // the keyboard means the offline check almost never has to
                // reject anything, and the user is never told off for a
                // character the field should not have accepted.
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(UsernameRules.maxLength),
                ],
                decoration: const InputDecoration(
                  prefixText: '@',
                  hintText: 'their handle',
                ),
                onChanged: (value) {
                  if (value.isEmpty) {
                    ref.read(friendSearchControllerProvider.notifier).clear();
                  }
                },
                onSubmitted: _search,
              ),
              const SizedBox(height: AuraSpacing.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AuraTouch.minTarget,
                ),
                child: FilledButton(
                  onPressed: state is FriendSearchBusy
                      ? null
                      : () => _search(_controller.text),
                  child: const Text('look up'),
                ),
              ),
              const SizedBox(height: AuraSpacing.xl),
              Expanded(child: _Result(state: state)),
            ],
          ),
        ),
      ),
    );
  }

  void _search(String raw) {
    _focus.unfocus();
    // Fire-and-forget on purpose: the controller publishes every stage of the
    // lookup as state, so there is nothing for the caller to await.
    unawaited(ref.read(friendSearchControllerProvider.notifier).search(raw));
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.state});

  final FriendSearchState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      FriendSearchIdle() => const _Hint(
        'handles are exact. ask them to read it out, or open the link they sent '
        'you.',
      ),

      FriendSearchBusy() => const Center(child: CircularProgressIndicator()),

      FriendSearchInvalid(:final problem) => _Message(
        _copyFor(problem),
        tone: AuraColors.textMuted,
      ),

      // Deliberately worded as "nobody has it", not "not found". The handle
      // being free is a fact about the handle, not a failure of the search.
      FriendSearchNotFound(:final username) => _Message(
        'nobody has @$username.',
        tone: AuraColors.textMuted,
      ),

      FriendSearchYourself() => const _Message(
        'that one is you.',
        tone: AuraColors.textMuted,
      ),

      // Kept apart from not-found on purpose: telling someone a handle does not
      // exist when the connection dropped sends them off to re-check a handle
      // that was right all along.
      FriendSearchFailed(:final problem) => _Message(
        problem == AccountProblem.network
            ? 'no connection. the handle might be fine — try again.'
            : 'could not look that up right now.',
        tone: AuraColors.negative,
      ),

      FriendSearchFound(:final profile) => AuraCard(
        child: FriendTile(
          profile: profile,
          trailing: FriendActionButton(
            otherUid: profile.uid,
            handle: profile.handle,
          ),
        ),
      ),
    };
  }

  String _copyFor(UsernameProblem problem) {
    return switch (problem) {
      UsernameProblem.empty => 'type a handle first.',
      UsernameProblem.tooShort =>
        'handles are at least ${UsernameRules.minLength} characters.',
      UsernameProblem.tooLong =>
        'handles are at most ${UsernameRules.maxLength} characters.',
      UsernameProblem.badCharacters => 'letters, numbers and _ only.',
      UsernameProblem.mustStartWithLetter => 'handles start with a letter.',
      UsernameProblem.doubleUnderscore => 'no double underscores.',
      UsernameProblem.trailingUnderscore => 'handles do not end in _.',
      UsernameProblem.reserved => 'nobody has that one.',
    };
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AuraType.bodySmall.copyWith(color: AuraColors.textMuted),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AuraType.body.copyWith(color: tone));
  }
}
