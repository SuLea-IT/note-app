import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../../tasks/application/task_detail_controller.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/entities/task.dart';
import '../../tasks/presentation/task_detail_screen.dart';
import '../data/notification_repository.dart';
import '../domain/entities/device.dart';
import 'package:frontend/core/platform/native_timezone.dart';

const String _kReminderChannelId = 'task_reminders_channel';
const String _kReminderChannelName = '任务提醒';
const String _kReminderChannelDescription = '来自提醒调度器的任务推送';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore repeated initialization errors.
  }
  debugPrint('Background message received: ${message.messageId}');
}

class NotificationPayload {
  const NotificationPayload({
    required this.taskId,
    required this.reminderId,
    required this.channel,
    required this.silent,
    this.title,
    this.body,
    this.scheduledAt,
    this.timezone,
  });

  factory NotificationPayload.fromMessage(RemoteMessage message) {
    return NotificationPayload.fromData(message.data, message.notification);
  }

  factory NotificationPayload.fromData(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final channel = NotificationChannelX.fromName(data['channel'] as String? ?? 'push');
    final silent = ((data['silent'] as String?) ?? 'false').toLowerCase() == 'true';
    final scheduledRaw = data['scheduled_at'] as String?;
    DateTime? scheduledAt;
    if (scheduledRaw != null && scheduledRaw.isNotEmpty) {
      scheduledAt = DateTime.tryParse(scheduledRaw)?.toLocal();
    }

    return NotificationPayload(
      taskId: data['task_id'] as String? ?? '',
      reminderId: data['reminder_id'] as String? ?? '',
      channel: channel,
      silent: silent,
      title: data['title'] as String? ?? notification?.title,
      body: data['body'] as String? ?? notification?.body,
      scheduledAt: scheduledAt,
      timezone: data['timezone'] as String?,
    );
  }

  final String taskId;
  final String reminderId;
  final NotificationChannel channel;
  final bool silent;
  final String? title;
  final String? body;
  final DateTime? scheduledAt;
  final String? timezone;

  bool get isValid => taskId.isNotEmpty;
}

class NotificationController extends ChangeNotifier {
  NotificationController(
    this._auth,
    this._repository, {
    bool enableMessaging = true,
  }) : _enableMessaging = enableMessaging {
    _auth.addListener(_handleAuthChanged);
    if (_enableMessaging) {
      Future.microtask(_initialize);
    }
  }

  final AuthController _auth;
  final NotificationRepository _repository;
  final bool _enableMessaging;
  bool _firebaseAvailable = true;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _initialized = false;
  bool _permissionGranted = false;
  String? _currentToken;
  NotificationPayload? _pendingNavigation;
  VoidCallback? _silentUpdateListener;
  StreamSubscription<String>? _tokenSubscription;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool get permissionGranted => _permissionGranted;

  void registerSilentUpdateListener(VoidCallback? listener) {
    _silentUpdateListener = listener;
  }

  NotificationPayload? consumePendingNavigation() {
    final payload = _pendingNavigation;
    _pendingNavigation = null;
    return payload;
  }

  NotificationPayload? get pendingNavigation => _pendingNavigation;

  void openTask(NotificationPayload payload) {
    _navigateToTask(payload);
  }

  Future<void> _initialize() async {
    if (!_enableMessaging || _initialized) {
      return;
    }

    try {
      await Firebase.initializeApp();
    } catch (error) {
      debugPrint('NotificationController Firebase init warning: $error');
      _firebaseAvailable = false;
    }

    await _configureLocalNotifications();
    if (!_firebaseAvailable) {
      _initialized = true;
      notifyListeners();
      return;
    }

    await _requestPermissions();
    await _configureMessagingStreams();

    _initialized = true;
    notifyListeners();
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationResponse,
    );

