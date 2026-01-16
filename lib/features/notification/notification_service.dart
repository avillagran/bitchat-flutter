import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Represents a local notification channel.
enum NotificationChannel {
  meshMessages,
  systemEvents,
  errorAlerts,
}

/// Represents a notification entry for persistence.
@HiveType(typeId: 10)
class NotificationEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String body;

  @HiveField(3)
  final int channelIndex;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final Map<String, dynamic>? payload;

  @HiveField(6)
  final bool isRead;

  NotificationEntry({
    required this.id,
    required this.title,
    required this.body,
    required NotificationChannel channel,
    required this.createdAt,
    this.payload,
    this.isRead = false,
  }) : channelIndex = channel.index;

  /// Gets the notification channel.
  NotificationChannel get channel => NotificationChannel.values[channelIndex];

  /// Creates a NotificationEntry from a notification details object.
  factory NotificationEntry.fromDetails({
    required String id,
    required String title,
    required String body,
    required NotificationChannel channel,
    Map<String, dynamic>? payload,
  }) {
    return NotificationEntry(
      id: id,
      title: title,
      body: body,
      channel: channel,
      createdAt: DateTime.now(),
      payload: payload,
      isRead: false,
    );
  }
}

/// Service for managing local notifications with channel support and persistence.
/// Handles Android/iOS notification APIs via flutter_local_notifications.
/// Provides storage and retrieval of notification history.
class NotificationService {
  // Singleton instance
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Sets a custom notifications plugin instance (for testing).
  @visibleForTesting
  void setPluginForTesting(FlutterLocalNotificationsPlugin plugin) {
    _notificationsPlugin = plugin;
  }

  /// Initializes the service for tests using an already-opened Hive box and a
  /// custom plugin instance. This bypasses channel creation and plugin
  /// initialization which are platform-specific.
  @visibleForTesting
  Future<void> initializeForTest({
    required FlutterLocalNotificationsPlugin plugin,
    required Box<NotificationEntry> notificationsBox,
  }) async {
    _notificationsPlugin = plugin;
    _notificationsBox = notificationsBox;
    _isInitialized = true;
  }

  /// Optional callback to notify when a notification is tapped (testing hook).
  @visibleForTesting
  void Function(String? payload)? onNotificationTappedCallback;

  /// Internal handler for notification payloads.
  void _onNotificationTappedPayload(String? payload) {
    debugPrint(
        'NotificationService: Notification tapped with payload: $payload');
    if (onNotificationTappedCallback != null) {
      try {
        onNotificationTappedCallback!(payload);
      } catch (_) {}
    }
  }

