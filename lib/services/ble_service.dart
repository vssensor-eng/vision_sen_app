import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device.dart';

/// ESP32 firmware ile birebir eşleşen UUID'ler.
class _BleUuids {
  static final service = Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final config = Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');
  static final status = Guid('0072d46f-b39f-4a3f-a1a5-9c9b6f2d6f11');
  static final info = Guid('e3223f9e-2c02-4a5b-92ef-6b2f9a1e2b90');
}

class _AdvertisementProtocolInfo {
  final int protocolVersion;
  final bool configured;
  const _AdvertisementProtocolInfo(this.protocolVersion, this.configured);
}

class BleService {
  static const bool debugShowAllDevices = false;

  /// Bluetooth adaptörünün güncel durumunu döndürür. Uygulama bu metodu
  /// çağırırken Bluetooth'u AÇMAZ; yalnızca mevcut durumu okur.
  Future<BluetoothAdapterState> getAdapterState() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        return BluetoothAdapterState.unavailable;
      }

      var state = FlutterBluePlus.adapterStateNow;
      if (state == BluetoothAdapterState.unknown ||
          state == BluetoothAdapterState.turningOn ||
          state == BluetoothAdapterState.turningOff) {
        try {
          state = await FlutterBluePlus.adapterState
              .where((value) =>
                  value != BluetoothAdapterState.unknown &&
                  value != BluetoothAdapterState.turningOn &&
                  value != BluetoothAdapterState.turningOff)
              .first
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          state = FlutterBluePlus.adapterStateNow;
        }
      }
      return state;
    } catch (_) {
      return BluetoothAdapterState.unavailable;
    }
  }

  /// Yalnızca UI katmanı kullanıcıdan açık onay aldıktan SONRA çağrılmalıdır.
  /// Android'de gerekli CONNECT iznini ister ve ardından sistemin Bluetooth açma
  /// diyaloğunu başlatır. Kullanıcı sistem isteğini de reddederse false döner.
  Future<bool> enableBluetoothAfterUserConsent() async {
    if (await getAdapterState() == BluetoothAdapterState.on) return true;
    if (!Platform.isAndroid) return false;

    final connectPermission = await Permission.bluetoothConnect.request();
    if (!connectPermission.isGranted) return false;

    try {
      await FlutterBluePlus.turnOn();
      await FlutterBluePlus.adapterState
          .where((state) => state == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (_) {
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    }
  }

  BluetoothDevice? _device;
  BluetoothCharacteristic? _configChar;
  BluetoothCharacteristic? _statusChar;
  BluetoothCharacteristic? _infoChar;
  int? _advertisedProtocolVersion;

  /// Cihazın reddettiği son hata kodu.
  String? lastError;

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
  }

  /// Firmware scan response içindeki VisionSen üretici verisi:
  /// company id 0xFFFF, payload = ['V','S', protocol_version, configured=0/1].
  _AdvertisementProtocolInfo? _protocolFromAdvertisement(AdvertisementData data) {
    for (final bytes in data.manufacturerData.values) {
      for (var i = 0; i + 3 < bytes.length; i++) {
        if (bytes[i] == 0x56 && bytes[i + 1] == 0x53) {
          return _AdvertisementProtocolInfo(bytes[i + 2], bytes[i + 3] != 0);
        }
      }
    }
    return null;
  }

  Future<List<BleDeviceModel>> scan() async {
    if (await getAdapterState() != BluetoothAdapterState.on) return [];
    if (!await _ensurePermissions()) return [];
    final found = <String, ScanResult>{};
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (debugShowAllDevices) {
          found[r.device.remoteId.str] = r;
          continue;
        }
        final hasService = r.advertisementData.serviceUuids.contains(_BleUuids.service);
        final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
        final nameMatch = name.startsWith('VISIONSEN-ESP-');
        if (hasService || nameMatch) found[r.device.remoteId.str] = r;
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: debugShowAllDevices ? [] : [_BleUuids.service],
        timeout: const Duration(seconds: 6),
      );
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
    } finally {
      await sub.cancel();
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    }

    return found.values.map((r) {
      String name = r.device.platformName;
      if (name.isEmpty) name = r.advertisementData.advName;
      if (name.isEmpty) name = '(isimsiz) ${r.device.remoteId.str}';
      final isVisionSen = r.advertisementData.serviceUuids.contains(_BleUuids.service) || name.startsWith('VISIONSEN-ESP-');
      final protocolInfo = isVisionSen ? _protocolFromAdvertisement(r.advertisementData) : null;
      return BleDeviceModel(
        id: r.device.remoteId.str,
        name: name,
        mac: r.device.remoteId.str,
        rssi: r.rssi,
        isVisionSen: isVisionSen,
        configured: protocolInfo?.configured,
        protocolVersion: protocolInfo?.protocolVersion,
      );
    }).toList();
  }

  /// Bağlanır ve Android'de bonding'i önden başlatır. Firmware'in INFO/CONFIG
  /// karakteristikleri şifreli GATT erişimi istediği için bağ başarısızsa
  /// güvenli okuma/yazma da başarısız olur.
  Future<bool> connect(BleDeviceModel device) async {
    final target = BluetoothDevice.fromId(device.id);
    _advertisedProtocolVersion = device.protocolVersion;
    try {
      await target.connect(timeout: const Duration(seconds: 12), autoConnect: false);

      if (Platform.isAndroid) {
        try {
          await target.createBond(timeout: 20);
        } catch (_) {
          // Zaten bonded cihazlarda veya üreticiye özgü Android davranışlarında
          // createBond hata verebilir. Güvenli karakteristik erişimi nihai kontrolü yapar.
        }
      }

      try {
        await target.requestMtu(247);
      } catch (_) {}

      final services = await target.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid == _BleUuids.service,
        orElse: () => throw Exception('VisionSen BLE servisi bulunamadı'),
      );

      _configChar = service.characteristics.firstWhere((c) => c.uuid == _BleUuids.config);
      _statusChar = service.characteristics.firstWhere((c) => c.uuid == _BleUuids.status);
      _infoChar = service.characteristics.firstWhere((c) => c.uuid == _BleUuids.info);

      // CCCD de firmware tarafında şifreli erişime zorlanır.
      await _statusChar!.setNotifyValue(true);
      _device = target;
      return true;
    } catch (_) {
      try {
        await target.disconnect();
      } catch (_) {}
      _device = null;
      _configChar = null;
      _statusChar = null;
      _infoChar = null;
      _advertisedProtocolVersion = null;
      return false;
    }
  }

  Future<Map<String, dynamic>?> readDeviceInfo() async {
    if (_infoChar == null) return null;
    try {
      final value = await _infoChar!.read();
      final decoded = jsonDecode(utf8.decode(value, allowMalformed: true));
      if (decoded is! Map) return null;

      final info = Map<String, dynamic>.from(decoded);
      if (info['mac'] is! String || info['configured'] is! bool) return null;

      // Kimlik alanları zorunludur. Eski firmware için varsayım/fallback yoktur.
      // Böylece aynı donanımda farklı firmware olsa bile yalnızca açıkça
      // desteklenen device_type + protocol_version eşleşmesi kabul edilir.
      final rawProtocol = info['protocol_version'];
      int? protocolVersion;
      if (rawProtocol is int) {
        protocolVersion = rawProtocol;
      } else if (rawProtocol is num && rawProtocol == rawProtocol.roundToDouble()) {
        protocolVersion = rawProtocol.toInt();
      }

      final rawDeviceType = info['device_type'];
      final deviceType = rawDeviceType is String ? rawDeviceType.trim() : '';

      info['protocol_version'] = protocolVersion;
      info['device_type'] = deviceType;
      info['identity_fields_valid'] = protocolVersion != null && deviceType.isNotEmpty;
      info['advertised_protocol_version'] = _advertisedProtocolVersion;
      info['protocol_mismatch'] = _advertisedProtocolVersion != null &&
          protocolVersion != null &&
          _advertisedProtocolVersion != protocolVersion;
      return info;
    } catch (_) {
      return null;
    }
  }

  Future<bool> authenticate() async {
    final info = await readDeviceInfo();
    if (info == null || info['identity_fields_valid'] != true || info['protocol_mismatch'] == true) {
      return false;
    }
    final protocol = info['protocol_version'];
    final deviceType = info['device_type'];
    return protocol is int &&
        deviceType is String &&
        VisionSenCompatibility.isSupportedIdentity(deviceType, protocol);
  }

  Future<bool> writeConfiguration(DeviceConfig config) async {
    if (_configChar == null || _statusChar == null) return false;
    lastError = null;

    final validationError = config.validate();
    if (validationError != null) {
      // Kod (ERROR:...) yerine doğrudan okunabilir mesaj saklanır; setup_screen
      // bunu "ERROR:" ile başlamayan değerler için olduğu gibi gösterir.
      lastError = validationError;
      return false;
    }

    final payload = jsonEncode({
      'ssid': config.ssid,
      'password': config.password,
      'server_url': config.serverUrl,
      'serial': config.serial,
      'company_key': config.effectiveCompanyKey,
      // Kurulu cihazda firmware mevcut firma anahtarını bununla doğrular.
      // Firma anahtarı değiştirilmiyorsa effectiveCompanyKey de mevcut anahtardır;
      // değiştiriliyorsa company_key yeni değeri, auth_key mevcut değeri taşır.
      // İlk kurulumda auth_key boş gider ve firmware bu alanı kontrol etmez.
      'auth_key': config.deviceAlreadyConfigured ? config.currentCompanyKey : '',
    });
    final bytes = utf8.encode(payload);
    const chunkSize = 180;
    final totalChunks = ((bytes.length + chunkSize - 1) ~/ chunkSize).clamp(1, 255).toInt();

    final resultCompleter = Completer<bool>();
    late final StreamSubscription<List<int>> sub;
    sub = _statusChar!.onValueReceived.listen((value) {
      final text = utf8.decode(value, allowMalformed: true);
      if (text.startsWith('SAVED')) {
        if (!resultCompleter.isCompleted) resultCompleter.complete(true);
      } else if (text.startsWith('ERROR')) {
        lastError = text;
        if (!resultCompleter.isCompleted) resultCompleter.complete(false);
      }
    });

    try {
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize > bytes.length) ? bytes.length : start + chunkSize;
        final chunkPayload = bytes.sublist(start, end);
        final packet = Uint8List(2 + chunkPayload.length);
        packet[0] = i;
        packet[1] = totalChunks;
        packet.setRange(2, 2 + chunkPayload.length, chunkPayload);
        await _configChar!.write(packet, withoutResponse: false);
      }

      return await resultCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          lastError ??= 'ERROR:TIMEOUT';
          return false;
        },
      );
    } catch (_) {
      lastError ??= 'ERROR:BLE_WRITE';
      return false;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _configChar = null;
    _statusChar = null;
    _infoChar = null;
    _advertisedProtocolVersion = null;
  }
}