    final androidPlugin = _localNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _kReminderChannelId,
          _kReminderChannelName,
          description: _kReminderChannelDescription,
          importance: Importance.high,
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    if (!_firebaseAvailable) {
      return;
    }
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );

    var granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted && !kIsWeb) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        granted = result.isGranted;
      }
    }

    _permissionGranted = granted;
  }

  Future<void> _configureMessagingStreams() async {
    if (!_firebaseAvailable) {
      return;
    }
    final messaging = FirebaseMessaging.instance;

    _tokenSubscription = messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      _registerDevice();
    });

    final token = await messaging.getToken();
    if (token != null) {
      _currentToken = token;
      await _registerDevice();
    }

    FirebaseMessaging.onMessage.listen((message) {
      _handleRemoteMessage(message, foreground: true);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(NotificationPayload.fromMessage(message));
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(
        NotificationPayload.fromMessage(initialMessage),
        fromTerminated: true,
      );
    }
  }

  void _handleRemoteMessage(RemoteMessage message, {required bool foreground}) {
    final payload = NotificationPayload.fromMessage(message);
    if (!payload.isValid) {
      return;
    }

    if (payload.silent && payload.channel != NotificationChannel.local) {
      _silentUpdateListener?.call();
      return;
    }

    final title = payload.title ?? '任务提醒';
    final body = payload.body ?? _buildBody(payload);

    _localNotificationsPlugin.show(
      payload.reminderId.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kReminderChannelId,
          _kReminderChannelName,
          channelDescription: _kReminderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload.taskId,
    );
  }

  void _handleNotificationTap(NotificationPayload payload,
      {bool fromTerminated = false}) {
    if (!payload.isValid) {
      return;
    }

    _pendingNavigation = payload;
    notifyListeners();

    if (!fromTerminated) {
      _navigateToTask(payload);
    }
  }

  void _onLocalNotificationResponse(NotificationResponse response) {
    final taskId = response.payload;
    if (taskId == null || taskId.isEmpty) {
      return;
    }
    final payload = NotificationPayload(
      taskId: taskId,
      reminderId: '',
      channel: NotificationChannel.push,
      silent: false,
    );
    _navigateToTask(payload);
  }

  void _navigateToTask(NotificationPayload payload) {
    final context = navigatorKey.currentContext;
    if (context == null || !payload.isValid) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<TaskDetailController>(
          create: (context) => TaskDetailController(
            context.read<TaskRepository>(),
            payload.taskId,
          )
            ..load(),
          child: TaskDetailScreen(
            taskId: payload.taskId,
            onTaskUpdated: (updated) => Navigator.of(context).pop(),
            onTaskDeleted: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  String _buildBody(NotificationPayload payload) {
    final scheduled = payload.scheduledAt;
    if (scheduled == null) {
      return '请及时查看任务详情';
    }
    return '提醒时间 ${_formatDateTime(scheduled)}';
  }

  String _formatDateTime(DateTime value) {
    final buffer = StringBuffer()
      ..write(value.year.toString().padLeft(4, '0'))
      ..write('-')
      ..write(value.month.toString().padLeft(2, '0'))
      ..write('-')
      ..write(value.day.toString().padLeft(2, '0'))
      ..write(' ')
      ..write(value.hour.toString().padLeft(2, '0'))
      ..write(':')
      ..write(value.minute.toString().padLeft(2, '0'));
    return buffer.toString();
  }

  Future<void> _registerDevice() async {
    if (!_enableMessaging || !_permissionGranted || !_firebaseAvailable) {
      return;
    }
    if (!_enableMessaging) {
      return;
    }
    final token = _currentToken;
    final user = _auth.state.user;
    if (token == null || token.isEmpty || user == null) {
      return;
    }

    try {
      final timezone = await NativeTimezone.getLocalTimezone();
      final locale = WidgetsBinding.instance.platformDispatcher.locales.first;
      final countryCode = locale.countryCode;
      final localeString = (countryCode == null || countryCode.isEmpty)
          ? locale.languageCode
          : '${locale.languageCode}_$countryCode';
      await _repository.registerDevice(
        DeviceRegistrationRequest(
          userId: user.id,
          deviceToken: token,
          platform: _detectPlatform(),
          channels: const [NotificationChannel.push, NotificationChannel.local],
          locale: localeString,
          timezone: timezone,
          appVersion: null,
          pushEnabled: true,
        ),
      );
    } catch (error) {
      debugPrint('NotificationController registerDevice error: $error');
    }
  }

  DevicePlatform _detectPlatform() {
    if (kIsWeb) {
      return DevicePlatform.web;
    }
    if (Platform.isAndroid) {
      return DevicePlatform.android;
    }
    if (Platform.isIOS) {
      return DevicePlatform.ios;
    }
    return DevicePlatform.android;
  }

  void _handleAuthChanged() {
    if (!_enableMessaging) {
      return;
    }
    final status = _auth.state.status;
    if (status == AuthStatus.authenticated) {
      _registerDevice();
    } else if (status == AuthStatus.unauthenticated) {
      _deregisterDevice();
    }
  }

  Future<void> _deregisterDevice() async {
    final token = _currentToken;
    if (token == null) {
      return;
    }
    try {
      await _repository.removeDevice(token);
    } catch (error) {
      debugPrint('NotificationController deregister error: $error');
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthChanged);
    _tokenSubscription?.cancel();
    super.dispose();
  }
}
