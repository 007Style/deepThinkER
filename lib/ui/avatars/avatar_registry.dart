// Plugin registry for deepThink avatar widgets.
//
// [AvatarRegistry] decouples the conversation UI from any specific avatar
// implementation. New avatar types can be registered at any time; the default
// Energy Orb type is registered by [registerDefaults].
//
// Usage at app startup:
//   AvatarRegistry.registerDefaults();
//
// Building an avatar:
//   AvatarRegistry.build(
//     'energyOrb',
//     state: AvatarState.thinking,
//     characterName: 'NOVA',
//   );
import 'package:flutter/widgets.dart';

import 'avatar_widget.dart';
import 'energy_orb/energy_orb_avatar.dart';

// ---------------------------------------------------------------------------
// AvatarBuilder typedef
// ---------------------------------------------------------------------------

/// Signature for a factory function that produces an [AvatarWidget].
typedef AvatarBuilder = AvatarWidget Function({
  required AvatarState state,
  required String characterName,
  double size,
  Key? key,
});

// ---------------------------------------------------------------------------
// AvatarRegistry
// ---------------------------------------------------------------------------

/// Lightweight registry mapping avatar-type strings to [AvatarBuilder]s.
///
/// All methods are static — there is no need to instantiate this class.
class AvatarRegistry {
  AvatarRegistry._(); // prevent instantiation

  static final Map<String, AvatarBuilder> _registry = {};

  // -------------------------------------------------------------------------
  // Registration
  // -------------------------------------------------------------------------

  /// Registers [builder] under [type].
  ///
  /// Overwrites any previously registered builder for the same [type].
  static void register(String type, AvatarBuilder builder) {
    _registry[type] = builder;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  /// Builds and returns an avatar of [type].
  ///
  /// Throws [ArgumentError] if [type] has not been registered.
  static AvatarWidget build(
    String type, {
    required AvatarState state,
    required String characterName,
    double size = 80.0,
    Key? key,
  }) {
    final builder = _registry[type];
    if (builder == null) {
      throw ArgumentError(
        'No avatar builder registered for type "$type". '
        'Call AvatarRegistry.register() or AvatarRegistry.registerDefaults() first.',
      );
    }
    return builder(
      state: state,
      characterName: characterName,
      size: size,
      key: key,
    );
  }

  // -------------------------------------------------------------------------
  // Defaults
  // -------------------------------------------------------------------------

  /// Registers the built-in avatar types.
  ///
  /// Currently registers:
  /// - `'energyOrb'` → [EnergyOrbAvatar]
  ///
  /// Call this once at app startup, e.g. in `main()` before `runApp`.
  static void registerDefaults() {
    register(
      'energyOrb',
      ({
        required AvatarState state,
        required String characterName,
        double size = 80.0,
        Key? key,
      }) =>
          EnergyOrbAvatar(
            state: state,
            characterName: characterName,
            size: size,
            key: key,
          ),
    );
  }
}
