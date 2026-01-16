import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/crypto/encryption_service.dart';
import 'features/mesh/bluetooth_mesh_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'ui/chat_screen.dart';
import 'ui/theme/bitchat_theme.dart';

/// Key for storing onboarding completion status
const String _onboardingCompleteKey = 'onboarding_complete';

/// Main Bitchat application widget.
/// Provides theme configuration, service initialization, and navigation.
class BitchatApp extends ConsumerStatefulWidget {
  const BitchatApp({super.key});

  @override
  ConsumerState<BitchatApp> createState() => _BitchatAppState();
}

class _BitchatAppState extends ConsumerState<BitchatApp> {
  bool _isCheckingOnboarding = true;
  bool _needsOnboarding = true;
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  /// Check if onboarding has been completed previously.
  Future<void> _checkOnboardingStatus() async {
    try {
      // Initialize Hive for preferences
      await Hive.initFlutter();
      final box = await Hive.openBox<bool>('preferences');
      final onboardingComplete =
          box.get(_onboardingCompleteKey, defaultValue: false) ?? false;

      setState(() {
        _isCheckingOnboarding = false;
        _needsOnboarding = !onboardingComplete;
      });

      // If onboarding was already complete, initialize services
      if (onboardingComplete) {
        await _initializeServices();
      }
    } catch (e) {
      debugPrint('Bitchat: Error checking onboarding status: $e');
      setState(() {
        _isCheckingOnboarding = false;
        _needsOnboarding = true; // Default to showing onboarding on error
      });
    }
  }

  /// Called when onboarding is completed.
  Future<void> _onOnboardingComplete() async {
    try {
      // Save onboarding completion status
      final box = await Hive.openBox<bool>('preferences');
      await box.put(_onboardingCompleteKey, true);

      // Initialize services
      await _initializeServices();

      setState(() {
        _needsOnboarding = false;
      });
    } catch (e) {
      debugPrint('Bitchat: Error completing onboarding: $e');
      setState(() {
        _initError = e.toString();
      });
    }
  }

  /// Initialize encryption and mesh services.
  Future<void> _initializeServices() async {
    try {
      // Initialize encryption service first (generates/loads keys)
      final encryptionService = ref.read(encryptionServiceProvider);
      await encryptionService.initialize();
      debugPrint('Bitchat: Encryption service initialized');

      // Start the mesh service (BLE advertising + scanning)
      final meshService = ref.read(meshServiceProvider);
      final started = await meshService.start();

      if (started) {
        debugPrint('Bitchat: Mesh service started successfully');
      } else {
        debugPrint(
            'Bitchat: Mesh service failed to start (BLE may not be available)');
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e, stackTrace) {
      debugPrint('Bitchat: Initialization error: $e\n$stackTrace');
      setState(() {
        _isInitialized = true; // Still show UI, but with error
        _initError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitchat',
      debugShowCheckedModeBanner: false,

      // Theme configuration - terminal/IRC style
      theme: BitchatTheme.lightTheme,
      darkTheme: BitchatTheme.darkTheme,
      themeMode: ThemeMode.system, // Follow system preference

      // Home screen - show appropriate screen based on state
      home: _buildHomeScreen(),
    );
  }

  Widget _buildHomeScreen() {
    // Still checking onboarding status
    if (_isCheckingOnboarding) {
      return _buildLoadingScreen('Checking setup...');
    }

    // Need to complete onboarding
    if (_needsOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    // Onboarding complete but still initializing services
    if (!_isInitialized) {
      return _buildLoadingScreen('Initializing mesh...');
    }

    // Ready to show chat
    return const ChatScreen();
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'bitchat',
              style: TextStyle(
                color: const Color(0xFF39FF14),
                fontFamily: 'monospace',
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF39FF14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: const Color(0xFF39FF14).withOpacity(0.7),
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
            if (_initError != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Error: $_initError',
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
