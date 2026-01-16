import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitchat/features/onboarding/onboarding_coordinator.dart';
import 'package:bitchat/features/onboarding/onboarding_state.dart';
import 'package:bitchat/ui/theme/bitchat_colors.dart';

/// Main onboarding screen that displays different content based on state.
/// Matches Android's onboarding flow with multiple check screens.
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    // Start onboarding flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coordinator = ref.read(onboardingCoordinatorProvider);
      coordinator.onOnboardingComplete = widget.onComplete;
      coordinator.startOnboarding();
    });
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(onboardingCoordinatorProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: _buildContent(coordinator, colorScheme),
      ),
    );
  }

  Widget _buildContent(
    OnboardingCoordinator coordinator,
    ColorScheme colorScheme,
  ) {
    switch (coordinator.state) {
      case OnboardingState.checking:
        return _buildCheckingScreen(colorScheme);
      case OnboardingState.bluetoothCheck:
        return _buildBluetoothCheckScreen(coordinator, colorScheme);
      case OnboardingState.locationCheck:
        return _buildLocationCheckScreen(coordinator, colorScheme);
      case OnboardingState.batteryOptimizationCheck:
        return _buildBatteryOptimizationScreen(coordinator, colorScheme);
      case OnboardingState.permissionExplanation:
        return _buildPermissionExplanationScreen(coordinator, colorScheme);
      case OnboardingState.backgroundLocationExplanation:
        return _buildBackgroundLocationScreen(coordinator, colorScheme);
      case OnboardingState.permissionRequesting:
        return _buildRequestingScreen(colorScheme);
      case OnboardingState.initializing:
        return _buildInitializingScreen(colorScheme);
      case OnboardingState.complete:
        return _buildCompleteScreen(colorScheme);
      case OnboardingState.error:
        return _buildErrorScreen(coordinator, colorScheme);
    }
  }

  /// Initial checking screen
  Widget _buildCheckingScreen(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'bitchat',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Checking requirements...',
            style: TextStyle(
              color: colorScheme.primary.withOpacity(0.7),
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Bluetooth check screen
  Widget _buildBluetoothCheckScreen(
    OnboardingCoordinator coordinator,
    ColorScheme colorScheme,
  ) {
    final status = coordinator.bluetoothStatus;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Bluetooth icon
          Icon(
            status == BluetoothStatus.enabled
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
            size: 64,
            color: status == BluetoothStatus.enabled
                ? BitchatColors.primaryGreen
                : colorScheme.error,
          ),
          const SizedBox(height: 24),

          Text(
            status == BluetoothStatus.notSupported
                ? 'Bluetooth Not Supported'
                : 'Bluetooth Required',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Explanation card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'bitchat needs Bluetooth for:',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '- Discovering nearby devices\n'
                  '- Sending and receiving messages\n'
                  '- Creating a mesh network',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.8),
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (status == BluetoothStatus.disabled) ...[
            // Enable Bluetooth button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: coordinator.requestEnableBluetooth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BitchatColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Enable Bluetooth',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else if (status == BluetoothStatus.notSupported) ...[
            // Not supported message
            Text(
              'This device does not support Bluetooth LE, '
              'which is required for bitchat to work.',
              style: TextStyle(
                color: colorScheme.error,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            // Loading while checking
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  /// Location check screen
  Widget _buildLocationCheckScreen(
    OnboardingCoordinator coordinator,
    ColorScheme colorScheme,
  ) {
    final status = coordinator.locationStatus;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            status == LocationStatus.enabled
                ? Icons.location_on
                : Icons.location_off,
            size: 64,
            color: status == LocationStatus.enabled
                ? BitchatColors.primaryGreen
                : colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            'Location Required',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Android requires location permission for Bluetooth scanning. '
              'bitchat does not track your location.',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.8),
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          if (status == LocationStatus.disabled) ...[
            // Continue anyway
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: coordinator.skipLocationCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BitchatColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else ...[
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  /// Battery optimization screen
  Widget _buildBatteryOptimizationScreen(
    OnboardingCoordinator coordinator,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.battery_saver,
            size: 64,
            color: BitchatColors.selfMessageColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Battery Optimization',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'For reliable background mesh operation, '
              'consider disabling battery optimization for bitchat.',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.8),
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          // This is optional, auto-advance after delay
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ],
      ),
    );
  }

  /// Permission explanation screen
  Widget _buildPermissionExplanationScreen(
    OnboardingCoordinator coordinator,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security,
            size: 64,
            color: BitchatColors.primaryGreen,
          ),
          const SizedBox(height: 24),
          Text(
            'Permissions Required',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Permission list
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPermissionItem(
                  Icons.bluetooth,
                  'Bluetooth',
                  'Discover and connect to nearby devices',
                  colorScheme,
                ),
                const SizedBox(height: 12),
                _buildPermissionItem(
                  Icons.location_on,
                  'Location',
                  'Required for Bluetooth scanning (not tracked)',
                  colorScheme,
                ),
                const SizedBox(height: 12),
                _buildPermissionItem(
                  Icons.notifications,
                  'Notifications',
                  'Receive message alerts (optional)',
                  colorScheme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: coordinator.requestPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: BitchatColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Grant Permissions',
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(
    IconData icon,
    String title,
    String description,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(icon, color: BitchatColors.primaryGreen, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Background location explanation
  Widget _buildBackgroundLocationScreen(
    OnboardingCoordinator coordinator,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 64,
            color: BitchatColors.selfMessageColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Background Location',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Background location allows bitchat to maintain mesh connections '
              'even when the app is not in the foreground.',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.8),
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Requesting permissions screen
  Widget _buildRequestingScreen(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_top,
            size: 64,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Requesting Permissions...',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ],
      ),
    );
  }

  /// Initializing mesh screen
  Widget _buildInitializingScreen(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'bitchat',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Starting mesh network...',
            style: TextStyle(
              color: colorScheme.primary.withOpacity(0.7),
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Complete screen (briefly shown before transition)
  Widget _buildCompleteScreen(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: BitchatColors.primaryGreen,
          ),
          const SizedBox(height: 24),
          Text(
            'Ready!',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Error screen
  Widget _buildErrorScreen(
    OnboardingCoordinator coordinator,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            'Setup Failed',
            style: TextStyle(
              color: colorScheme.error,
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (coordinator.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                coordinator.errorMessage!,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: coordinator.retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BitchatColors.primaryGreen,
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: coordinator.openAppSettings,
                child: Text(
                  'Open Settings',
                  style: TextStyle(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
