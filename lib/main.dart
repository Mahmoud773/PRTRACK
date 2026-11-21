import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'src/app_controller.dart';
import 'src/ui/shell.dart';

final notificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await notificationsPlugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      appController.openFromPush({'requestId': payload});
    },
  );
  FirebaseMessaging.onMessage.listen((message) async {
    final data = message.data;
    final id = data['notificationId']?.toString() ?? '';
    if (id.isEmpty || await appController.pushSeen(id)) return;
    await appController.rememberPush(id);
    if (data['type'] == 'account_deleted') {
      appController.openFromPush(data);
      return;
    }
    await notificationsPlugin.show(
      id.hashCode,
      message.notification?.title,
      message.notification?.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pr_track',
          'PR TRACK',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: data['requestId']?.toString(),
    );
  });
  FirebaseMessaging.onMessageOpenedApp.listen(appController.openFromMessage);
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) appController.openFromMessage(initial);
  runApp(PrApp(controller: appController));
}

final appController = AppController();

extension on AppController {
  void openFromMessage(RemoteMessage message) => openFromPush(message.data);
}
