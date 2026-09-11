import 'package:flutter_test/flutter_test.dart';
import 'package:visionsen_setup/models/device.dart';

const validKeyA = 'ABCDEF0123456789ABCDEF0123456789';
const validKeyB = '1234567890ABCDEF1234567890ABCDEF';

String repeatedA(int count) => List.filled(count, 'A').join();

DeviceConfig baseConfig() => DeviceConfig()
  ..deviceName = 'VisionSen Test'
  ..ssid = 'TestWifi'
  ..serial = 'ESP-999999'
  ..companyKey = validKeyA
  ..serverUrl = 'https://example.com/api';

void main() {
  group('DeviceConfig validation', () {
    test('placeholder serial is rejected', () {
      final c = baseConfig()..serial = DeviceConfig.placeholderSerial;
      expect(c.validate(), contains('örnek seri numarası'));
    });

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

    test('server url requires a host', () {
      expect(DeviceConfig.validateServerUrl('https://'), isNotNull);
    });

    test('server url rejects query', () {
      expect(
        DeviceConfig.validateServerUrl('https://example.com/api?x=1'),
        isNotNull,
      );
    });

    test('server url accepts a normal trailing slash', () {
      expect(DeviceConfig.validateServerUrl('https://example.com/api/'), isNull);
    });

    test('already-configured device requires a valid current company key', () {
      final c = baseConfig()
        ..deviceAlreadyConfigured = true
        ..changeCompanyKey = false
        ..currentCompanyKey = '';
      expect(c.validate(), contains('MEVCUT firma anahtarı'));

      c.currentCompanyKey = validKeyA;
      c.companyKey = c.currentCompanyKey;
      expect(c.validate(), isNull);

      c.currentCompanyKey = '${repeatedA(31)} ';
      c.companyKey = c.currentCompanyKey;
      expect(c.validate(), contains('yalnızca harf'));
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

    test('first-time setup does not require current company key', () {
      final c = baseConfig()..deviceAlreadyConfigured = false;
      expect(c.validate(), isNull);
    });

    test('valid server url is accepted', () {
      expect(
        DeviceConfig.validateServerUrl(
          'https://example.com/wp-json/oim/v1/ingest',
        ),
        isNull,
      );
      expect(
        DeviceConfig.validateServerUrl('http://192.168.1.10:8080/ingest'),
        isNull,
      );
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
      expect(
        VisionSenCompatibility.isSupportedIdentity('collector', 1),
        isFalse,
      );
      expect(VisionSenCompatibility.isSupportedProtocol(2), isFalse);
      expect(VisionSenCompatibility.isSupportedDeviceType('collector'), isFalse);
    });
  });
}
