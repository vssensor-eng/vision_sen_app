import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/device.dart';

class WifiProvisionService {
  static const String deviceBaseUrl = 'http://192.168.4.1';
  static const String apNamePrefix = 'VISIONSEN-OIM3-';
  static const String apNamePattern = 'VISIONSEN-OIM3-XXXX';
  static const String apPassword = 'VisionSenOIM3';
  static const MethodChannel _platform = MethodChannel('com.visionsen/setup');

  final ValueNotifier<bool> connectionNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> connectedSsidNotifier =
      ValueNotifier<String?>(null);

  String? lastError;
  bool _closed = false;

  WifiProvisionService() {
    _platform.setMethodCallHandler(_handleNativeCall);
  }

  bool get isConnected => connectionNotifier.value;
  String? get connectedSsid => connectedSsidNotifier.value;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'provisioningDisconnected') {
      _setConnection(false);
    }
    return null;
  }

  void _setConnection(bool value, {String? ssid}) {
    if (_closed) return;
    connectionNotifier.value = value;
    connectedSsidNotifier.value = value ? (ssid ?? connectedSsidNotifier.value) : null;
  }

  Future<bool> connectToDevice() async {
    lastError = null;
    if (_closed) {
      lastError = 'Kurulum servisi kapalı.';
      return false;
    }
    if (isConnected) return true;

    try {
      final result = await _platform.invokeMapMethod<String, dynamic>(
        'connectProvisioningWifi',
        const {
          'ssidPrefix': apNamePrefix,
          'password': apPassword,
          'timeoutMs': 30000,
        },
      ).timeout(const Duration(seconds: 35));

      final connected = result?['connected'] == true;
      if (!connected) {
        lastError = 'VisionSen cihaz Wi-Fi bağlantısı kurulamadı.';
        _setConnection(false);
        return false;
      }

      final ssid = result?['ssid']?.toString().trim();
      _setConnection(
        true,
        ssid: ssid?.isNotEmpty == true ? ssid : apNamePattern,
      );
      return true;
    } on TimeoutException {
      lastError = 'Cihaz Wi-Fi bağlantı isteği zaman aşımına uğradı.';
      _setConnection(false);
      return false;
    } on PlatformException catch (e) {
      _setConnection(false);
      switch (e.code) {
        case 'PERMISSION_DENIED':
          lastError =
              'Yakındaki Wi-Fi cihazlarına erişim izni verilmedi. İzin verip tekrar deneyin.';
          break;
        case 'ANDROID_VERSION':
          lastError =
              'Uygulama içi cihaz bağlantısı Android 10 veya daha yeni sürüm gerektiriyor.';
          break;
        case 'WIFI_UNAVAILABLE':
          lastError =
              'VisionSen kurulum ağı bulunamadı. Cihazı kapatıp açın ve tekrar deneyin.';
          break;
        case 'WIFI_BUSY':
          lastError = 'Başka bir cihaz bağlantı isteği halen devam ediyor.';
          break;
        default:
          lastError = e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'VisionSen cihaz Wi-Fi bağlantısı kurulamadı.';
      }
      return false;
    } catch (_) {
      _setConnection(false);
      lastError = 'VisionSen cihaz Wi-Fi bağlantısı kurulamadı.';
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_closed) return;
    try {
      await _platform
          .invokeMethod<void>('disconnectProvisioningWifi')
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Native request process/activity ömrüyle de sonlandırılır. Dart state'i
      // her durumda temizlenir; sonraki connect yeni bir request oluşturur.
    } finally {
      _setConnection(false);
    }
  }

  Future<Map<String, dynamic>?> _localRequest({
    required String method,
    required String path,
    String? body,
    required int timeoutMs,
  }) async {
    if (!isConnected) {
      lastError = 'Önce VisionSen cihaz bağlantısını kurun.';
      return null;
    }

    try {
      final response = await _platform.invokeMapMethod<String, dynamic>(
        'localHttpRequest',
        {
          'method': method,
          'path': path,
          'body': body ?? '',
          'timeoutMs': timeoutMs,
        },
      ).timeout(Duration(milliseconds: timeoutMs + 2500));

      if (response == null) {
        lastError = 'Cihazdan boş yanıt alındı.';
        return null;
      }
      return response;
    } on TimeoutException {
      lastError = 'Cihaz isteği zaman aşımına uğradı.';
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'NO_PROVISIONING_NETWORK') {
        _setConnection(false);
        lastError = 'Cihaz Wi-Fi bağlantısı kesildi. Yeniden bağlanın.';
      } else {
        lastError = e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'Cihazla yerel bağlantı kurulamadı.';
      }
      return null;
    } catch (_) {
      lastError = 'Cihazla yerel bağlantı kurulamadı.';
      return null;
    }
  }

  Future<Map<String, dynamic>?> readDeviceInfo() async {
    lastError = null;
    final response = await _localRequest(
      method: 'GET',
      path: '/api/info',
      timeoutMs: 4000,
    );
    if (response == null) return null;

    final statusCode = response['statusCode'] as int? ?? 0;
    if (statusCode != 200) {
      lastError = 'Cihaz bilgi servisi HTTP $statusCode döndürdü.';
      return null;
    }

    try {
      final decoded = jsonDecode(response['body']?.toString() ?? '');
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
    } catch (_) {
      lastError = 'Cihaz bilgi yanıtı geçersiz.';
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

    final response = await _localRequest(
      method: 'POST',
      path: '/api/config',
      body: payload,
      timeoutMs: 8000,
    );
    if (response == null) return false;

    Map<String, dynamic>? decodedBody;
    try {
      final decoded = jsonDecode(response['body']?.toString() ?? '');
      if (decoded is Map) decodedBody = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    final statusCode = response['statusCode'] as int? ?? 0;
    final status = decodedBody?['status']?.toString();
    if (statusCode == 200 && status == 'SAVED') return true;

    lastError = status ??
        decodedBody?['message']?.toString() ??
        'HTTP $statusCode';
    return false;
  }

  void close() {
    if (_closed) return;
    if (isConnected) {
      _platform.invokeMethod<void>('disconnectProvisioningWifi').catchError((_) {});
    }
    _closed = true;
    _platform.setMethodCallHandler(null);
  }
}
