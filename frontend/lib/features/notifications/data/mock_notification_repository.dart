import '../../tasks/domain/entities/task.dart';
import '../domain/entities/device.dart';
import 'notification_repository.dart';

class MockNotificationRepository implements NotificationRepository {
  @override
  Future<NotificationDevice> registerDevice(
    DeviceRegistrationRequest payload,
  ) async {
    final channels = payload.channels.isEmpty
        ? const [NotificationChannel.push]
        : payload.channels;
    return NotificationDevice(
      id: 0,
      deviceToken: payload.deviceToken,
      platform: payload.platform,
      channels: channels,
      timezone: payload.timezone,
      locale: payload.locale,
      appVersion: payload.appVersion,
      isActive: payload.pushEnabled,
      lastSeenAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<NotificationDevice>> listDevices(String userId) async {
    return const [];
  }

  @override
  Future<void> removeDevice(String deviceToken) async {}

  @override
  Future<int> triggerDispatch() async => 0;

  @override
  Future<NotificationDevice> updateDevice(
    String userId,
    String deviceToken,
    DevicePreferenceUpdateRequest payload,
  ) async {
    return NotificationDevice(
      id: 0,
      deviceToken: deviceToken,
      platform: DevicePlatform.android,
      channels: payload.channels ?? const [NotificationChannel.push],
      timezone: payload.timezone ?? 'UTC',
      locale: payload.locale,
      appVersion: payload.appVersion,
      isActive: payload.pushEnabled ?? true,
      lastSeenAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
