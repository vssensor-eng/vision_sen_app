import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/device.dart';

class WifiProvisionService {
  static const String deviceBaseUrl = 'http://192.168.4.1';
  static const String apNamePattern = 'VISIONSEN-OIM3-XXXX';
  static const String apPassword = 'VisionSenOIM3';
  static const MethodChannel _platform = MethodChannel('com.visionsen/setup');

  final http.Client _client;
  String? lastError;

  WifiProvisionService({http.Client? client}) : _client = client ?? http.Client();

  Future<void> openWifiSettings() async {
    await _platform.invokeMethod<void>('openWifiSettings');
  }

  Future<Map<String, dynamic>?> readDeviceInfo() async {
    lastError = null;
    try {
      final response = await _client
          .get(
            Uri.parse('$deviceBaseUrl/api/info'),
            headers: const {'Cache-Control': 'no-store'},
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        lastError = 'Cihaz bilgi servisi HTTP ${response.statusCode} döndürdü.';
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        lastError = 'Cihaz bilgi yanıtı geçersiz.';
        return null;
      }
      final info = Map<String, dynamic>.from(decoded);
      final rawProtocol = info['protocol_version'];
      final protocol = rawProtocol is int
          ? rawProtocol
          : rawProtocol is num && rawProtocol == rawProtocol.roundToDouble()
              ? rawProtocol.toInt()
              : int.tryParse('${rawProtocol ?? ''}');
      final rawInterval = info['send_interval_minutes'];
      final interval = rawInterval is int
          ? rawInterval
          : rawInterval is num && rawInterval == rawInterval.roundToDouble()
              ? rawInterval.toInt()
              : int.tryParse('${rawInterval ?? ''}');
      info['protocol_version'] = protocol;
      info['send_interval_minutes'] = interval;
      info['device_type'] = info['device_type']?.toString().trim() ?? '';
      info['transport'] = info['transport']?.toString().trim() ?? '';
      info['identity_fields_valid'] =
          protocol != null && (info['device_type'] as String).isNotEmpty;
      return info;
    } on TimeoutException {
      lastError =
          'Cihaza ulaşılamadı. Telefonun VisionSen kurulum Wi-Fi ağına bağlı olduğundan emin olun.';
      return null;
    } catch (_) {
      lastError =
          'Cihaza ulaşılamadı. VisionSen kurulum Wi-Fi ağına bağlanıp tekrar deneyin.';
      return null;
    }
  }

  Future<bool> writeConfiguration(DeviceConfig config) async {
    lastError = null;
    final validation = config.validate();
    if (validation != null) {
      lastError = validation;
      return false;
    }

    final payload = jsonEncode({
      'ssid': config.ssid,
      'password': config.password,
      'server_url': config.serverUrl,
      'serial': config.serial,
      'company_key': config.effectiveCompanyKey,
      'auth_key': config.deviceAlreadyConfigured ? config.currentCompanyKey : '',
      'device_name': config.deviceName.trim(),
      'send_interval_minutes': config.sendIntervalMinutes,
    });

    try {
      final response = await _client
          .post(
            Uri.parse('$deviceBaseUrl/api/config'),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Cache-Control': 'no-store',
            },
            body: utf8.encode(payload),
          )
          .timeout(const Duration(seconds: 8));

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      final status = body?['status']?.toString();
      if (response.statusCode == 200 && status == 'SAVED') return true;
      lastError =
          status ?? body?['message']?.toString() ?? 'HTTP ${response.statusCode}';
      return false;
    } on TimeoutException {
      lastError =
          'Kurulum isteği zaman aşımına uğradı. Kurulum Wi-Fi bağlantısını kontrol edin.';
      return false;
    } catch (_) {
      lastError =
          'Cihazla Wi-Fi bağlantısı kesildi. Kurulum ağına tekrar bağlanıp deneyin.';
      return false;
    }
  }

  void close() => _client.close();
}
