import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmNotificationService {
  AlarmNotificationService._();

  static final AlarmNotificationService instance = AlarmNotificationService._();
  static const MethodChannel _channel =
      MethodChannel('com.visionsen/alarm_notifications');

  bool _initialized = false;
  bool _permissionGranted = false;

  Future<bool> initialize() async {
    if (_initialized) return _permissionGranted;
    _initialized = true;

    if (!Platform.isAndroid) {
      _permissionGranted = false;
      return false;
    }

    final status = await Permission.notification.request();
    _permissionGranted = status.isGranted;
    return _permissionGranted;
  }

  Future<void> showAlarm(Map<String, dynamic> alarm) async {
    if (!_initialized) await initialize();
    if (!_permissionGranted || !Platform.isAndroid) return;

    final id = int.tryParse('${alarm['id'] ?? ''}') ??
        '${alarm['kind']}:${alarm['device_id']}:${alarm['sensor_id']}:${alarm['opened_at']}'
            .hashCode
            .abs();
    final sensorName = _firstNonEmpty([
      alarm['sensor_name'],
      alarm['sensor_metric'],
      alarm['kind'],
    ]);
    final deviceName = _firstNonEmpty([
      alarm['device_name'],
      alarm['device_code'],
      alarm['device_id'] == null ? null : 'Cihaz #${alarm['device_id']}',
    ]);
    final locationName = _firstNonEmpty([
      alarm['location_name'],
      alarm['location_id'] == null ? null : 'Konum #${alarm['location_id']}',
    ]);
    final value = alarm['last_value'];

    final title = sensorName.isEmpty
        ? 'VisionSen Alarmı'
        : '${_pretty(sensorName)} Alarmı';
    final bodyParts = <String>[
      if (locationName.isNotEmpty) locationName,
      if (deviceName.isNotEmpty) deviceName,
      if (value != null && '$value'.isNotEmpty) 'Değer: $value',
    ];

    try {
      await _channel.invokeMethod<void>('showAlarm', {
        'id': id & 0x7fffffff,
        'title': title,
        'body': bodyParts.isEmpty ? 'Yeni bir alarm oluştu.' : bodyParts.join(' · '),
      });
    } on PlatformException {
      // Bildirim köprüsü kullanılamıyorsa izleme ekranının çalışmasını bozmayız.
    }
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _pretty(String raw) {
    final normalized = raw.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return raw;
    return normalized
        .split(RegExp(r'\s+'))
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
