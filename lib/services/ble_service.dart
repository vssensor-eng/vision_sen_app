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

  String? lastError;
  String? lastScanError;

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
  }

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

  bool _hasVisionSenManufacturerData(AdvertisementData data) =>
      _protocolFromAdvertisement(data) != null;

  String _scanName(ScanResult r) {
    // Android platformName eski bond/GATT cache'inden önceki adı döndürebilir.
    // Reklam paketindeki güncel ad her zaman önceliklidir.
    final advertised = r.advertisementData.advName.trim();
    if (advertised.isNotEmpty) return advertised;
    final platform = r.device.platformName.trim();
    if (platform.isNotEmpty) return platform;
    return '(isimsiz) ${r.device.remoteId.str}';
  }

  List<BleDeviceModel> _modelsFromScanResults(Iterable<ScanResult> results) {
    return results.map((r) {
      final name = _scanName(r);
      final isVisionSen =
          r.advertisementData.serviceUuids.contains(_BleUuids.service) ||
          name.startsWith('VISIONSEN-ESP-') ||
          _hasVisionSenManufacturerData(r.advertisementData);
      final protocolInfo =
          isVisionSen ? _protocolFromAdvertisement(r.advertisementData) : null;
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

  bool _scanMetadataImproved(ScanResult? previous, ScanResult current) {
    if (previous == null) return true;

    final oldProtocol = _protocolFromAdvertisement(previous.advertisementData);
    final newProtocol = _protocolFromAdvertisement(current.advertisementData);
    if (oldProtocol == null && newProtocol != null) return true;
    if (oldProtocol != null &&
        newProtocol != null &&
        (oldProtocol.protocolVersion != newProtocol.protocolVersion ||
            oldProtocol.configured != newProtocol.configured)) {
      return true;
    }

    if (_scanName(previous) != _scanName(current)) return true;

    final oldHasService =
        previous.advertisementData.serviceUuids.contains(_BleUuids.service);
    final newHasService =
        current.advertisementData.serviceUuids.contains(_BleUuids.service);
    return !oldHasService && newHasService;
  }

  Future<List<BleDeviceModel>> scan({
    Duration timeout = const Duration(seconds: 60),
    void Function(List<BleDeviceModel> devices)? onUpdate,
  }) async {
    lastScanError = null;

    if (await getAdapterState() != BluetoothAdapterState.on) {
      lastScanError = 'Bluetooth kapalı. Bluetooth’u açıp tekrar deneyin.';
      return [];
    }
    if (!await _ensurePermissions()) {
      lastScanError =
          'Bluetooth tarama izni verilmedi. Uygulama izinlerinden Yakındaki cihazlar/Bluetooth erişimine izin verin.';
      return [];
    }

    if (FlutterBluePlus.isScanningNow) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }

    final found = <String, ScanResult>{};
    final sub = FlutterBluePlus.scanResults.listen((results) {
      var shouldNotify = false;
      for (final r in results) {
        if (debugShowAllDevices) {
          final id = r.device.remoteId.str;
          if (_scanMetadataImproved(found[id], r)) shouldNotify = true;
          found[id] = r;
          continue;
        }

        final hasService =
            r.advertisementData.serviceUuids.contains(_BleUuids.service);
        final name = _scanName(r);
        final nameMatch = name.startsWith('VISIONSEN-ESP-');
        final manufacturerMatch =
            _hasVisionSenManufacturerData(r.advertisementData);

        if (hasService || nameMatch || manufacturerMatch) {
          final id = r.device.remoteId.str;
          if (_scanMetadataImproved(found[id], r)) shouldNotify = true;
          found[id] = r;
        }
      }

      if (shouldNotify && onUpdate != null) {
        onUpdate(_modelsFromScanResults(found.values));
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
    } catch (_) {
      lastScanError =
          'Bluetooth taraması başlatılamadı. Bluetooth/izin durumunu kontrol edip tekrar deneyin.';
    } finally {
      await sub.cancel();
      if (FlutterBluePlus.isScanningNow) {
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}
      }
    }

    return _modelsFromScanResults(found.values);
  }

  Future<void> stopScan() async {
    if (!FlutterBluePlus.isScanningNow) return;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<bool> _ensureAndroidBond(BluetoothDevice target) async {
    if (!Platform.isAndroid) return true;

    try {
      final current = await target.bondState.first
          .timeout(const Duration(seconds: 2));
      if (current == BluetoothBondState.bonded) return true;
    } catch (_) {}

    try {
      // flutter_blue_plus 1.35.8 ile bonding bekleme hatası düzeltilmiştir.
      // İlk bağlantıda eşleştirme penceresini doğrudan burada gösterip kullanıcı
      // onayını bekliyoruz; GATT read işlemlerine erken geçmiyoruz.
      await target.createBond(timeout: 45);
      final bonded = await target.bondState
          .where((state) => state == BluetoothBondState.bonded)
          .first
          .timeout(const Duration(seconds: 5));
      return bonded == BluetoothBondState.bonded;
    } catch (_) {
      return false;
    }
  }

  Future<bool> connect(BleDeviceModel device) async {
    final target = BluetoothDevice.fromId(device.id);
    _advertisedProtocolVersion = device.protocolVersion;
    try {
      await target.connect(
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );

      if (!await _ensureAndroidBond(target)) {
        throw Exception('BLE eşleştirme tamamlanamadı');
      }

      try {
        await target.requestMtu(247);
      } catch (_) {}

      final services = await target.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid == _BleUuids.service,
        orElse: () => throw Exception('VisionSen BLE servisi bulunamadı'),
      );

      _configChar = service.characteristics
          .firstWhere((c) => c.uuid == _BleUuids.config);
      _statusChar = service.characteristics
          .firstWhere((c) => c.uuid == _BleUuids.status);
      _infoChar =
          service.characteristics.firstWhere((c) => c.uuid == _BleUuids.info);

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

    // Android bazı telefonlarda bonding tamamlandıktan hemen sonraki ilk encrypted
    // read'i ATT/GATT hatasıyla reddedebiliyor. Aynı bağlantı içinde kısa gecikmeli
    // iki tekrar yaparak kullanıcıyı ikinci kez "Bağlantı Kur" demeye zorlamıyoruz.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final value = await _infoChar!.read();
        final decoded = jsonDecode(utf8.decode(value, allowMalformed: true));
        if (decoded is! Map) return null;

        final info = Map<String, dynamic>.from(decoded);
        if (info['mac'] is! String || info['configured'] is! bool) return null;

        final rawProtocol = info['protocol_version'];
        int? protocolVersion;
        if (rawProtocol is int) {
          protocolVersion = rawProtocol;
        } else if (rawProtocol is num &&
            rawProtocol == rawProtocol.roundToDouble()) {
          protocolVersion = rawProtocol.toInt();
        }

        final rawDeviceType = info['device_type'];
        final deviceType = rawDeviceType is String ? rawDeviceType.trim() : '';

        info['protocol_version'] = protocolVersion;
        info['device_type'] = deviceType;
        info['identity_fields_valid'] =
            protocolVersion != null && deviceType.isNotEmpty;
        info['advertised_protocol_version'] = _advertisedProtocolVersion;
        info['protocol_mismatch'] = _advertisedProtocolVersion != null &&
            protocolVersion != null &&
            _advertisedProtocolVersion != protocolVersion;
        return info;
      } catch (_) {
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 500 + (attempt * 350)));
        }
      }
    }
    return null;
  }

  Future<bool> authenticate() async {
    final info = await readDeviceInfo();
    if (info == null ||
        info['identity_fields_valid'] != true ||
        info['protocol_mismatch'] == true) {
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
      lastError = validationError;
      return false;
    }

    final payload = jsonEncode({
      'ssid': config.ssid,
      'password': config.password,
      'server_url': config.serverUrl,
      'serial': config.serial,
      'company_key': config.effectiveCompanyKey,
      'auth_key':
          config.deviceAlreadyConfigured ? config.currentCompanyKey : '',
      // Firmware v1.3.9+ bu alanı NVS'te saklar ve sonraki gerçek güç
      // açılışında BLE reklam adında kullanır. Eski firmware alanı yok sayar.
      'device_name': config.deviceName.trim(),
    });
    final bytes = utf8.encode(payload);
    const chunkSize = 180;
    final totalChunks =
        ((bytes.length + chunkSize - 1) ~/ chunkSize).clamp(1, 255).toInt();

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
        final end =
            (start + chunkSize > bytes.length) ? bytes.length : start + chunkSize;
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
