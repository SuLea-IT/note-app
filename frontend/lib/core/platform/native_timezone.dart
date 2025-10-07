import 'dart:async';

import 'package:flutter/services.dart';

class NativeTimezone {
  static const MethodChannel _channel =
      MethodChannel('com.example.frontend/timezone');

  static Future<String> getLocalTimezone() async {
    try {
      final value = await _channel.invokeMethod<String>('getLocalTimezone');
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    } on PlatformException {
      // ignore and fall through to fallback below
    } catch (_) {
      // ignore and use fallback
    }

    final name = DateTime.now().timeZoneName;
    return name.isNotEmpty ? name : 'UTC';
  }
}
