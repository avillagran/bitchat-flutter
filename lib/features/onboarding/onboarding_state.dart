/// Onboarding state machine matching Android implementation.
/// Defines all states in the permission/setup flow.
enum OnboardingState {
  /// Initial state - checking what permissions are needed
  checking,

  /// Checking if Bluetooth is enabled
  bluetoothCheck,

  /// Checking if Location is enabled (required for BLE on Android)
  locationCheck,

  /// Checking battery optimization settings
  batteryOptimizationCheck,

  /// Showing explanation screen before requesting permissions
  permissionExplanation,

  /// Explaining background location permission
  backgroundLocationExplanation,

  /// Actually requesting permissions from the OS
  permissionRequesting,

  /// Initializing the mesh service
  initializing,

  /// Onboarding complete, ready to use app
  complete,

  /// Error state - something went wrong
  error,
}

/// Extension methods for OnboardingState
extension OnboardingStateExtension on OnboardingState {
  /// Returns true if this is a terminal state
  bool get isTerminal =>
      this == OnboardingState.complete || this == OnboardingState.error;

  /// Returns true if the UI should show a loading indicator
  bool get isLoading =>
      this == OnboardingState.checking ||
      this == OnboardingState.permissionRequesting ||
      this == OnboardingState.initializing;

  /// Returns the next state in the flow (for automatic transitions)
  OnboardingState? get nextState {
    switch (this) {
      case OnboardingState.checking:
        return OnboardingState.bluetoothCheck;
      case OnboardingState.bluetoothCheck:
        return OnboardingState.locationCheck;
      case OnboardingState.locationCheck:
        return OnboardingState.batteryOptimizationCheck;
      case OnboardingState.batteryOptimizationCheck:
        return OnboardingState.permissionExplanation;
      case OnboardingState.permissionExplanation:
        return OnboardingState.permissionRequesting;
      case OnboardingState.permissionRequesting:
        return OnboardingState.initializing;
      case OnboardingState.initializing:
        return OnboardingState.complete;
      default:
        return null;
    }
  }

  /// Human-readable description
  String get description {
    switch (this) {
      case OnboardingState.checking:
        return 'Checking requirements...';
      case OnboardingState.bluetoothCheck:
        return 'Checking Bluetooth...';
      case OnboardingState.locationCheck:
        return 'Checking Location...';
      case OnboardingState.batteryOptimizationCheck:
        return 'Checking battery settings...';
      case OnboardingState.permissionExplanation:
        return 'Permission explanation';
      case OnboardingState.backgroundLocationExplanation:
        return 'Background location';
      case OnboardingState.permissionRequesting:
        return 'Requesting permissions...';
      case OnboardingState.initializing:
        return 'Starting mesh...';
      case OnboardingState.complete:
        return 'Ready';
      case OnboardingState.error:
        return 'Error';
    }
  }
}
