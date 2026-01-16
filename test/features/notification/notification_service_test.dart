import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:bitchat/features/notification/notification_service.dart';

void main() {
  group('NotificationService', () {
    late NotificationService notificationService;

    setUpAll(() async {
      // Initialize Flutter bindings
      WidgetsFlutterBinding.ensureInitialized();
      // Initialize Hive for testing with a temp path
      Hive.init('./test_hive');
      // Register adapter
      Hive.registerAdapter(NotificationEntryAdapter());
    });

    setUp(() async {
      notificationService = NotificationService();
    });

    tearDown(() async {
      await notificationService.dispose();
    });

    tearDownAll(() async {
      await Hive.close();
    });

    test('should return singleton instance', () {
      final service1 = NotificationService();
      final service2 = NotificationService();
      expect(identical(service1, service2), true);
    });

    test('should initialize successfully', () async {
      final initialized = await notificationService.initialize();
      expect(initialized, true);
      expect(notificationService.isInitialized, true);
    });

    test('should initialize only once', () async {
      await notificationService.initialize();
      final initialized2 = await notificationService.initialize();
      expect(initialized2, true);
      // Verify it's the same instance and initialized flag is set
      expect(notificationService.isInitialized, true);
    });

    test('should create NotificationEntry from details', () {
      final entry = NotificationEntry.fromDetails(
        id: 'test-id',
        title: 'Test Title',
        body: 'Test Body',
        channel: NotificationChannel.meshMessages,
        payload: {'key': 'value'},
      );

      expect(entry.id, 'test-id');
      expect(entry.title, 'Test Title');
      expect(entry.body, 'Test Body');
      expect(entry.channel, NotificationChannel.meshMessages);
      expect(entry.payload, {'key': 'value'});
      expect(entry.isRead, false);
      expect(entry.createdAt, isNotNull);
    });

    test('should store and retrieve notification', () async {
      await notificationService.initialize();

      final entry = NotificationEntry.fromDetails(
        id: 'store-test-id',
        title: 'Store Test',
        body: 'Testing storage',
        channel: NotificationChannel.systemEvents,
      );

      // Manually store for testing (since we can't easily test the full show flow)
      final box = await Hive.openBox<NotificationEntry>('notifications_box');
      await box.put('store-test-id', entry);

      final retrieved = notificationService.getStoredNotification('store-test-id');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'store-test-id');
      expect(retrieved.title, 'Store Test');
      expect(retrieved.body, 'Testing storage');
      expect(retrieved.channel, NotificationChannel.systemEvents);

      await box.close();
    });

    test('should return all stored notifications sorted by creation time', () async {
      await notificationService.initialize();

      final box = await Hive.openBox<NotificationEntry>('notifications_box');

      final now = DateTime.now();
      final entry1 = NotificationEntry(
        id: 'entry1',
        title: 'First',
        body: 'Body 1',
        channel: NotificationChannel.meshMessages,
        createdAt: now.subtract(const Duration(minutes: 2)),
        isRead: false,
      );
      final entry2 = NotificationEntry(
        id: 'entry2',
        title: 'Second',
        body: 'Body 2',
        channel: NotificationChannel.meshMessages,
        createdAt: now.subtract(const Duration(minutes: 1)),
        isRead: false,
      );
      final entry3 = NotificationEntry(
        id: 'entry3',
        title: 'Third',
        body: 'Body 3',
        channel: NotificationChannel.meshMessages,
        createdAt: now,
        isRead: false,
      );

      await box.put('entry1', entry1);
      await box.put('entry2', entry2);
      await box.put('entry3', entry3);

      final all = notificationService.getAllStoredNotifications();
      expect(all.length, 3);
      expect(all[0].id, 'entry3'); // Newest first
      expect(all[1].id, 'entry2');
      expect(all[2].id, 'entry1');

      await box.close();
    });

    test('should filter notifications by channel', () async {
      await notificationService.initialize();

      final box = await Hive.openBox<NotificationEntry>('notifications_box');

      final now = DateTime.now();
      final meshEntry = NotificationEntry(
        id: 'mesh1',
        title: 'Mesh',
        body: 'Mesh message',
        channel: NotificationChannel.meshMessages,
        createdAt: now,
        isRead: false,
      );
      final systemEntry = NotificationEntry(
        id: 'system1',
        title: 'System',
        body: 'System event',
        channel: NotificationChannel.systemEvents,
        createdAt: now,
        isRead: false,
      );
      final errorEntry = NotificationEntry(
        id: 'error1',
        title: 'Error',
        body: 'Error alert',
        channel: NotificationChannel.errorAlerts,
        createdAt: now,
        isRead: false,
      );

      await box.put('mesh1', meshEntry);
      await box.put('system1', systemEntry);
      await box.put('error1', errorEntry);

      final meshNotifications =
          notificationService.getNotificationsByChannel(NotificationChannel.meshMessages);
      final systemNotifications =
          notificationService.getNotificationsByChannel(NotificationChannel.systemEvents);
      final errorNotifications =
          notificationService.getNotificationsByChannel(NotificationChannel.errorAlerts);

      expect(meshNotifications.length, 1);
      expect(meshNotifications[0].id, 'mesh1');
      expect(systemNotifications.length, 1);
      expect(systemNotifications[0].id, 'system1');
      expect(errorNotifications.length, 1);
      expect(errorNotifications[0].id, 'error1');

      await box.close();
    });

    test('should mark notification as read', () async {
      await notificationService.initialize();

      final box = await Hive.openBox<NotificationEntry>('notifications_box');

      final entry = NotificationEntry(
        id: 'read-test',
        title: 'Read Test',
        body: 'Testing read status',
        channel: NotificationChannel.meshMessages,
        createdAt: DateTime.now(),
        isRead: false,
      );

      await box.put('read-test', entry);
      await notificationService.markNotificationAsRead('read-test');

      final updated = notificationService.getStoredNotification('read-test');
      expect(updated, isNotNull);
      expect(updated!.isRead, true);

      await box.close();
    });

    test('should clear stored notification', () async {
      await notificationService.initialize();

      final box = await Hive.openBox<NotificationEntry>('notifications_box');

      final entry = NotificationEntry(
        id: 'clear-test',
        title: 'Clear Test',
        body: 'Testing clear',
        channel: NotificationChannel.meshMessages,
        createdAt: DateTime.now(),
        isRead: false,
      );

      await box.put('clear-test', entry);
      expect(notificationService.getStoredNotification('clear-test'), isNotNull);

      await notificationService.clearStoredNotification('clear-test');
      expect(notificationService.getStoredNotification('clear-test'), isNull);

      await box.close();
    });

    test('should clear all stored notifications', () async {
      await notificationService.initialize();

      final box = await Hive.openBox<NotificationEntry>('notifications_box');

      for (int i = 0; i < 5; i++) {
        final entry = NotificationEntry(
          id: 'clear-all-$i',
          title: 'Entry $i',
          body: 'Body $i',
          channel: NotificationChannel.meshMessages,
          createdAt: DateTime.now(),
          isRead: false,
        );
        await box.put('clear-all-$i', entry);
      }

      expect(notificationService.getAllStoredNotifications().length, 5);

      await notificationService.clearAllStoredNotifications();
      expect(notificationService.getAllStoredNotifications().length, 0);

      await box.close();
    });

    test('should count unread notifications', () async {
      await notificationService.initialize();

      final box = await Hive.openBox<NotificationEntry>('notifications_box');

      final readEntry = NotificationEntry(
        id: 'read',
        title: 'Read',
        body: 'Already read',
        channel: NotificationChannel.meshMessages,
        createdAt: DateTime.now(),
        isRead: true,
      );
      final unreadEntry1 = NotificationEntry(
        id: 'unread1',
        title: 'Unread 1',
        body: 'Not read yet',
        channel: NotificationChannel.meshMessages,
        createdAt: DateTime.now(),
        isRead: false,
      );
      final unreadEntry2 = NotificationEntry(
        id: 'unread2',
        title: 'Unread 2',
        body: 'Not read yet',
        channel: NotificationChannel.meshMessages,
        createdAt: DateTime.now(),
        isRead: false,
      );

      await box.put('read', readEntry);
      await box.put('unread1', unreadEntry1);
      await box.put('unread2', unreadEntry2);

      final unreadCount = notificationService.unreadNotificationCount;
      expect(unreadCount, 2);

      await box.close();
    });

    test('should handle get notification when box is not open', () {
      final service = NotificationService();
      final result = service.getStoredNotification('test-id');
      expect(result, isNull);
    });

    test('should handle get all notifications when box is not open', () {
      final service = NotificationService();
      final result = service.getAllStoredNotifications();
      expect(result, isEmpty);
    });

    test('should handle get notifications by channel when box is not open', () {
      final service = NotificationService();
      final result =
          service.getNotificationsByChannel(NotificationChannel.meshMessages);
      expect(result, isEmpty);
    });

    test('should handle mark as read when box is not open', () async {
      final service = NotificationService();
      // Should not throw
      await service.markNotificationAsRead('test-id');
    });

    test('should handle clear notification when box is not open', () async {
      final service = NotificationService();
      // Should not throw
      await service.clearStoredNotification('test-id');
    });

    test('should handle clear all notifications when box is not open', () async {
      final service = NotificationService();
      // Should not throw
      await service.clearAllStoredNotifications();
    });

    test('should handle show notification when not initialized', () async {
      final service = NotificationService();
      // Don't initialize
      final result = await service.showNotification(
        id: 1,
        title: 'Test',
        body: 'Test body',
        channel: NotificationChannel.meshMessages,
      );
      expect(result, false);
    });

    test('should handle schedule notification when not initialized', () async {
      final service = NotificationService();
      // Don't initialize
      final result = await service.scheduleNotification(
        id: 1,
        title: 'Test',
        body: 'Test body',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
        channel: NotificationChannel.meshMessages,
      );
      expect(result, false);
    });

    test('should have all notification channels defined', () {
      expect(NotificationChannel.values.length, 3);
      expect(NotificationChannel.values.contains(NotificationChannel.meshMessages),
          true);
      expect(
          NotificationChannel.values.contains(NotificationChannel.systemEvents),
          true);
      expect(NotificationChannel.values.contains(NotificationChannel.errorAlerts),
          true);
    });
  });
}
