// Re-exports [ModelStatus] so main.dart can import it without reaching
// into model_manager.dart (which also exports ModelPullProgress).

export 'model_manager.dart' show ModelStatus;
