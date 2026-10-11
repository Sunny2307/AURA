import 'package:flutter/widgets.dart';

/// Durations and curves, from spec section 6.5.
///
/// The spec is specific that score changes must *animate*, never hard-cut, and
/// that the orb is always subtly breathing. Both are encoded here so no screen
/// invents its own timing.
///
/// **Every animation in the app must check [prefersReducedMotion] first.** The
/// orb pulses forever by default; for someone with vestibular sensitivity, or
/// on a phone in battery saver, a permanently moving element is a real problem.
abstract final class AuraMotion {
  /// Score count-up / count-down. Spec: 0.6–1s. 800ms sits in the middle and
  /// reads as deliberate without feeling slow.
  static const scoreCount = Duration(milliseconds: 800);

  /// One full orb breath in, or out. A ~3s round trip is calm enough to read as
  /// breathing rather than throbbing.
  static const orbBreath = Duration(milliseconds: 1500);

  /// Tap feedback — button scales down slightly.
  static const press = Duration(milliseconds: 120);

  /// Standard element enter/exit.
  static const short = Duration(milliseconds: 200);

  /// Page transitions and sheets.
  static const medium = Duration(milliseconds: 300);

  /// Particle burst on a positive send.
  static const burst = Duration(milliseconds: 900);

  /// Score numbers should feel "bouncy and alive" (spec 6.3) — a slight
  /// overshoot does that without the cartoonish wobble of `elasticOut`.
  static const scoreCurve = Curves.easeOutBack;

  /// Breathing is symmetric, so ease in *and* out.
  static const breathCurve = Curves.easeInOut;

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// True when the OS has been told to reduce motion, or the platform has
  /// otherwise disabled animations.
  ///
  /// Widgets that loop forever (the orb) should stop entirely; widgets that
  /// animate once (score count-up) should jump to their final value rather than
  /// tween, because a score that silently changes is worse than one that snaps.
  static bool prefersReducedMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Collapses a duration to zero when reduced motion is on, so a single call
  /// site can stay declarative.
  static Duration respecting(BuildContext context, Duration duration) =>
      prefersReducedMotion(context) ? Duration.zero : duration;
}
