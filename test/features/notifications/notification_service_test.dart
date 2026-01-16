import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:bitchat/features/notification/notification_service.dart';

class FakeFlutterLocalNotificationsPlugin
    extends FlutterLocalNotificationsPlugin {
  @override
  Future<bool?> initialize(InitializationSettings settings,
      {OnDidReceiveNotificationResponse? onDidReceiveNotificationResponse,
      OnDidReceiveBackgroundNotificationResponse?
          onDidReceiveBackgroundNotificationResponse}) async {
    return true;
  }

  @override
  Future<void> show(
      int id, String? title, String? body, NotificationDetails? details,
      {String? payload}) async {}

  @override
  Future<void> zonedSchedule(int id, String? title, String? body,
      tz.TZDateTime scheduledDate, NotificationDetails? details,
      {required UILocalNotificationDateInterpretation
          uiLocalNotificationDateInterpretation,
      String? payload,
      AndroidAllowWhileIdle? androidAllowWhileIdle,
      DateTimeComponents? matchDateTimeComponents}) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  T? resolvePlatformSpecificImplementation<T extends Object?>() {
    return null;
  }
}

void main() {
  late Directory tempDir;
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  final service = NotificationService();

  late Box<NotificationEntry> notificationsBox;

  setUp(() async {
    // Ensure fresh singleton state
    await service.dispose();

    // Prepare Hive in a temporary directory
    tempDir = Directory.systemTemp.createTempSync('bitchat_test_hive_');
    Hive.init(tempDir.path);

    // Register adapter and open box
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(NotificationEntryAdapter());
    }
    notificationsBox =
        await Hive.openBox<NotificationEntry>('notifications_box');

    // Create mock plugin and inject it
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    when(mockPlugin.show(any<int>(), any<String?>(), any<String?>(),
            any<NotificationDetails>(),
            payload: anyNamed('payload')))
        .thenAnswer((_) async => Future.value());
    when(mockPlugin.zonedSchedule(any<int>(), any<String?>(), any<String?>(),
            any<tz.TZDateTime>(), any<NotificationDetails>(),
            uiLocalNotificationDateInterpretation:
                anyNamed('uiLocalNotificationDateInterpretation'),
            payload: anyNamed('payload')))
        .thenAnswer((_) async => Future.value());
    when(mockPlugin.cancel(any<int>())).thenAnswer((_) async => Future.value());
    when(mockPlugin.cancelAll()).thenAnswer((_) async => Future.value());

    await service.initializeForTest(
        plugin: mockPlugin, notificationsBox: notificationsBox);
  });

  tearDown(() async {
    await service.dispose();
    try {
      if (await tempDir.exists()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('Show message notification', () async {
    final id = 1001;
    final sender = 'Alice';
    final message = 'Hello world';

    final result = await service.showMeshMessage(
      id: id,
      senderName: sender,
      messageContent: message,
      payload: {'from': sender},
    );

    expect(result, isTrue);

    // Verify plugin show called
    verify(mockPlugin.show(id, 'Message from $sender', message, any,
            payload: anyNamed('payload')))
        .called(1);

    // Verify persistence
    final stored = service.getStoredNotification(id.toString());
    expect(stored, isNotNull);
    expect(stored!.title, contains(sender));
    expect(stored.body, equals(message));
  });

  test('Show connection (system event) notification', () async {
    final id = 2001;
    final title = 'Peer Connected';
    final desc = 'peer-1 is now online';

    final result = await service.showSystemEvent(
      id: id,
      eventTitle: title,
      eventDescription: desc,
      payload: {'peer': 'peer-1'},
    );

    expect(result, isTrue);
    verify(mockPlugin.show(id, title, desc, any, payload: anyNamed('payload')))
        .called(1);

    final stored = service.getStoredNotification(id.toString());
    expect(stored, isNotNull);
    expect(stored!.title, equals(title));
    expect(stored.body, equals(desc));
  });

  test('Clear notifications', () async {
    // Add two notifications
    await service.showMeshMessage(
      id: 3001,
      senderName: 'Bob',
      messageContent: 'One',
    );
    await service.showSystemEvent(
      id: 3002,
      eventTitle: 'Event',
      eventDescription: 'Two',
    );

    var all = service.getAllStoredNotifications();
    expect(all.length, greaterThanOrEqualTo(2));

    // Clear one
    await service.clearStoredNotification('3001');
    final one = service.getStoredNotification('3001');
    expect(one, isNull);

    // Clear all
    await service.clearAllStoredNotifications();
    all = service.getAllStoredNotifications();
    expect(all, isEmpty);
  });

  test('Notification persistence and unread count', () async {
    await service.clearAllStoredNotifications();

    await service.showMeshMessage(
      id: 4001,
      senderName: 'Carol',
      messageContent: 'First',
    );
    await Future.delayed(Duration(milliseconds: 5));
    await service.showMeshMessage(
      id: 4002,
      senderName: 'Dave',
      messageContent: 'Second',
    );

    final all = service.getAllStoredNotifications();
    expect(all.length, equals(2));

    // Newest first
    expect(all.first.id, equals('4002'));

    // Unread count
    expect(service.unreadNotificationCount, equals(2));

    // Mark one as read
    await service.markNotificationAsRead('4002');
    expect(service.unreadNotificationCount, equals(1));
  });

  test('Notification tapping', () async {
    String? tappedPayload;
    service.onNotificationTappedCallback = (payload) {
      tappedPayload = payload;
    };

    // Simulate a tap
    service.handleNotificationTapPayload('{"action":"open","id":123}');

    expect(tappedPayload, isNotNull);
    expect(tappedPayload, contains('action'));
  });
}
