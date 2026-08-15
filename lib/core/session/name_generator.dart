// Fun lowerCamelCase session name generator for deepThink.
//
// Produces names of the form `[adjective][Noun]` — e.g. `thetaByte`,
// `thorKitten`, `lateralPerception`.
//
// This file has zero Flutter imports — pure Dart only.

import 'dart:math';

// ---------------------------------------------------------------------------
// Word lists
// ---------------------------------------------------------------------------

const List<String> _adjectives = [
  'quantum',
  'neural',
  'cosmic',
  'stellar',
  'atomic',
  'digital',
  'binary',
  'photon',
  'vector',
  'delta',
  'theta',
  'lambda',
  'sigma',
  'orbital',
  'sonic',
  'kinetic',
  'fractal',
  'cryptic',
  'nebula',
  'plasma',
  'helix',
  'cipher',
  'apex',
  'zenith',
  'cobalt',
  'vertex',
  'axiom',
  'tangent',
  'prism',
  'flux',
  'lateral',
  'radiant',
  'vortex',
];

const List<String> _nouns = [
  'byte',
  'kitten',
  'falcon',
  'thunder',
  'prism',
  'echo',
  'vortex',
  'pixel',
  'comet',
  'spark',
  'cipher',
  'matrix',
  'nexus',
  'beacon',
  'pulse',
  'quark',
  'titan',
  'nova',
  'forge',
  'ember',
  'drift',
  'phantom',
  'zenith',
  'specter',
  'axiom',
  'catalyst',
  'synapse',
  'horizon',
  'torrent',
  'signal',
  'orbit',
  'perception',
];

// ---------------------------------------------------------------------------
// NameGenerator
// ---------------------------------------------------------------------------

/// Generates fun lowerCamelCase two-word session names from curated word lists.
///
/// Format: `[adjective][Noun]` where the adjective is lowercase and the noun
/// has its first letter capitalised — e.g. `thetaByte`, `fractalSynapse`.
class NameGenerator {
  final Random _rng;

  /// Creates a [NameGenerator].
  ///
  /// Supply a [Random] instance for deterministic testing; leave null for a
  /// cryptographically seeded generator.
  NameGenerator({Random? random}) : _rng = random ?? Random.secure();

  /// Generates a single random lowerCamelCase session name.
  ///
  /// Example output: `quantumFalcon`, `helixPulse`, `cobaltSynapse`.
  String generate() {
    final adj = _adjectives[_rng.nextInt(_adjectives.length)];
    final noun = _nouns[_rng.nextInt(_nouns.length)];
    final capitalised = noun[0].toUpperCase() + noun.substring(1);
    return '$adj$capitalised';
  }

  /// Generates a name that is not already in [existingNames].
  ///
  /// Keeps generating candidates until a unique one is found.
  /// In the unlikely event that all combinations are exhausted the loop will
  /// still terminate because it appends a numeric suffix after 200 attempts.
  String generateUnique(Set<String> existingNames) {
    for (var attempt = 0; attempt < 200; attempt++) {
      final candidate = generate();
      if (!existingNames.contains(candidate)) return candidate;
    }
    // Fallback: append timestamp millis to guarantee uniqueness.
    return '${generate()}${DateTime.now().millisecondsSinceEpoch}';
  }
}
