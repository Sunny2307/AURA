import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../shared/widgets/aura_wordmark.dart';
import '../../../shared/widgets/aura_identity.dart';
import '../../../core/theme/aura_motion.dart';
import '../../../prototype/prototype_panel.dart';
import 'onboarding_art.dart';

/// The four swipeable screens from spec §5.2, with copy from §7.4.
///
/// The headline strings are **verbatim from §7.4** and should stay that way.
/// They were written to be read aloud in a group chat, and paraphrasing them —
/// "or hide it" for "or keep it private" — loses the rhythm that makes them
/// land. If the copy needs to change, change it in the spec first.
///
/// Every illustration comes from [OnboardingOrbArt] and friends, which are built
/// out of the real `AuraOrb` / `AuraCard` / `AuraPoints` widgets. Drawing
/// onboarding-only visuals here would mean the pitch and the product drift apart
/// silently, one theme tweak at a time.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.showPrototype = false});
  final bool showPrototype;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _page = 0;

  /// §7.4 copy. `title` is the hook, `body` the payoff — split across two lines
  /// because a single 60-character sentence at `headingLarge` wraps badly on a
  /// small phone.
  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      title: 'your friends already judge you.',
      body: "now it's official.",
      visual: OnboardingOrbArt(),
    ),
    _OnboardingPage(
      title: 'send aura for the wins.',
      body: 'take it for the fails.',
      visual: OnboardingTransactionArt(),
    ),
    _OnboardingPage(
      title: 'flex your score.',
      body: 'or keep it private. your call.',
      visual: OnboardingPrivacyArt(),
    ),
    // §5.2 frames the last screen around permissions "casually". The permission
    // is not *requested* here — see the note on [OnboardingFriendsArt]. This
    // page only sets the expectation, so a later system dialog is not a surprise.
    _OnboardingPage(
      title: "let's find your friends already on aura",
      body: "we'll tell you the second someone takes your aura.",
      visual: OnboardingFriendsArt(),
    ),
  ];

  Duration get _pageTurn =>
      AuraMotion.respecting(context, const Duration(milliseconds: 320));

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _page == _pages.length - 1;

  void _next() {
    if (_isLastPage) {
      // push, not replace: someone who taps "get started" and then thinks better
      // of it can back out to the pitch rather than into a dead end.
      unawaited(context.push(AuraRoutes.signup));
      return;
    }
    if (_pageTurn == Duration.zero) {
      _pageController.jumpToPage(_page + 1);
      return;
    }
    unawaited(
      _pageController.nextPage(duration: _pageTurn, curve: Curves.easeOutCubic),
    );
  }

  void _previous() {
    if (_pageTurn == Duration.zero) {
      _pageController.jumpToPage(_page - 1);
      return;
    }
    unawaited(
      _pageController.previousPage(
        duration: _pageTurn,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Lets someone who has seen the pitch get straight to signup. Hidden on the
  /// last page, where the primary button already does exactly this.
  void _skip() {
    unawaited(context.push(AuraRoutes.signup));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.screenPadding,
            AuraSpacing.lg,
            AuraSpacing.screenPadding,
            AuraSpacing.md,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AuraWordmark(size: 28),
                  // Reserves its own space when hidden so the wordmark does not
                  // shift sideways on the last page.
                  Visibility(
                    visible: !_isLastPage,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      onPressed: _skip,
                      child: const Text('skip'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpacing.lg),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) => _pages[index],
                ),
              ),
              _PageDots(count: _pages.length, current: _page),
              const SizedBox(height: AuraSpacing.lg),
              if (widget.showPrototype) ...[
                const PrototypePanel(compact: true),
                TextButton(
                  onPressed: () =>
                      AppRouter.pushTo(context, AuraRoutes.localAccounts),
                  child: const Text('return to a saved account'),
                ),
                const SizedBox(height: 12),
              ],
              // Primary action sits at the bottom, inside the thumb's natural
              // arc on a phone held one-handed.
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLastPage ? 'get started' : 'next'),
                ),
              ),
              const SizedBox(height: AuraSpacing.sm),
              SizedBox(
                height: AuraTouch.minTarget,
                child: TextButton(
                  // Disabled rather than hidden: a control that vanishes moves
                  // everything below it, and this row is next to the main CTA.
                  onPressed: _page == 0 ? null : _previous,
                  child: const Text('back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page indicator.
///
/// One [Semantics] node for the whole row rather than one per dot. Announcing
/// four separate "onboarding page N" nodes makes a screen-reader user swipe
/// through decoration to reach the buttons; "page 2 of 4" is the actual fact.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'page ${current + 1} of $count',
      container: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < count; index++)
              AnimatedContainer(
                duration: AuraMotion.respecting(
                  context,
                  const Duration(milliseconds: 200),
                ),
                width: index == current ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == current
                      ? AuraColors.action
                      : AuraColors.neutral,
                  borderRadius: AuraRadius.pillAll,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.visual,
  });

  final String title;
  final String body;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    // Scrollable because the art is a fixed 260px and a large system font size
    // can push the two lines of copy past the bottom of a short screen.
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            height: 250 * MediaQuery.textScalerOf(context).scale(16) / 16,
            width: double.infinity,
            decoration: BoxDecoration(
              color: visual is OnboardingOrbArt
                  ? AuraColors.lilac
                  : visual is OnboardingTransactionArt
                  ? AuraColors.peach
                  : AuraColors.lime,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AuraColors.surfaceBorder),
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: 20,
                  left: 20,
                  child: AuraEyebrow('the aura effect'),
                ),
                Center(child: visual),
                const Positioned(
                  top: 54,
                  right: 22,
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AuraColors.action,
                      size: 32,
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 16,
                  right: 20,
                  child: Icon(
                    Icons.north_east_rounded,
                    color: AuraColors.action,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpacing.xl),
          Text(title, textAlign: TextAlign.left, style: AuraType.headingLarge),
          const SizedBox(height: AuraSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.left,
            style: AuraType.body.copyWith(color: AuraColors.textMuted),
          ),
        ],
      ),
    );
  }
}
