import 'dart:convert';

class VisionSenCompatibility {
  static const String environmentMonitor = 'environment_monitor';

  /// Destek kararı firmware numarasından bağımsızdır. Cihaz tipi ve Wi-Fi
  /// provisioning protokol sürümü birlikte değerlendirilir; tanımlı olmayan hiçbir eşleşme
  /// kurulum akışına alınmaz.
  static const Map<String, Set<int>> supportedIdentities = {
    environmentMonitor: {2},
  };

  static bool isSupportedProtocol(int value) =>
      supportedIdentities.values.any((versions) => versions.contains(value));

  static bool isSupportedDeviceType(String value) =>
      supportedIdentities.containsKey(value);

  static bool isSupportedIdentity(String deviceType, int protocolVersion) =>
      supportedIdentities[deviceType]?.contains(protocolVersion) == true;

  static String deviceTypeLabel(String value) {
    switch (value) {
      case environmentMonitor:
        return 'Ortam İzleme';
      default:
        return value.isEmpty ? 'Bilinmiyor' : value;
    }
  }
}

class DeviceConfig {
  static const int maxDeviceNameBytes = 28;
  static const List<int> supportedSendIntervals = [1, 5, 15];

  String deviceName = '';
  String ssid = '';
  String password = '';
  String companyKey = '';
  String serverUrl = '';
  String timezone = '(UTC+03:00) İstanbul';
  int sendIntervalMinutes = 1;

  bool deviceAlreadyConfigured = false;
  String currentCompanyKey = '';
  bool changeCompanyKey = false;

  static const int minCompanyKeyLength = 32;
  static const int maxCompanyKeyLength = 128;
  static final RegExp _companyKeyPattern = RegExp(r'^[A-Za-z0-9._:-]+$');

  String get effectiveCompanyKey =>
      deviceAlreadyConfigured && !changeCompanyKey
          ? currentCompanyKey
          : companyKey;

  static bool isSupportedSendInterval(int value) =>
      supportedSendIntervals.contains(value);

  static String? validateCompanyKey(
    String value, {
    String label = 'Firma anahtarı',
  }) {
    if (value.length < minCompanyKeyLength || value.length > maxCompanyKeyLength) {
      return '$label $minCompanyKeyLength-$maxCompanyKeyLength karakter olmalı (şu an ${value.length}).';
    }
    if (!_companyKeyPattern.hasMatch(value)) {
      return '$label yalnızca harf, rakam, nokta, alt çizgi, iki nokta ve tire içerebilir.';
    }
    return null;
  }

  static String? validateDeviceName(String value) {
    final name = value.trim();
    if (name.isEmpty) return 'Cihaz adı boş olamaz.';
    final byteLength = utf8.encode(name).length;
    if (byteLength > maxDeviceNameBytes) {
      return 'Cihaz adı en fazla $maxDeviceNameBytes UTF-8 byte olabilir (şu an $byteLength byte).';
    }
    for (final rune in name.runes) {
      if (rune < 0x20 || rune == 0x7F) {
        return 'Cihaz adında kontrol karakteri kullanılamaz.';
      }
    }
    return null;
  }

  static String? validateServerUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return 'Sunucu adresi boş olamaz.';
    if (raw.length > 512) return 'Sunucu adresi çok uzun.';
    if (RegExp(r'\s').hasMatch(raw) || raw.contains('#')) {
      return 'Sunucu adresinde boşluk veya # olamaz.';
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https') {
      return 'Sunucu adresi https:// ile başlamalı.';
    }
    if (uri.host.isEmpty) {
      return 'Sunucu adresinde geçerli bir alan adı veya IP bulunmalı.';
    }
    if (uri.userInfo.isNotEmpty) {
      return 'Sunucu adresinde kullanıcı adı/şifre kullanılamaz.';
    }
    if (uri.hasQuery) return 'Sunucu adresinde sorgu parametresi (?) kullanılamaz.';
    if (uri.fragment.isNotEmpty) return 'Sunucu adresinde # bölümü kullanılamaz.';

    try {
      if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
        return 'Sunucu portu 1-65535 arasında olmalı.';
      }
    } on FormatException {
      return 'Sunucu portu geçersiz.';
    }
    return null;
  }

  String? validate() {
    final deviceNameError = validateDeviceName(deviceName);
    if (deviceNameError != null) return deviceNameError;

    if (!isSupportedSendInterval(sendIntervalMinutes)) {
      return 'Gönderim aralığı yalnızca 1, 5 veya 15 dakika olabilir.';
    }
    if (ssid.trim().isEmpty) return 'WiFi ağ adı (SSID) boş olamaz.';
    if (utf8.encode(ssid).length > 32) {
      return 'WiFi ağ adı en fazla 32 byte olabilir.';
    }
    final passwordBytes = utf8.encode(password).length;
    if (passwordBytes > 64) return 'WiFi şifresi en fazla 64 byte olabilir.';
    if (passwordBytes == 64 && !RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(password)) {
      return '64 karakterlik WiFi şifresi yalnız hexadecimal PSK olabilir.';
    }
    if (deviceAlreadyConfigured) {
      if (currentCompanyKey.trim().isEmpty) {
        return 'Bu cihaz daha önce kurulmuş; cihazda kayıtlı MEVCUT firma anahtarını girmelisiniz.';
      }
      final currentKeyError = validateCompanyKey(
        currentCompanyKey,
        label: 'Mevcut firma anahtarı',
      );
      if (currentKeyError != null) return currentKeyError;
    }

    final targetKeyError = validateCompanyKey(effectiveCompanyKey);
    if (targetKeyError != null) return targetKeyError;
    return validateServerUrl(serverUrl);
  }
}
