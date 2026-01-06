import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage.dart';
import '../config/environment.dart';
import 'package:http/http.dart' as http;

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 Background message: ${message.messageId}');
}

/// FCM Service for handling push notifications
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // Lazy initialization - will be set after Firebase.initializeApp()
  FirebaseMessaging? _messaging;
  FirebaseMessaging get messaging => _messaging ??= FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize FCM service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Request permission
      await _requestPermission();

      // Initialize local notifications
      await _initLocalNotifications();

      // Setup message handlers
      _setupMessageHandlers();

      // Get and register FCM token
      await _registerToken();

      _isInitialized = true;
      debugPrint('✅ FCM Service initialized');
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
    }
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('🔔 Permission status: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications for foreground display
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'workradar_channel',
      'Workradar Notifications',
      description: 'Notifications from Workradar app',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // Handle navigation based on payload
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _handleNotificationNavigation(data);
    }
  }

  /// Setup message handlers for different app states
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // App opened from background via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 App opened from notification: ${message.data}');
      _handleNotificationNavigation(message.data);
    });

    // Check if app was opened from terminated state
    _checkInitialMessage();
  }

  /// Check if app was launched from a notification
  Future<void> _checkInitialMessage() async {
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 App launched from notification: ${initialMessage.data}');
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  /// Show local notification when app is in foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'workradar_channel',
      'Workradar Notifications',
      channelDescription: 'Notifications from Workradar app',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Handle navigation based on notification data
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    switch (type) {
      case 'task_reminder':
        // Navigate to task detail
        debugPrint('Navigate to task: ${data['task_id']}');
        break;
      case 'health_recommendation':
        // Navigate to profile/health
        debugPrint('Navigate to health recommendations');
        break;
      case 'weather_alert':
        // Navigate to weather screen
        debugPrint('Navigate to weather');
        break;
      case 'vip_upgrade':
        // Navigate to subscription
        debugPrint('Navigate to subscription');
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  /// Get FCM token and register with backend
  Future<void> _registerToken() async {
    try {
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: ${token.substring(0, 20)}...');
        await _sendTokenToServer(token);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('📱 FCM Token refreshed');
        _sendTokenToServer(newToken);
      });
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Send FCM token to backend server
  Future<void> _sendTokenToServer(String fcmToken) async {
    try {
      final accessToken = await SecureStorage.getAccessToken();
      if (accessToken == null) {
        debugPrint('⚠️ No access token, skipping FCM token registration');
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/notifications/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token registered with server');
      } else {
        debugPrint('⚠️ Failed to register FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM token to server: $e');
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    return await messaging.getToken();
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await messaging.subscribeToTopic(topic);
    debugPrint('✅ Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await messaging.unsubscribeFromTopic(topic);
    debugPrint('✅ Unsubscribed from topic: $topic');
  }

  /// Subscribe VIP user to VIP-only topics
  Future<void> subscribeVIPTopics() async {
    await subscribeToTopic('vip_users');
    await subscribeToTopic('weather_alerts');
    await subscribeToTopic('health_tips');
  }

  /// Unsubscribe from VIP-only topics (when subscription expires)
  Future<void> unsubscribeVIPTopics() async {
    await unsubscribeFromTopic('vip_users');
    await unsubscribeFromTopic('weather_alerts');
    await unsubscribeFromTopic('health_tips');
  }
}
