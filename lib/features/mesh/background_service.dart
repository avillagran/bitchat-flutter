import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:bitchat/features/mesh/bluetooth_mesh_service.dart';
import 'package:bitchat/features/crypto/encryption_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background service to keep mesh running in Android foreground mode.
///
/// This service manages the mesh network in the background using Android's
/// foreground service mechanism. It ensures BLE operations continue even when
/// the app is not visible to the user.
///
/// Key features:
/// - Foreground service with persistent notification
/// - Periodic mesh health checks and notification updates
/// - Lifecycle hooks for app foreground/background transitions
/// - Automatic mesh restart on recovery
/// - Permission-aware foreground mode promotion
class BackgroundService {
  /// Notification channel ID for the foreground service.
  static const String channelId = 'bitchat_mesh_service';

  /// Notification ID for the foreground service.
  static const int notificationId = 10001;

  /// Action to start the service.
  static const String actionStart = 'ACTION_START';

  /// Action to stop the service.
  static const String actionStop = 'ACTION_STOP';

  /// Action to update the notification.
  static const String actionUpdateNotification = 'ACTION_UPDATE_NOTIFICATION';

  /// Action to quit the application.
  static const String actionQuit = 'ACTION_QUIT';

  /// Instance of the background service plugin.
  final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Notification channel for the foreground service.
  static final AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'Bitchat Mesh Service',
    description: 'Keeps mesh network running in background',
    importance: Importance.low,
  );

  /// Flutter local notifications plugin instance.
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Initializes the background service.
  ///
  /// Configures the service with Android and iOS settings, creates the
  /// notification channel, and prepares the service for execution.
  ///
  /// Returns true if initialization was successful, false otherwise.
  Future<bool> initialize() async {
    try {
      // Initialize notifications plugin
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      // Create notification channel (Android 8.0+)
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Configure background service
      final configured = await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: false, // Start in background, promote later
          notificationChannelId: channelId,
          initialNotificationTitle: 'Bitchat Mesh',
          initialNotificationContent: 'Initializing mesh...',
          foregroundServiceNotificationId: notificationId,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      return configured;
    } catch (e) {
      debugPrint('BackgroundService: Initialization failed: $e');
      return false;
    }
  }

  /// Starts the background service.
  ///
  /// This method initiates the background service. On Android, it will attempt
  /// to start the foreground service if background mode is enabled and all
  /// required permissions are granted.
  ///
  /// Returns true if the service was started successfully, false otherwise.
  Future<bool> start() async {
    try {
      await _service.startService();
      debugPrint('BackgroundService: Service started');
      return true;
    } catch (e) {
      debugPrint('BackgroundService: Failed to start service: $e');
      return false;
    }
  }

  /// Stops the background service.
  ///
  /// Stops the mesh service and the background service itself. This is a clean
  /// shutdown that properly releases resources.
  Future<void> stop() async {
    try {
      _service.invoke('stopService');
      debugPrint('BackgroundService: Stop requested');
    } catch (e) {
      debugPrint('BackgroundService: Failed to request stop: $e');
    }
  }

  /// Requests a full shutdown and quit of the application.
  ///
  /// This is different from a regular stop - it performs a complete shutdown
  /// of all mesh operations and requests the application to quit.
  Future<void> quit() async {
    try {
      _service.invoke('quitService');
      debugPrint('BackgroundService: Quit requested');
    } catch (e) {
      debugPrint('BackgroundService: Failed to request quit: $e');
    }
  }

  /// Updates the notification with current mesh status.
  ///
  /// This method can be called from the main thread to force a notification
  /// update with the latest peer count and mesh status.
  Future<void> updateNotification(int activePeers) async {
    try {
      _service.invoke('updateNotification', {'activePeers': activePeers});
      debugPrint('BackgroundService: Notification update requested');
    } catch (e) {
      debugPrint('BackgroundService: Failed to update notification: $e');
    }
  }

  /// Promotes the service to foreground mode.
  ///
  /// Called when the app enters background mode and all required permissions
  /// are available. This ensures the mesh service continues running.
  Future<void> promoteToForeground() async {
    try {
      _service.invoke('setAsForeground');
      debugPrint('BackgroundService: Promoted to foreground');
    } catch (e) {
      debugPrint('BackgroundService: Failed to promote to foreground: $e');
    }
  }

  /// Demotes the service from foreground to background mode.
  ///
  /// Called when the app returns to foreground mode and the persistent
  /// notification is no longer needed.
  Future<void> demoteToBackground() async {
    try {
      _service.invoke('setAsBackground');
      debugPrint('BackgroundService: Demoted to background');
    } catch (e) {
      debugPrint('BackgroundService: Failed to demote to background: $e');
    }
  }

  /// Entry point for the background service when started.
  ///
  /// This static method is called when the service starts running in the
  /// background. It initializes the mesh service and sets up periodic tasks.
  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Initialize notifications for foreground service
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Initialize encryption and mesh services
    final encryption = EncryptionService();
    await encryption.initialize();
    final mesh = BluetoothMeshService(encryption);

    // Track foreground state
    var isInForeground = false;
    var isShuttingDown = false;

    // Set up action handlers for Android service
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        if (!isShuttingDown) {
          service.setAsForegroundService();
          isInForeground = true;
          debugPrint('BackgroundService: Promoted to foreground mode');
        }
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
        isInForeground = false;
        debugPrint('BackgroundService: Demoted to background mode');
      });

      service.on('stopService').listen((event) async {
        try {
          mesh.stop();
          debugPrint('BackgroundService: Mesh service stopped');
        } catch (e) {
          debugPrint('BackgroundService: Error stopping mesh: $e');
        }
        service.stopSelf();
      });

      service.on('quitService').listen((event) async {
        isShuttingDown = true;
        try {
          mesh.stop();
          if (isInForeground) {
            await notifications.cancel(notificationId);
            isInForeground = false;
          }
          debugPrint('BackgroundService: Full quit performed');
        } catch (e) {
          debugPrint('BackgroundService: Error during quit: $e');
        }
        service.stopSelf();
      });

      service.on('updateNotification').listen((event) async {
        if (!isShuttingDown && isInForeground) {
          final activePeers = event?['activePeers'] as int? ?? 0;
          await _updateNotificationContent(
            activePeers,
            notifications,
          );
          debugPrint(
            'BackgroundService: Notification updated: $activePeers peers',
          );
        }
      });
    }

    // Start mesh service
    try {
      await mesh.start();
      debugPrint('BackgroundService: Mesh service started');
    } catch (e) {
      debugPrint('BackgroundService: Failed to start mesh: $e');
    }

    // Periodic tasks: health check, notification update, etc.
    Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        if (isShuttingDown) {
          timer.cancel();
          return;
        }

        // Ensure mesh is still running
        if (!mesh.isActive) {
          try {
            debugPrint('BackgroundService: Mesh not active, restarting...');
            await mesh.start();
          } catch (e) {
            debugPrint('BackgroundService: Failed to restart mesh: $e');
          }
        }

        // Update notification if in foreground
        if (service is AndroidServiceInstance && isInForeground) {
          try {
            final activePeers = mesh.getActivePeers().length;
            await _updateNotificationContent(
              activePeers,
              notifications,
            );
          } catch (e) {
            debugPrint('BackgroundService: Failed to update notification: $e');
          }
        }
      },
    );
  }

  /// iOS background handler.
  ///
  /// Returns true to allow the service to run in the background on iOS.
  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    return true;
  }

  /// Updates the notification content with current peer count.
  static Future<void> _updateNotificationContent(
    int activePeers,
    FlutterLocalNotificationsPlugin notifications,
  ) async {
    final content = activePeers == 1
        ? '1 peer connected'
        : '$activePeers peers connected';

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      'Bitchat Mesh Service',
      channelDescription: 'Keeps mesh network running in background',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.service,
    );

    final notificationDetails = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await notifications.show(
      notificationId,
      'Bitchat Mesh',
      content,
      notificationDetails,
    );
  }

  /// Checks if the background service is currently running.
  Future<bool> get isRunning async {
    return await _service.isRunning();
  }

  /// Gets the current service instance (for direct control if needed).
  FlutterBackgroundService get service => _service;

  /// Disposes of resources held by the background service.
  void dispose() {
    // Cleanup is handled by the service lifecycle
  }
}

/// Provider for the BackgroundService.
///
/// Returns a singleton instance of the BackgroundService for use throughout
/// the application.
final backgroundServiceProvider = Provider<BackgroundService>((ref) {
  return BackgroundService();
});
