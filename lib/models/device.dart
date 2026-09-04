class VisionSenCompatibility {
  static const String environmentMonitor = 'environment_monitor';

  /// Destek kararı firmware numarasından bağımsızdır. Cihaz tipi ve BLE
  /// protokol sürümü birlikte değerlendirilir; tanımlı olmayan hiçbir eşleşme
  /// kurulum akışına alınmaz.
  static const Map<String, Set<int>> supportedIdentities = {
    environmentMonitor: {1},
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

class BleDeviceModel {
  final String id;
  final String name;
  final String mac;
  final int rssi;
  final bool isVisionSen;
  final bool? configured;
  final int? protocolVersion;

  const BleDeviceModel({
    required this.id,
    required this.name,
    required this.mac,
    required this.rssi,
    required this.isVisionSen,
    required this.configured,
    required this.protocolVersion,
  });
}

class DeviceConfig {
  static const placeholderSerial = 'ESP-000125';

  /// Bu alanların hiçbiri uydurma varsayılan içermez; hepsi kullanıcı tarafından
  /// doldurulur veya cihazdan okunur. Boş bırakılan alanlar cihaz tarafında
  /// reddedilir.
  String deviceName = '';
  String serial = '';
  String ssid = '';
  String password = '';
  String companyKey = '';
  String serverUrl = '';
  String timezone = '(UTC+03:00) İstanbul';

  /// VerifyScreen'de cihazın INFO karakteristiğinden okunan "configured"
  /// alanına göre doldurulur. true ise cihaz DAHA ÖNCE kurulmuştur ve
  /// firmware, herhangi bir ayarı kabul etmeden önce cihazda KAYITLI olan
  /// mevcut firma anahtarını (auth_key) ister — bkz. currentCompanyKey.
  bool deviceAlreadyConfigured = false;

  /// Yalnızca DAHA ÖNCE kurulmuş bir cihazı güncellerken doldurulur: cihazda
  /// hâlâ kayıtlı olan (DEĞİŞTİRİLMEK istenen değil, MEVCUT) firma anahtarı.
  /// Bu, `companyKey` alanından KASITLI olarak AYRIDIR — aksi halde kullanıcı
  /// yeni bir anahtar girdiğinde kimlik doğrulaması kendi kendini geçersiz
  /// kılar ve hiçbir ayar (WiFi/sunucu dahil) güncellenemez.
  String currentCompanyKey = '';

  /// Kurulu cihazlarda false ise firma anahtarı değiştirilmez; mevcut anahtar
  /// hem kimlik doğrulama hem de kaydedilecek değer olarak kullanılır.
  bool changeCompanyKey = false;

  static const int minCompanyKeyLength = 6;
  static const int maxCompanyKeyLength = 128;
  static final RegExp _companyKeyPattern = RegExp(r'^[A-Za-z0-9._:-]+$');

  String get effectiveCompanyKey =>
      deviceAlreadyConfigured && !changeCompanyKey ? currentCompanyKey : companyKey;

  static String? validateCompanyKey(String value, {String label = 'Firma anahtarı'}) {
    if (value.length < minCompanyKeyLength || value.length > maxCompanyKeyLength) {
      return '$label $minCompanyKeyLength-$maxCompanyKeyLength karakter olmalı (şu an ${value.length}).';
    }
    if (!_companyKeyPattern.hasMatch(value)) {
      return '$label yalnızca harf, rakam, nokta, alt çizgi, iki nokta ve tire içerebilir.';
    }
    return null;
  }

  static bool isPlaceholderSerial(String value) =>
      value.trim().toUpperCase() == placeholderSerial;

  static String? validateServerUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return 'Sunucu adresi boş olamaz.';
    if (raw.length > 512) return 'Sunucu adresi çok uzun.';
    if (RegExp(r'\s').hasMatch(raw) || raw.contains('#')) {
      return 'Sunucu adresinde boşluk veya # olamaz.';
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Sunucu adresi http:// veya https:// ile başlamalı.';
    }
    if (uri.host.isEmpty) return 'Sunucu adresinde geçerli bir alan adı veya IP bulunmalı.';
    if (uri.userInfo.isNotEmpty) return 'Sunucu adresinde kullanıcı adı/şifre kullanılamaz.';
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

  /// Firmware'in doğruladığı kurallarla aynı kontroller.
  String? validate() {
    if (ssid.trim().isEmpty) return 'WiFi ağ adı (SSID) boş olamaz.';
    if (serial.trim().isEmpty) return 'Seri numarası boş olamaz.';
    if (isPlaceholderSerial(serial)) {
      return '$placeholderSerial örnek seri numarası kullanılamaz; gerçek cihaz seri numarasını girin.';
    }
    if (serial.length > 64) return 'Seri numarası en fazla 64 karakter olabilir.';
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(serial)) {
      return 'Seri numarası yalnızca harf, rakam, tire ve alt çizgi içerebilir.';
    }
    if (deviceAlreadyConfigured) {
      if (currentCompanyKey.trim().isEmpty) {
        return 'Bu cihaz daha önce kurulmuş; cihazda kayıtlı MEVCUT firma anahtarını girmelisiniz.';
      }
      final currentKeyError = validateCompanyKey(currentCompanyKey, label: 'Mevcut firma anahtarı');
      if (currentKeyError != null) return currentKeyError;
    }

    final targetKeyError = validateCompanyKey(effectiveCompanyKey);
    if (targetKeyError != null) return targetKeyError;
    return validateServerUrl(serverUrl);
  }
}