  /// Handles notification responses (internal callback from plugin).
  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    _onNotificationTappedPayload(payload);
  }

  /// Exposed helper to simulate a notification tap in tests.
  @visibleForTesting
  void handleNotificationTapPayload(String? payload) {
    _onNotificationTappedPayload(payload);
  }

  static const String _notificationsBoxName = 'notifications_box';
  static const int _maxStoredNotifications = 100;

  Box<NotificationEntry>? _notificationsBox;
  bool _isInitialized = false;

  /// Checks if the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initializes the notification service.
  /// Sets up platform-specific initialization, time zones, and local channels.
  /// Must be called before using any other methods.
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      // Initialize time zones for scheduled notifications
      tz_data.initializeTimeZones();

      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin
      final bool? initialized = await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized != true) {
        debugPrint('NotificationService: Failed to initialize plugin');
        return false;
      }

      // Create notification channels for Android
      await _createNotificationChannels();

      // Open Hive box for persistence
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(NotificationEntryAdapter());
      }
      _notificationsBox = await Hive.openBox<NotificationEntry>(
        _notificationsBoxName,
      );

      // Cleanup old notifications if needed
      await _cleanupOldNotifications();

      _isInitialized = true;
      debugPrint('NotificationService: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('NotificationService: Initialization error - $e');
      return false;
    }
  }

  /// Creates local notification channels for different notification types.
  /// Android-specific configuration for grouping notifications by type.
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) {
      return;
    }

    final List<AndroidNotificationChannel> channels = [
      AndroidNotificationChannel(
        'mesh_messages',
        'Mesh Messages',
        description: 'Notifications for messages received via mesh network',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        'system_events',
        'System Events',
        description: 'Notifications for system-level events and updates',
        importance: Importance.defaultImportance,
        enableVibration: false,
        playSound: true,
        showBadge: false,
      ),
      AndroidNotificationChannel(
        'error_alerts',
        'Error Alerts',
        description: 'Notifications for errors and warnings',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
    ];

    // Create all channels
    for (final channel in channels) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Requests permission to show notifications.
  /// Required on iOS and Android 13+.
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final bool? granted = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return granted ?? false;
      } else if (Platform.isAndroid) {
        // Android permissions are requested via createNotificationChannel
        // For Android 13+, runtime permission is handled by the plugin
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('NotificationService: Permission request error - $e');
      return false;
    }
  }

  /// Shows a notification immediately.
  /// @param id - Unique identifier for the notification
  /// @param title - Notification title
  /// @param body - Notification body text
  /// @param channel - The channel to display the notification on
  /// @param payload - Optional payload data to include
  Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
    required NotificationChannel channel,
    Map<String, dynamic>? payload,
  }) async {
    if (!_isInitialized) {
      debugPrint(
          'NotificationService: Cannot show notification - not initialized');
      return false;
    }

    try {
      // Store notification for persistence
      await _storeNotification(
        id: id.toString(),
        title: title,
        body: body,
        channel: channel,
        payload: payload,
      );

      // Get channel-specific details
      final String channelId = _getChannelId(channel);

      // Android notification details
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        _getChannelName(channel),
        channelDescription: _getChannelDescription(channel),
        importance: _getChannelImportance(channel),
        priority: Priority.high,
        showWhen: true,
      );

      // iOS notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Combined details
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show the notification
      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload != null ? payload.toString() : null,
      );

      debugPrint('NotificationService: Showed notification $id: $title');
      return true;
    } catch (e) {
      debugPrint('NotificationService: Show notification error - $e');
      return false;
    }
  }

  /// Shows a mesh message notification.
  /// @param id - Unique identifier for the notification
  /// @param senderName - Name of the message sender
  /// @param messageContent - Content of the message
  /// @param payload - Optional payload data
  Future<bool> showMeshMessage({
    required int id,
    required String senderName,
    required String messageContent,
    Map<String, dynamic>? payload,
  }) {
    final String title = 'Message from $senderName';
    return showNotification(
      id: id,
      title: title,
      body: messageContent,
      channel: NotificationChannel.meshMessages,
      payload: payload,
    );
  }

  /// Shows a system event notification.
  /// @param id - Unique identifier for the notification
  /// @param eventTitle - Title of the event
  /// @param eventDescription - Description of the event
  /// @param payload - Optional payload data
  Future<bool> showSystemEvent({
    required int id,
    required String eventTitle,
    required String eventDescription,
    Map<String, dynamic>? payload,
  }) {
    return showNotification(
      id: id,
      title: eventTitle,
      body: eventDescription,
      channel: NotificationChannel.systemEvents,
      payload: payload,
    );
  }

  /// Shows an error alert notification.
  /// @param id - Unique identifier for the notification
  /// @param errorTitle - Title of the error
  /// @param errorMessage - Error message details
  /// @param payload - Optional payload data
  Future<bool> showErrorAlert({
    required int id,
    required String errorTitle,
    required String errorMessage,
    Map<String, dynamic>? payload,
  }) {
    return showNotification(
      id: id,
      title: errorTitle,
      body: errorMessage,
      channel: NotificationChannel.errorAlerts,
      payload: payload,
    );
  }

  /// Schedules a notification to be shown at a specific time.
  /// @param id - Unique identifier for the notification
  /// @param title - Notification title
  /// @param body - Notification body text
  /// @param scheduledTime - When to show the notification
  /// @param channel - The channel to display the notification on
  /// @param payload - Optional payload data to include
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required NotificationChannel channel,
    Map<String, dynamic>? payload,
  }) async {
    if (!_isInitialized) {
      debugPrint(
          'NotificationService: Cannot schedule notification - not initialized');
      return false;
    }

    try {
      // Get channel-specific details
      final String channelId = _getChannelId(channel);

      // Android notification details
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        _getChannelName(channel),
        channelDescription: _getChannelDescription(channel),
        importance: _getChannelImportance(channel),
        priority: Priority.high,
        showWhen: true,
      );

      // iOS notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Combined details
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule the notification
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload != null ? payload.toString() : null,
      );

      debugPrint(
          'NotificationService: Scheduled notification $id for $scheduledTime');
      return true;
    } catch (e) {
      debugPrint('NotificationService: Schedule notification error - $e');
      return false;
    }
  }

  /// Cancels a notification by ID.
  /// @param id - The ID of the notification to cancel
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('NotificationService: Cancelled notification $id');
    } catch (e) {
      debugPrint('NotificationService: Cancel notification error - $e');
    }
  }

  /// Cancels all notifications.
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('NotificationService: Cancelled all notifications');
    } catch (e) {
      debugPrint('NotificationService: Cancel all notifications error - $e');
    }
  }

  /// Stores a notification entry for persistence.
  /// @param id - Unique identifier for the notification
  /// @param title - Notification title
  /// @param body - Notification body text
  /// @param channel - The channel of the notification
  /// @param payload - Optional payload data
  Future<void> _storeNotification({
    required String id,
    required String title,
    required String body,
    required NotificationChannel channel,
    Map<String, dynamic>? payload,
  }) async {
    try {
      if (_notificationsBox == null) {
        debugPrint(
            'NotificationService: Cannot store notification - box not opened');
        return;
      }

      final entry = NotificationEntry.fromDetails(
        id: id,
        title: title,
        body: body,
        channel: channel,
        payload: payload,
      );

      await _notificationsBox!.put(id, entry);
      debugPrint('NotificationService: Stored notification $id');
    } catch (e) {
      debugPrint('NotificationService: Store notification error - $e');
    }
  }

  /// Retrieves a stored notification by ID.
  /// @param id - The ID of the notification to retrieve
  /// @return The NotificationEntry if found, null otherwise
  NotificationEntry? getStoredNotification(String id) {
    try {
      if (_notificationsBox == null) {
        debugPrint(
            'NotificationService: Cannot get notification - box not opened');
        return null;
      }

      return _notificationsBox!.get(id);
    } catch (e) {
      debugPrint('NotificationService: Get notification error - $e');
      return null;
    }
  }

  /// Retrieves all stored notifications.
  /// @return List of all NotificationEntry objects, sorted by creation time (newest first)
  List<NotificationEntry> getAllStoredNotifications() {
    try {
      if (_notificationsBox == null) {
        debugPrint(
            'NotificationService: Cannot get notifications - box not opened');
        return [];
      }

      final notifications = _notificationsBox!.values.toList();
      // Sort by creation time, newest first
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    } catch (e) {
      debugPrint('NotificationService: Get all notifications error - $e');
      return [];
    }
  }

  /// Retrieves stored notifications filtered by channel.
  /// @param channel - The channel to filter by
  /// @return List of NotificationEntry objects for the specified channel
  List<NotificationEntry> getNotificationsByChannel(
      NotificationChannel channel) {
    try {
      if (_notificationsBox == null) {
        debugPrint(
            'NotificationService: Cannot get notifications - box not opened');
        return [];
      }

      final notifications = _notificationsBox!.values
          .where((entry) => entry.channel == channel)
          .toList();
      // Sort by creation time, newest first
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    } catch (e) {
      debugPrint(
          'NotificationService: Get notifications by channel error - $e');
      return [];
    }
  }

  /// Marks a stored notification as read.
  /// @param id - The ID of the notification to mark as read
  Future<void> markNotificationAsRead(String id) async {
    try {
      if (_notificationsBox == null) {
        debugPrint(
            'NotificationService: Cannot mark notification - box not opened');
        return;
      }

      final entry = _notificationsBox!.get(id);
      if (entry != null) {
        final updated = NotificationEntry(
          id: entry.id,
          title: entry.title,
          body: entry.body,
          channel: entry.channel,
          createdAt: entry.createdAt,
          payload: entry.payload,
          isRead: true,
        );
        await _notificationsBox!.put(id, updated);
        debugPrint('NotificationService: Marked notification $id as read');
      }
    } catch (e) {
      debugPrint('NotificationService: Mark notification as read error - $e');
    }
  }

  /// Clears a stored notification by ID.
  /// @param id - The ID of the notification to clear
  Future<void> clearStoredNotification(String id) async {
    try {
      if (_notificationsBox == null) {
        debugPrint(
            'NotificationService: Cannot clear notification - box not opened');
        return;
      }

      await _notificationsBox!.delete(id);
      debugPrint('NotificationService: Cleared notification $id');
    } catch (e) {
      debugPrint('NotificationService: Clear notification error - $e');
    }
  }

  /// Clears all stored notifications.
  Future<void> clearAllStoredNotifications() async {
    try {
      if (_notificationsBox == null) {
        debugPrint(
            'NotificationService: Cannot clear notifications - box not opened');
        return;
      }

      await _notificationsBox!.clear();
      debugPrint('NotificationService: Cleared all stored notifications');
    } catch (e) {
      debugPrint('NotificationService: Clear all notifications error - $e');
    }
  }

  /// Removes old notifications to maintain storage limit.
  /// Keeps only the most recent _maxStoredNotifications entries.
  Future<void> _cleanupOldNotifications() async {
    try {
      if (_notificationsBox == null) {
        return;
      }

      final notifications = _notificationsBox!.values.toList();
      if (notifications.length <= _maxStoredNotifications) {
        return;
      }

      // Sort by creation time, oldest first
      notifications.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Remove oldest notifications that exceed the limit
      final toRemove = notifications.length - _maxStoredNotifications;
      for (int i = 0; i < toRemove; i++) {
        await _notificationsBox!.delete(notifications[i].id);
      }

      debugPrint('NotificationService: Cleaned up $toRemove old notifications');
    } catch (e) {
      debugPrint('NotificationService: Cleanup error - $e');
    }
  }

  /// Returns the number of unread notifications.
  int get unreadNotificationCount {
    try {
      if (_notificationsBox == null) {
        return 0;
      }

      return _notificationsBox!.values.where((entry) => !entry.isRead).length;
    } catch (e) {
      debugPrint('NotificationService: Get unread count error - $e');
      return 0;
    }
  }

  /// Closes the notification service and cleans up resources.
  Future<void> dispose() async {
    try {
      await _notificationsBox?.close();
      _notificationsBox = null;
      _isInitialized = false;
      debugPrint('NotificationService: Disposed');
    } catch (e) {
      debugPrint('NotificationService: Dispose error - $e');
    }
  }

  // Helper methods for channel configuration

  String _getChannelId(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.meshMessages:
        return 'mesh_messages';
      case NotificationChannel.systemEvents:
        return 'system_events';
      case NotificationChannel.errorAlerts:
        return 'error_alerts';
    }
  }

  String _getChannelName(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.meshMessages:
        return 'Mesh Messages';
      case NotificationChannel.systemEvents:
        return 'System Events';
      case NotificationChannel.errorAlerts:
        return 'Error Alerts';
    }
  }

  String _getChannelDescription(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.meshMessages:
        return 'Notifications for messages received via mesh network';
      case NotificationChannel.systemEvents:
        return 'Notifications for system-level events and updates';
      case NotificationChannel.errorAlerts:
        return 'Notifications for errors and warnings';
    }
  }

  Importance _getChannelImportance(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.meshMessages:
        return Importance.high;
      case NotificationChannel.systemEvents:
        return Importance.defaultImportance;
      case NotificationChannel.errorAlerts:
        return Importance.high;
    }
  }
}

/// Hive type adapter for NotificationEntry.
class NotificationEntryAdapter extends TypeAdapter<NotificationEntry> {
  @override
  final int typeId = 10;

  @override
  NotificationEntry read(BinaryReader reader) {
    final fieldsCount = reader.readByte();
    final Map<int, dynamic> fields = {};
    for (int i = 0; i < fieldsCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return NotificationEntry(
      id: fields[0] as String,
      title: fields[1] as String,
      body: fields[2] as String,
      channel: NotificationChannel.values[fields[3] as int],
      createdAt: fields[4] as DateTime,
      payload: fields[5] as Map<String, dynamic>?,
      isRead: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationEntry obj) {
    writer.writeByte(7); // Number of fields
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.body);
    writer.writeByte(3);
    writer.write(obj.channelIndex);
    writer.writeByte(4);
    writer.write(obj.createdAt);
    writer.writeByte(5);
    writer.write(obj.payload);
    writer.writeByte(6);
    writer.write(obj.isRead);
  }
}
