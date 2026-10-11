import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/aura_user.dart';
import '../../../core/models/friendship.dart';
import '../../../core/models/public_profile.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../auth/application/auth_providers.dart';
import '../application/friends_providers.dart';
import '../../safety/presentation/safety_menu.dart';
import 'friend_action_button.dart';
import 'friend_tile.dart';

/// Your friends, and the requests waiting on you.
///
/// Both lists come from one Firestore listener per status, scoped to you by
/// `members array-contains <you>` — the only query shape the security rules
/// accept on this collection.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider);
    final outgoing = ref.watch(outgoingRequestsProvider);
    final friends = ref.watch(friendshipsProvider);
    final me = ref.watch(currentUserProvider).value;
    final myUid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('friends', style: AuraType.headingMedium),
        actions: [
          if (me != null)
            IconButton(
              tooltip: 'share your handle',
              onPressed: () => _shareHandle(context, me),
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      // The primary action sits in the thumb zone rather than in the app bar,
      // which on a tall phone is the hardest place on the screen to reach.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppRouter.pushTo(context, AuraRoutes.addFriend),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('add'),
      ),
      body: SafeArea(
        child: switch (friends) {
          AsyncError() => const _Failed(),
          AsyncData(value: final accepted) => _Lists(
            accepted: accepted,
            incoming: incoming.value ?? const [],
            outgoing: outgoing.value ?? const [],
            me: me,
            myUid: myUid ?? '',
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Future<void> _shareHandle(BuildContext context, AuraUser me) async {
    // Copy-to-clipboard rather than the OS share sheet: `share_plus` is a
    // dependency this slice does not otherwise need, and pasting into whichever
    // group chat the friend group already lives in is the actual behaviour.
    final link = AuraRoutes.inviteLinkFor(me.username);
    await Clipboard.setData(
      ClipboardData(text: 'add me on aura: ${me.handle}\n$link'),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('invite copied.')));
  }
}

class _Lists extends StatelessWidget {
  const _Lists({
    required this.accepted,
    required this.incoming,
    required this.outgoing,
    required this.me,
    required this.myUid,
  });

  final List<Friendship> accepted;
  final List<Friendship> incoming;
  final List<Friendship> outgoing;
  final AuraUser? me;

  /// The signed-in uid, needed to work out which member of each friendship is
  /// the *other* person. Comes from auth state rather than being recovered from
  /// the documents, because a friendship knows both uids and nothing about
  /// which one is reading it.
  final String myUid;

  @override
  Widget build(BuildContext context) {
    if (accepted.isEmpty && incoming.isEmpty && outgoing.isEmpty) {
      return _Empty(me: me);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.sm,
        vertical: AuraSpacing.md,
      ),
      children: [
        if (incoming.isNotEmpty) ...[
          _SectionHeading('waiting on you (${incoming.length})'),
          for (final friendship in incoming)
            _Row(
              key: ValueKey('incoming-${friendship.id}'),
              uid: friendship.otherMember(myUid),
              subtitle: 'wants to be friends',
              incoming: true,
            ),
          const SizedBox(height: AuraSpacing.lg),
        ],
        if (accepted.isNotEmpty) ...[
          _SectionHeading('friends (${accepted.length})'),
          for (final friendship in accepted)
            _Row(
              key: ValueKey('friend-${friendship.id}'),
              uid: friendship.otherMember(myUid),
            ),
          const SizedBox(height: AuraSpacing.lg),
        ],
        if (outgoing.isNotEmpty) ...[
          _SectionHeading('sent (${outgoing.length})'),
          for (final friendship in outgoing)
            _Row(
              key: ValueKey('outgoing-${friendship.id}'),
              uid: friendship.otherMember(myUid),
              subtitle: 'not answered yet',
            ),
        ],
        // Clears the floating action button, which would otherwise sit on top of
        // the last row and make it untappable.
        const SizedBox(height: AuraSpacing.xxl * 2),
      ],
    );
  }

}

/// One person, resolved from their uid to a public profile.
///
/// The friendship document holds uids, not handles — it has to, or a handle
/// change would orphan it. Each row therefore watches its own
/// `publicProfiles/{uid}` document, which also means one friend changing their
/// photo rebuilds one row rather than the whole list.
class _Row extends ConsumerWidget {
  const _Row({
    super.key,
    required this.uid,
    this.subtitle,
    this.incoming = false,
  });

  final String uid;
  final String? subtitle;

  /// Whether this row is a request waiting on the viewer, which is the only
  /// state that needs a decline action.
  final bool incoming;

  void _decline(WidgetRef ref, String otherUid) {
    final myUid = ref.read(authStateProvider).value?.uid;
    if (myUid == null) return;
    unawaited(
      ref
          .read(friendshipRepositoryProvider)
          .remove(viewerUid: myUid, otherUid: otherUid),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(uid));

    return switch (profile) {
      AsyncData(value: final PublicProfile p) => FriendTile(
        profile: p,
        subtitle: subtitle,
        // Block and report sit beside the friendship action rather than inside
        // it: they are available at every stage of a relationship, including on
        // an incoming request from someone you have never accepted — which is
        // exactly the case they most need to cover.
        // Compact on purpose: a list row fits about one button plus an
        // overflow. Decline moves into the menu for incoming requests so the
        // handle is not squeezed out of its own row.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FriendActionButton(
              otherUid: uid,
              handle: p.handle,
              compact: true,
            ),
            SafetyMenu(
              otherUid: uid,
              handle: p.handle,
              onDecline: incoming ? () => _decline(ref, uid) : null,
            ),
          ],
        ),
      ),
      // A friendship whose public profile will not resolve still gets a row.
      //
      // It used to render nothing, which left the section heading counting a
      // request the user could not see, accept, decline, or make go away. The
      // rules now require a requester to have a public profile, so this should
      // only happen on a transient read failure — but "should only happen" is
      // not a reason to leave someone with a badge they cannot clear.
      AsyncData(value: null) || AsyncError() => _Unresolved(uid: uid),
      _ => const ListTile(
        leading: SizedBox(
          height: AuraTouch.minTarget,
          width: AuraTouch.minTarget,
        ),
        title: Text('…'),
      ),
    };
  }
}

