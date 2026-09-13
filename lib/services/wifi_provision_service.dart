import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/device.dart';

class ProvisioningWifiDevice {
  final String ssid;
  final int rssi;

  const ProvisioningWifiDevice({required this.ssid, required this.rssi});

  int get signalBars {
    if (rssi >= -55) return 4;
    if (rssi >= -67) return 3;
    if (rssi >= -75) return 2;
    return 1;
  }
}

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
  String? connectedLocalIp;
  bool _closed = false;

  WifiProvisionService() {
    _platform.setMethodCallHandler(_handleNativeCall);
  }

  bool get isConnected => connectionNotifier.value;
  String? get connectedSsid => connectedSsidNotifier.value;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'provisioningDisconnected') {
      connectedLocalIp = null;
      _setConnection(false);
    }
    return null;
  }

  void _setConnection(bool value, {String? ssid}) {
    if (_closed) return;
    connectionNotifier.value = value;
    connectedSsidNotifier.value =
        value ? (ssid ?? connectedSsidNotifier.value) : null;
  }

  String _platformMessage(PlatformException e, String fallback) {
    final message = e.message?.trim();
    if (message != null && message.isNotEmpty) return message;
    return fallback;
  }

  Future<List<ProvisioningWifiDevice>> scanDevices() async {
    lastError = null;
    if (_closed) {
      lastError = 'Kurulum servisi kapalı.';
      return const [];
    }

    try {
      final result = await _platform.invokeMapMethod<String, dynamic>(
        'scanProvisioningWifi',
        const {'ssidPrefix': apNamePrefix},
      ).timeout(const Duration(seconds: 15));

      if (result == null) {
        lastError = 'Wi-Fi taramasından yanıt alınamadı.';
        return const [];
      }
      if (result['wifiEnabled'] != true) {
        lastError =
            'Telefon Wi-Fi kapalı. Wi-Fi’yi açın ve cihazları tekrar tarayın.';
        return const [];
      }

      final raw = result['devices'];
      if (raw is! List) {
        lastError = 'VisionSen cihaz tarama sonucu geçersiz.';
        return const [];
      }

      final devices = <ProvisioningWifiDevice>[];
      final seen = <String>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final ssid = item['ssid']?.toString().trim() ?? '';
        if (!ssid.startsWith(apNamePrefix) || !seen.add(ssid)) continue;
        final rawRssi = item['rssi'];
        final rssi = rawRssi is num ? rawRssi.toInt() : -100;
        devices.add(ProvisioningWifiDevice(ssid: ssid, rssi: rssi));
      }
      devices.sort((a, b) => b.rssi.compareTo(a.rssi));
      if (devices.isEmpty) {
        lastError =
            'Yakında açık VisionSen kurulum cihazı bulunamadı. Cihazı kapatıp açın ve tekrar tarayın.';
      }
      return devices;
    } on TimeoutException {
      lastError = 'VisionSen cihaz taraması zaman aşımına uğradı.';
      return const [];
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'PERMISSION_DENIED':
          lastError =
              'Yakındaki Wi-Fi cihazlarını taramak için gerekli Android izni verilmedi.';
          break;
        case 'WIFI_DISABLED':
          lastError =
              'Telefon Wi-Fi kapalı. Wi-Fi’yi açın ve tekrar deneyin.';
          break;
        default:
          lastError = _platformMessage(
            e,
            'VisionSen cihazları taranamadı.',
          );
      }
      return const [];
    } catch (_) {
      lastError = 'VisionSen cihazları taranamadı.';
      return const [];
    }
  }

  Future<bool> connectToDevice(String ssid) async {
    lastError = null;
    if (_closed) {
      lastError = 'Kurulum servisi kapalı.';
      return false;
    }
    final selected = ssid.trim();
    if (!selected.startsWith(apNamePrefix)) {
      lastError = 'Seçilen ağ bir VisionSen kurulum cihazı değil.';
      return false;
    }
    if (isConnected && connectedSsid == selected) return true;

    try {
      await _platform.invokeMethod<void>('disconnectProvisioningWifi');
    } catch (_) {}
    _setConnection(false);
    connectedLocalIp = null;

    try {
      final result = await _platform.invokeMapMethod<String, dynamic>(
        'connectProvisioningWifi',
        {
          'ssid': selected,
          'password': apPassword,
          'timeoutMs': 35000,
        },
      ).timeout(const Duration(seconds: 40));

      final connected = result?['connected'] == true;
      if (!connected) {
        lastError = 'VisionSen cihaz Wi-Fi bağlantısı kurulamadı.';
        _setConnection(false);
        return false;
      }

      final returnedSsid = result?['ssid']?.toString().trim();
      connectedLocalIp = result?['localIp']?.toString().trim();
      _setConnection(
        true,
        ssid: returnedSsid?.isNotEmpty == true ? returnedSsid : selected,
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
        case 'WIFI_DISABLED':
          lastError =
              'Telefon Wi-Fi kapalı. Wi-Fi’yi açın ve tekrar deneyin.';
          break;
        case 'WIFI_UNAVAILABLE':
          lastError =
              'Seçilen VisionSen cihazına bağlanılamadı. Cihazı kapatıp açın ve tekrar tarayın.';
          break;
        case 'WIFI_BUSY':
          lastError = 'Başka bir cihaz bağlantı isteği halen devam ediyor.';
          break;
        case 'DHCP_TIMEOUT':
          lastError =
              'Cihaz Wi-Fi bağlantısı kuruldu ancak telefona yerel IP atanamadı. Tekrar deneyin.';
          break;
        default:
          lastError = _platformMessage(
            e,
            'VisionSen cihaz Wi-Fi bağlantısı kurulamadı.',
          );
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
      // Native request is also released from Activity lifecycle callbacks.
    } finally {
      connectedLocalIp = null;
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
      ).timeout(Duration(milliseconds: timeoutMs + 5000));

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
        connectedLocalIp = null;
        lastError = 'Cihaz Wi-Fi bağlantısı kesildi. Yeniden bağlanın.';
      } else {
        lastError = _platformMessage(e, 'Cihazla yerel bağlantı kurulamadı.');
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
      timeoutMs: 6500,
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
      timeoutMs: 9000,
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
    _platform.invokeMethod<void>('disconnectProvisioningWifi').catchError((_) {});
    _closed = true;
    _platform.setMethodCallHandler(null);
  }
}
