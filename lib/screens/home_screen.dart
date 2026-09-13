import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/wifi_provision_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final WifiProvisionService _provision = WifiProvisionService();
  final DeviceConfig _config = DeviceConfig();

  final _ssid = TextEditingController();
  final _password = TextEditingController();
  final _deviceName = TextEditingController();
  final _serial = TextEditingController();
  final _serverUrl = TextEditingController(
    text: 'https://www.vsias.com/wp-json/oim/v1/ingest',
  );
  final _companyKey = TextEditingController();
  final _currentCompanyKey = TextEditingController();

  bool _checking = false;
  bool _saving = false;
  bool _waitingForSettings = false;
  bool _connected = false;
  bool _saved = false;
  bool _showWifiPassword = false;
  bool _showCompanyKey = false;
  bool _showCurrentCompanyKey = false;
  bool _changeCompanyKey = false;
  int _sendInterval = 1;
  Map<String, dynamic>? _deviceInfo;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ssid.dispose();
    _password.dispose();
    _deviceName.dispose();
    _serial.dispose();
    _serverUrl.dispose();
    _companyKey.dispose();
    _currentCompanyKey.dispose();
    _provision.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _waitingForSettings &&
        !_checking &&
        !_saving) {
      _waitingForSettings = false;
      _checkConnection();
    }
  }

  void _setMessage(String? value, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _messageIsError = error;
    });
  }

  Future<void> _openWifiSettings() async {
    if (_checking || _saving) return;
    setState(() {
      _waitingForSettings = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      await _provision.openWifiSettings();
    } catch (_) {
      if (!mounted) return;
      setState(() => _waitingForSettings = false);
      _setMessage(
        'Wi-Fi ayarları açılamadı. Telefonunuzdan Ayarlar > Wi-Fi bölümünü açın.',
        error: true,
      );
    }
  }

  Future<void> _checkConnection() async {
    if (_checking || _saving) return;
    setState(() {
      _checking = true;
      _message = null;
      _messageIsError = false;
    });

    final info = await _provision.readDeviceInfo();
    if (!mounted) return;

    if (info == null) {
      setState(() {
        _checking = false;
        _connected = false;
      });
      _setMessage(
        _provision.lastError ?? 'VisionSen cihazına ulaşılamadı.',
        error: true,
      );
      return;
    }

    final deviceType = info['device_type']?.toString() ?? '';
    final protocolVersion = info['protocol_version'] as int?;
    final transport = info['transport']?.toString() ?? '';
    if (transport != 'wifi_softap' ||
        protocolVersion == null ||
        !VisionSenCompatibility.isSupportedIdentity(
          deviceType,
          protocolVersion,
        )) {
      setState(() {
        _checking = false;
        _connected = false;
      });
      _setMessage(
        'Bağlı ağ desteklenen VisionSen OIM3 Wi-Fi kurulum cihazı değil.',
        error: true,
      );
      return;
    }

    final configured =
        info['configured'] == true || '${info['configured']}' == 'true';
    final serial = info['serial']?.toString().trim() ?? '';
    final name = info['device_name']?.toString().trim() ?? '';
    final interval = info['send_interval_minutes'] as int? ?? 1;

    if (serial.isNotEmpty && !DeviceConfig.isPlaceholderSerial(serial)) {
      _serial.text = serial;
    }
    if (name.isNotEmpty) _deviceName.text = name;
    if (DeviceConfig.isSupportedSendInterval(interval)) {
      _sendInterval = interval;
    }

    _config.deviceAlreadyConfigured = configured;
    setState(() {
      _checking = false;
      _connected = true;
      _saved = false;
      _deviceInfo = info;
    });
    _setMessage(
      configured
          ? 'Cihaz bulundu. Mevcut firma anahtarını girerek ayarları güncelleyebilirsiniz.'
          : 'Cihaz bulundu. Wi-Fi ve sunucu bilgilerini doldurup kaydedin.',
    );
  }

  String? _prepareConfig() {
    _config
      ..ssid = _ssid.text.trim()
      ..password = _password.text
      ..deviceName = _deviceName.text.trim()
      ..serial = _serial.text.trim()
      ..serverUrl = _serverUrl.text.trim()
      ..sendIntervalMinutes = _sendInterval
      ..currentCompanyKey = _currentCompanyKey.text.trim()
      ..changeCompanyKey =
          _config.deviceAlreadyConfigured && _changeCompanyKey
      ..companyKey = _companyKey.text.trim();

    if (_config.deviceAlreadyConfigured && !_changeCompanyKey) {
      _config.companyKey = _config.currentCompanyKey;
    }
    return _config.validate();
  }

  Future<void> _saveConfiguration() async {
    if (_saving || _checking || !_connected) return;
    final validation = _prepareConfig();
    if (validation != null) {
      _setMessage(validation, error: true);
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
      _messageIsError = false;
    });
    final ok = await _provision.writeConfiguration(_config);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      _setMessage(
        _friendlyProvisionError(_provision.lastError),
        error: true,
      );
      return;
    }

    setState(() {
      _saved = true;
      _connected = false;
    });
    _setMessage(
      'Ayarlar kaydedildi. Cihaz yeniden başlıyor ve seçtiğiniz Wi-Fi ağına bağlanacak.',
    );
  }

  String _friendlyProvisionError(String? raw) {
    switch (raw) {
      case 'ERROR:KEY_MISMATCH':
        return 'Mevcut firma anahtarı cihazdaki anahtarla eşleşmiyor.';
      case 'ERROR:SEND_INTERVAL':
        return 'Gönderim aralığı yalnızca 1, 5 veya 15 dakika olabilir.';
      case 'ERROR:SSID':
        return 'Wi-Fi ağ adı geçersiz.';
      case 'ERROR:WIFI_PASSWORD':
        return 'Wi-Fi şifresi geçersiz.';
      case 'ERROR:SERIAL':
        return 'Seri numarası geçersiz.';
      case 'ERROR:KEY_LENGTH':
        return 'Firma anahtarı geçersiz.';
      case 'ERROR:DEVICE_NAME':
        return 'Cihaz adı geçersiz.';
      case 'ERROR:URL_SCHEME':
      case 'ERROR:URL':
        return 'Sunucu adresi geçersiz; HTTPS adresi kullanın.';
      case 'ERROR:SAVE':
        return 'Cihaz ayarları belleğe kaydedilemedi.';
      case 'ERROR:JSON':
      case 'ERROR:TOO_LARGE':
        return 'Cihaza gönderilen yapılandırma paketi geçersiz.';
      default:
        return raw?.isNotEmpty == true
            ? raw!
            : 'Yapılandırma cihaz tarafından kabul edilmedi.';
    }
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? hint,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      );

  @override
  Widget build(BuildContext context) {
    final info = _deviceInfo;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Icon(
                  Icons.wifi_tethering,
                  size: 62,
                  color: AppTheme.cyan,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'VISIONSEN WI-FI YAPILANDIRMA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'OIM3 v2.1.0 • Bluetooth kullanılmaz',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.green, fontSize: 11.5),
              ),
              const SizedBox(height: 18),
              const Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kurulum bağlantısı',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 10),
                    Text('1. ESP32 cihazı kapatıp açın.'),
                    SizedBox(height: 6),
                    Text('2. Telefonu VISIONSEN-OIM3-XXXX Wi-Fi ağına bağlayın.'),
                    SizedBox(height: 6),
                    SelectableText(
                      'Wi-Fi şifresi: VisionSenOIM3',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '3. Android “internet yok” uyarısı verirse bu ağa bağlı kalın ve uygulamaya dönün.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: 'WI-FI AYARLARINI AÇ',
                icon: Icons.settings_outlined,
                onPressed: _checking || _saving ? null : _openWifiSettings,
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                text: _checking
                    ? 'CİHAZ KONTROL EDİLİYOR...'
                    : 'BAĞLANTIYI KONTROL ET',
                onPressed: _checking || _saving ? null : _checkConnection,
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_messageIsError ? Colors.redAccent : AppTheme.green)
                        .withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_messageIsError
                              ? Colors.redAccent
                              : AppTheme.green)
                          .withOpacity(.28),
                    ),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _messageIsError
                          ? Colors.redAccent
                          : AppTheme.green,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              if (_connected && info != null) ...[
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bağlı cihaz',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text('Firmware: ${info['fw'] ?? '-'}'),
                      Text('Seri no: ${info['serial'] ?? '-'}'),
                      Text('MAC: ${info['mac'] ?? '-'}'),
                      Text(
                        _config.deviceAlreadyConfigured
                            ? 'Durum: Daha önce yapılandırılmış'
                            : 'Durum: İlk kurulum',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    children: [
                      TextField(
                        controller: _ssid,
                        decoration: _inputDecoration(
                          'Bağlanılacak Wi-Fi ağı (SSID)',
                          Icons.wifi,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: !_showWifiPassword,
                        decoration: _inputDecoration(
                          'Wi-Fi şifresi',
                          Icons.lock_outline,
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _showWifiPassword = !_showWifiPassword,
                            ),
                            icon: Icon(
                              _showWifiPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _deviceName,
                        decoration: _inputDecoration(
                          'Cihaz adı',
                          Icons.label_outline,
                          hint: 'Depo Sensör 1',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _serial,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _inputDecoration(
                          'Seri numarası',
                          Icons.qr_code_2,
                          hint: 'ESP-001',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _sendInterval,
                        decoration: _inputDecoration(
                          'Gönderim aralığı',
                          Icons.schedule_send_outlined,
                        ),
                        items: DeviceConfig.supportedSendIntervals
                            .map(
                              (minutes) => DropdownMenuItem<int>(
                                value: minutes,
                                child: Text('$minutes dakika'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sendInterval = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _serverUrl,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: _inputDecoration(
                          'Sunucu URL',
                          Icons.cloud_outlined,
                        ),
                      ),
                      if (_config.deviceAlreadyConfigured) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _currentCompanyKey,
                          obscureText: !_showCurrentCompanyKey,
                          autocorrect: false,
                          decoration: _inputDecoration(
                            'Mevcut firma anahtarı',
                            Icons.vpn_key_outlined,
                            suffix: IconButton(
                              onPressed: () => setState(
                                () => _showCurrentCompanyKey =
                                    !_showCurrentCompanyKey,
                              ),
                              icon: Icon(
                                _showCurrentCompanyKey
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _changeCompanyKey,
                          title: const Text('Firma anahtarını değiştir'),
                          onChanged: (value) => setState(
                            () => _changeCompanyKey = value == true,
                          ),
                        ),
                      ],
                      if (!_config.deviceAlreadyConfigured ||
                          _changeCompanyKey) ...[
                        const SizedBox(height: 4),
                        TextField(
                          controller: _companyKey,
                          obscureText: !_showCompanyKey,
                          autocorrect: false,
                          decoration: _inputDecoration(
                            _config.deviceAlreadyConfigured
                                ? 'Yeni firma anahtarı'
                                : 'Firma anahtarı',
                            Icons.key_outlined,
                            suffix: IconButton(
                              onPressed: () => setState(
                                () => _showCompanyKey = !_showCompanyKey,
                              ),
                              icon: Icon(
                                _showCompanyKey
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      PrimaryButton(
                        text: _saving
                            ? 'CİHAZA KAYDEDİLİYOR...'
                            : 'AYARLARI CİHAZA KAYDET',
                        icon: Icons.save_outlined,
                        onPressed: _saving ? null : _saveConfiguration,
                      ),
                    ],
                  ),
                ),
              ],
              if (_saved) ...[
                const SizedBox(height: 14),
                SecondaryButton(
                  text: 'BAŞKA CİHAZ YAPILANDIR',
                  onPressed: () {
                    setState(() {
                      _saved = false;
                      _deviceInfo = null;
                      _config.deviceAlreadyConfigured = false;
                    });
                    _openWifiSettings();
                  },
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Mobil v1.6.0+18 • Wi-Fi SoftAP Provisioning Protocol v2',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
