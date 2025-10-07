import '../../../tasks/domain/entities/task.dart';

enum DevicePlatform { android, ios, web }

DevicePlatform devicePlatformFromName(String? raw) {
  final normalized = raw?.trim().toLowerCase();
  switch (normalized) {
    case 'ios':
      return DevicePlatform.ios;
    case 'web':
      return DevicePlatform.web;
    case 'android':
    default:
      return DevicePlatform.android;
  }
}

class NotificationDevice {
  const NotificationDevice({
    required this.id,
    required this.deviceToken,
    required this.platform,
    required this.channels,
    required this.timezone,
    this.locale,
    this.appVersion,
    required this.isActive,
    this.lastSeenAt,
    this.createdAt,
    this.updatedAt,
  });

  factory NotificationDevice.fromJson(Map<String, dynamic> json) {
    final rawChannels = (json['channels'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map(NotificationChannelX.fromName)
        .toList(growable: false);
    return NotificationDevice(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deviceToken: json['device_token'] as String? ?? '',
      platform: devicePlatformFromName(json['platform'] as String?),
      channels: rawChannels.isEmpty
          ? const [NotificationChannel.push]
          : rawChannels,
      locale: json['locale'] as String?,
      timezone: (json['timezone'] as String? ?? 'UTC').trim().isEmpty
          ? 'UTC'
          : (json['timezone'] as String).trim(),
      appVersion: json['app_version'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      lastSeenAt: _parseDateTime(json['last_seen_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  final int id;
  final String deviceToken;
  final DevicePlatform platform;
  final List<NotificationChannel> channels;
  final String? locale;
  final String timezone;
  final String? appVersion;
  final bool isActive;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