/// Someone whose public profile could not be read. Always dismissible.
class _Unresolved extends ConsumerWidget {
  const _Unresolved({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      minVerticalPadding: AuraSpacing.md,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.sm,
        vertical: AuraSpacing.xs,
      ),
      leading: const SizedBox(
        height: AuraTouch.minTarget,
        width: AuraTouch.minTarget,
        child: Icon(Icons.person_off_outlined),
      ),
      title: Text('someone', style: AuraType.bodyStrong),
      subtitle: Text(
        'this account could not be loaded',
        style: AuraType.caption.copyWith(color: AuraColors.textMuted),
      ),
      // Not `FriendActionButton` — that widget's states all assume a resolved
      // profile. Removal is the only action that makes sense here, and it is the
      // one that unsticks the list.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AuraTouch.minTarget),
        child: OutlinedButton(
          onPressed: () {
            final myUid = ref.read(authStateProvider).value?.uid;
            if (myUid == null) return;
            unawaited(
              ref
                  .read(friendshipRepositoryProvider)
                  .remove(viewerUid: myUid, otherUid: uid),
            );
          },
          child: const Text('remove'),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpacing.sm,
        AuraSpacing.md,
        AuraSpacing.sm,
        AuraSpacing.sm,
      ),
      child: Text(
        text,
        style: AuraType.label.copyWith(color: AuraColors.textMuted),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.me});

  final AuraUser? me;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'no friends yet.',
              style: AuraType.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpacing.md),
            // An empty state that tells someone what to do, per spec §6.7.
            // Showing a bare "nothing here" to the very first user of a social
            // app is the one moment it is guaranteed to be wrong.
            Text(
              me == null
                  ? 'add someone by their handle to get started.'
                  : 'share your handle ${me!.handle}, or add someone by theirs.',
              style: AuraType.bodySmall.copyWith(color: AuraColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'could not load your friends.',
              style: AuraType.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpacing.md),
            // The raw error is deliberately not shown. A FirebaseException's
            // toString carries the project id, the exact query shape and a
            // console URL for creating the missing index — a free map of the
            // backend for anyone who decompiles the app and triggers it.
            Text(
              'check your connection and try again.',
              style: AuraType.bodySmall.copyWith(color: AuraColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
