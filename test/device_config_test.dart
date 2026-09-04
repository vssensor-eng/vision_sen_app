import 'package:flutter_test/flutter_test.dart';
import 'package:visionsen_setup/models/device.dart';

void main() {
  group('DeviceConfig validation', () {
    test('placeholder serial is rejected', () {
      final c = DeviceConfig()
        ..ssid = 'TestWifi'
        ..serial = DeviceConfig.placeholderSerial
        ..companyKey = 'ABC123'
        ..serverUrl = 'https://example.com/api';
      expect(c.validate(), contains('örnek seri numarası'));
    });

    test('company key accepts 6 characters and rejects 5', () {
      final valid = DeviceConfig()
        ..ssid = 'TestWifi'
        ..serial = 'ESP-999999'
        ..companyKey = 'ABC123'
        ..serverUrl = 'https://example.com/api';
      expect(valid.validate(), isNull);

      valid.companyKey = 'ABC12';
      expect(valid.validate(), contains('6-128'));
    });

    test('company key rejects unsupported characters', () {
      final c = DeviceConfig()
        ..ssid = 'TestWifi'
        ..serial = 'ESP-999999'
        ..companyKey = 'ABC 123'
        ..serverUrl = 'https://example.com/api';
      expect(c.validate(), contains('yalnızca harf'));
    });

    test('server url requires a host', () {
      expect(DeviceConfig.validateServerUrl('https://'), isNotNull);
    });

    test('server url rejects query', () {
      expect(DeviceConfig.validateServerUrl('https://example.com/api?x=1'), isNotNull);
    });

    test('server url accepts a normal trailing slash', () {
      expect(DeviceConfig.validateServerUrl('https://example.com/api/'), isNull);
    });

    test('already-configured device requires a valid current company key', () {
      final c = DeviceConfig()
        ..ssid = 'TestWifi'
        ..serial = 'ESP-999999'
        ..serverUrl = 'https://example.com/api'
        ..deviceAlreadyConfigured = true
        ..changeCompanyKey = false;
      expect(c.validate(), contains('MEVCUT firma anahtarı'));

      c.currentCompanyKey = 'ABC123';
      c.companyKey = c.currentCompanyKey;
      expect(c.validate(), isNull);

      c.currentCompanyKey = 'ABC 123';
      c.companyKey = c.currentCompanyKey;
      expect(c.validate(), contains('yalnızca harf'));
    });

    test('already-configured device keeps current key when change is disabled', () {
      final c = DeviceConfig()
        ..ssid = 'TestWifi'
        ..serial = 'ESP-999999'
        ..serverUrl = 'https://example.com/api'
        ..deviceAlreadyConfigured = true
        ..currentCompanyKey = 'ABC123'
        ..companyKey = 'NEW456'
        ..changeCompanyKey = false;
      expect(c.effectiveCompanyKey, 'ABC123');
      expect(c.validate(), isNull);
    });

    test('already-configured device uses new key when change is enabled', () {
      final c = DeviceConfig()
        ..ssid = 'TestWifi'
        ..serial = 'ESP-999999'
        ..serverUrl = 'https://example.com/api'
        ..deviceAlreadyConfigured = true
        ..currentCompanyKey = 'ABC123'
        ..companyKey = 'NEW456'
        ..changeCompanyKey = true;
      expect(c.effectiveCompanyKey, 'NEW456');
      expect(c.validate(), isNull);
    });

    test('first-time setup does not require current company key', () {
      final c = DeviceConfig()
        ..ssid = 'TestWifi'
        ..serial = 'ESP-999999'
        ..companyKey = 'ABC123'
        ..serverUrl = 'https://example.com/api'
        ..deviceAlreadyConfigured = false;
      expect(c.validate(), isNull);
    });

    test('valid server url is accepted', () {
      expect(DeviceConfig.validateServerUrl('https://example.com/wp-json/oim/v1/ingest'), isNull);
      expect(DeviceConfig.validateServerUrl('http://192.168.1.10:8080/ingest'), isNull);
    });
  });

  group('VisionSen compatibility', () {
    test('environment monitor + protocol v1 identity is supported', () {
      expect(
        VisionSenCompatibility.isSupportedIdentity(
          VisionSenCompatibility.environmentMonitor,
          1,
        ),
        isTrue,
      );
    });

    test('unsupported identity combinations are rejected', () {
      expect(
        VisionSenCompatibility.isSupportedIdentity(
          VisionSenCompatibility.environmentMonitor,
          2,
        ),
        isFalse,
      );
      expect(VisionSenCompatibility.isSupportedIdentity('collector', 1), isFalse);
      expect(VisionSenCompatibility.isSupportedProtocol(2), isFalse);
      expect(VisionSenCompatibility.isSupportedDeviceType('collector'), isFalse);
    });
  });
}
