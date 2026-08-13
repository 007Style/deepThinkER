/// MotionPolicyScope — InheritedWidget that propagates AnimationPolicy down
/// the widget tree.
library motion_policy;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AnimationPolicy
// ---------------------------------------------------------------------------

/// Controls the level of animation throughout the UI.
enum AnimationPolicy {
  /// Full animations — the default experience.
  full,

  /// Reduced motion — transitions use instant or near-instant durations
  /// to support users with vestibular disorders or motion sensitivity.
  reduced,
}

// ---------------------------------------------------------------------------
// MotionPolicyScope
// ---------------------------------------------------------------------------

/// An [InheritedWidget] that exposes an [AnimationPolicy] to all descendants.
///
/// Wrap the app (or a sub-tree) with [MotionPolicyScope] to control motion.
///
/// ```dart
/// MotionPolicyScope(
///   policy: settings.reducedMotionMode
///       ? AnimationPolicy.reduced
///       : AnimationPolicy.full,
///   child: const MyApp(),
/// )
/// ```
class MotionPolicyScope extends InheritedWidget {
  /// The animation policy for this sub-tree.
  final AnimationPolicy policy;

  const MotionPolicyScope({
    super.key,
    required this.policy,
    required super.child,
  });

  /// Returns the nearest [AnimationPolicy] from the widget tree.
  ///
  /// Falls back to [AnimationPolicy.full] when no [MotionPolicyScope] is found.
  static AnimationPolicy of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MotionPolicyScope>();
    return scope?.policy ?? AnimationPolicy.full;
  }

  /// Whether reduced motion is active in [context].
  static bool isReduced(BuildContext context) =>
      of(context) == AnimationPolicy.reduced;

  @override
  bool updateShouldNotify(MotionPolicyScope oldWidget) =>
      policy != oldWidget.policy;
}
