import '../../tasks/domain/entities/task.dart';
import '../domain/entities/device.dart';

class DeviceRegistrationRequest {
  DeviceRegistrationRequest({
    required this.userId,
    required this.deviceToken,
    required this.platform,
    required this.channels,
    this.locale,
    this.timezone = 'UTC',
    this.appVersion,
    this.pushEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'device_token': deviceToken,
      'platform': platform.name,
      'channels': channels.map((item) => item.name).toList(),
      'locale': locale,
      'timezone': timezone,
      'app_version': appVersion,
      'push_enabled': pushEnabled,
    };
  }

  final String userId;
  final String deviceToken;
  final DevicePlatform platform;
  final List<NotificationChannel> channels;
  final String? locale;
  final String timezone;
  final String? appVersion;
  final bool pushEnabled;
}

class DevicePreferenceUpdateRequest {
  DevicePreferenceUpdateRequest({
    this.channels,
    this.pushEnabled,
    this.locale,
    this.timezone,
    this.appVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      if (channels != null)
        'channels': channels!.map((item) => item.name).toList(),
      if (pushEnabled != null) 'push_enabled': pushEnabled,
      if (locale != null) 'locale': locale,
      if (timezone != null) 'timezone': timezone,
      if (appVersion != null) 'app_version': appVersion,
    };
  }

  final List<NotificationChannel>? channels;
  final bool? pushEnabled;
  final String? locale;
  final String? timezone;
  final String? appVersion;
}

abstract class NotificationRepository {
  Future<NotificationDevice> registerDevice(DeviceRegistrationRequest payload);

  Future<NotificationDevice> updateDevice(
    String userId,
    String deviceToken,
    DevicePreferenceUpdateRequest payload,
  );

  Future<List<NotificationDevice>> listDevices(String userId);

  Future<void> removeDevice(String deviceToken);

  Future<int> triggerDispatch();
}
