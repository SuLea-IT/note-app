import '../../../core/network/api_client.dart';
import '../domain/entities/device.dart';
import 'notification_repository.dart';

class RemoteNotificationRepository implements NotificationRepository {
  RemoteNotificationRepository(this._client);

  final ApiClient _client;

  @override
  Future<NotificationDevice> registerDevice(
    DeviceRegistrationRequest payload,
  ) async {
    final response = await _client.postJson(
      '/notifications/devices',
      payload.toJson(),
    );
    final data = _unwrap(response);
    return NotificationDevice.fromJson(data);
  }

  @override
  Future<NotificationDevice> updateDevice(
    String userId,
    String deviceToken,
    DevicePreferenceUpdateRequest payload,
  ) async {
    final response = await _client.patchJson(
      '/notifications/devices/${Uri.encodeComponent(deviceToken)}?user_id=${Uri.encodeComponent(userId)}',
      payload.toJson(),
    );
    final data = _unwrap(response);
    return NotificationDevice.fromJson(data);
  }

  @override
  Future<List<NotificationDevice>> listDevices(String userId) async {
    final response = await _client.getJson(
      '/notifications/devices?user_id=${Uri.encodeComponent(userId)}',
    );
    final data = _unwrap(response);
    final items = (data['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(NotificationDevice.fromJson)
        .toList(growable: false);
    return items;
  }

  @override
  Future<void> removeDevice(String deviceToken) async {
    await _client.delete(
      '/notifications/devices/${Uri.encodeComponent(deviceToken)}',
    );
  }

  @override
  Future<int> triggerDispatch() async {
    final response = await _client.postJson(
      '/notifications/dispatch',
      const {},
    );
    final data = _unwrap(response);
    return (data['dispatched'] as num?)?.toInt() ?? 0;
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if (json.containsKey('id') || json.containsKey('items') || json.containsKey('device_token')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return json;
  }
}
