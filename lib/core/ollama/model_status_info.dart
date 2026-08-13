/// Re-exports [ModelStatus] so main.dart can import it without reaching
/// into model_manager.dart (which also exports ModelPullProgress).
library model_status_info;

export 'model_manager.dart' show ModelStatus;
