import 'package:flutter_test/flutter_test.dart';
import 'package:visionsen_setup/models/device.dart';

const validKeyA = 'ABCDEF0123456789ABCDEF0123456789';
const validKeyB = '1234567890ABCDEF1234567890ABCDEF';

String repeatedA(int count) => List.filled(count, 'A').join();

DeviceConfig baseConfig() => DeviceConfig()
  ..deviceName = 'VisionSen Test'
  ..ssid = 'TestWifi'
  ..companyKey = validKeyA
  ..serverUrl = 'https://example.com/api';

void main() {
  group('DeviceConfig validation', () {
    test('company key accepts 32 characters and rejects 31', () {
      final valid = baseConfig();
      expect(valid.validate(), isNull);
      valid.companyKey = repeatedA(31);
      expect(valid.validate(), contains('32-128'));
    });

    test('company key rejects unsupported characters', () {
      final c = baseConfig()..companyKey = '${repeatedA(31)} ';
      expect(c.validate(), contains('yalnızca harf'));
    });

    test('device name is required and limited by UTF-8 byte length', () {
      final c = baseConfig()..deviceName = '';
      expect(c.validate(), contains('Cihaz adı boş'));
      c.deviceName = repeatedA(29);
      expect(c.validate(), contains('28 UTF-8 byte'));
      c.deviceName = 'VisionSen Oda 1';
      expect(c.validate(), isNull);
    });

    test('Wi-Fi SSID and password lengths match firmware limits', () {
      final c = baseConfig()..ssid = repeatedA(33);
      expect(c.validate(), contains('32 byte'));
      c.ssid = 'TestWifi';
      c.password = repeatedA(65);
      expect(c.validate(), contains('64 byte'));
      c.password = List.filled(64, 'G').join();
      expect(c.validate(), contains('hexadecimal'));
      c.password = repeatedA(64);
      expect(c.validate(), isNull);
    });

    test('server url requires HTTPS and a host', () {
      expect(DeviceConfig.validateServerUrl('https://'), isNotNull);
      expect(DeviceConfig.validateServerUrl('http://192.168.1.10/ingest'), isNotNull);
      expect(DeviceConfig.validateServerUrl('https://example.com/ingest'), isNull);
    });

    test('server url rejects query', () {
      expect(DeviceConfig.validateServerUrl('https://example.com/api?x=1'), isNotNull);
    });

    test('already-configured device requires a valid current company key', () {
      final c = baseConfig()
        ..deviceAlreadyConfigured = true
        ..changeCompanyKey = false
        ..currentCompanyKey = '';
      expect(c.validate(), contains('MEVCUT firma anahtarı'));
      c.currentCompanyKey = validKeyA;
      expect(c.validate(), isNull);
    });

    test('already-configured device keeps current key when change is disabled', () {
      final c = baseConfig()
        ..deviceAlreadyConfigured = true
        ..currentCompanyKey = validKeyA
        ..companyKey = validKeyB
        ..changeCompanyKey = false;
      expect(c.effectiveCompanyKey, validKeyA);
      expect(c.validate(), isNull);
    });

    test('already-configured device uses new key when change is enabled', () {
      final c = baseConfig()
        ..deviceAlreadyConfigured = true
        ..currentCompanyKey = validKeyA
        ..companyKey = validKeyB
        ..changeCompanyKey = true;
      expect(c.effectiveCompanyKey, validKeyB);
      expect(c.validate(), isNull);
    });
  });

  group('VisionSen compatibility', () {
    test('environment monitor + Wi-Fi provisioning protocol v2 is supported', () {
      expect(
        VisionSenCompatibility.isSupportedIdentity(
          VisionSenCompatibility.environmentMonitor,
          2,
        ),
        isTrue,
      );
    });

    test('old BLE protocol identity and unknown device types are rejected', () {
      expect(
        VisionSenCompatibility.isSupportedIdentity(
          VisionSenCompatibility.environmentMonitor,
          1,
        ),
        isFalse,
      );
      expect(VisionSenCompatibility.isSupportedDeviceType('collector'), isFalse);
      expect(VisionSenCompatibility.isSupportedProtocol(1), isFalse);
    });
  });
}
