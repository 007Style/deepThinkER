// Per-character configuration for the Energy Orb avatar.
//
// Each [OrbConfig] captures the color palette and animation personality
// that make each deepThink character visually distinct.
import 'package:flutter/painting.dart';

// ---------------------------------------------------------------------------
// OrbConfig
// ---------------------------------------------------------------------------

/// Immutable configuration bundle for one character's Energy Orb.
class OrbConfig {
  /// The dominant orb color (center of radial gradient).
  final Color primaryColor;

  /// Accent color used for the outer gradient band and glow ring.
  final Color secondaryColor;

  /// Bloom / glow color (usually a lighter, more saturated variant).
  final Color glowColor;

  /// Multiplier applied to base particle travel speed.
  ///
  /// Values > 1.0 produce faster particles; values < 1.0 slow them down.
  final double particleSpeed;

  /// Multiplier applied to the base orbit-frequency (angular velocity).
  ///
  /// Higher values make particles orbit the center more rapidly.
  final double swirlFrequency;

  /// The participant name this config belongs to (e.g. `"WATSON"`).
  final String characterName;

  /// Creates an [OrbConfig].
  const OrbConfig({
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
    required this.particleSpeed,
    required this.swirlFrequency,
    required this.characterName,
  });

  // -------------------------------------------------------------------------
  // Static per-character configs
  // -------------------------------------------------------------------------

  /// WATSON — cool electric blue, steady precise pulses.
  ///
  /// Conveys analytical clarity: clean lines, regular cadence.
  static const OrbConfig watson = OrbConfig(
    characterName: 'WATSON',
    primaryColor: Color(0xFF1E90FF),
    secondaryColor: Color(0xFF00BFFF),
    glowColor: Color(0xFF87CEFA),
    particleSpeed: 1.0,
    swirlFrequency: 1.0,
  );

  /// DEEP — rich deep purple, slow philosophical swirl.
  ///
  /// Conveys contemplative depth: unhurried, weighty rotations.
  static const OrbConfig deep = OrbConfig(
    characterName: 'DEEP',
    primaryColor: Color(0xFF7B2FBE),
    secondaryColor: Color(0xFF9B59B6),
    glowColor: Color(0xFFCB9EFF),
    particleSpeed: 0.65,
    swirlFrequency: 0.6,
  );

  /// NOVA — vivid orange, expanding outward bursts.
  ///
  /// Conveys energetic vision: fast, outward-rushing, radiant.
  static const OrbConfig nova = OrbConfig(
    characterName: 'NOVA',
    primaryColor: Color(0xFFFF6B00),
    secondaryColor: Color(0xFFFFAA00),
    glowColor: Color(0xFFFFD080),
    particleSpeed: 1.5,
    swirlFrequency: 1.6,
  );

  /// SAGE — sharp crimson / red, crackling spark energy.
  ///
  /// Conveys provocative challenge: jagged, intense, high-contrast.
  static const OrbConfig sage = OrbConfig(
    characterName: 'SAGE',
    primaryColor: Color(0xFFDC143C),
    secondaryColor: Color(0xFFFF4500),
    glowColor: Color(0xFFFF8070),
    particleSpeed: 1.3,
    swirlFrequency: 1.4,
  );

  /// Returns the [OrbConfig] matching [name] (case-insensitive).
  ///
  /// Falls back to [watson] if the name is not recognised.
  static OrbConfig forCharacter(String name) {
    switch (name.toUpperCase()) {
      case 'WATSON':
        return watson;
      case 'DEEP':
        return deep;
      case 'NOVA':
        return nova;
      case 'SAGE':
        return sage;
      default:
        return watson;
    }
  }
}
