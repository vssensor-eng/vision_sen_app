import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/wifi_provision_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

class WifiProvisionScreen extends StatefulWidget {
  final WifiProvisionService provision;

  const WifiProvisionScreen({super.key, required this.provision});

  @override
  State<WifiProvisionScreen> createState() => _WifiProvisionScreenState();
}

class _WifiProvisionScreenState extends State<WifiProvisionScreen> {
  late final WifiProvisionService _provision;
  final DeviceConfig _config = DeviceConfig();

  final _ssid = TextEditingController();
  final _password = TextEditingController();
  final _deviceName = TextEditingController();
  final _serverUrl = TextEditingController(
    text: 'https://www.vsias.com/wp-json/oim/v1/ingest',
  );
  final _companyKey = TextEditingController();
  final _currentCompanyKey = TextEditingController();

  bool _busy = false;
  bool _saved = false;
  bool _showWifiPassword = false;
  bool _showCompanyKey = false;
  bool _showCurrentCompanyKey = false;
  bool _changeCompanyKey = false;
  int _sendInterval = 1;
  Map<String, dynamic>? _deviceInfo;
  List<ProvisioningWifiDevice> _foundDevices = const [];
  String? _connectingSsid;
  String? _message;
  bool _messageIsError = false;

  bool get _connected => _provision.isConnected;

  @override
  void initState() {
    super.initState();
    _provision = widget.provision;
    _provision.connectionNotifier.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    if (!_provision.isConnected) {
      _deviceInfo = null;
      _connectingSsid = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _provision.connectionNotifier.removeListener(_onConnectionChanged);
    _ssid.dispose();
    _password.dispose();
    _deviceName.dispose();
    _serverUrl.dispose();
    _companyKey.dispose();
    _currentCompanyKey.dispose();
    super.dispose();
  }

  void _setMessage(String? value, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _messageIsError = error;
    });
  }

  Future<void> _scanDevices() async {
    if (_busy || _connected) return;
    setState(() {
      _busy = true;
      _saved = false;
      _foundDevices = const [];
      _message = 'Yakındaki VisionSen cihazları aranıyor...';
      _messageIsError = false;
    });

    final devices = await _provision.scanDevices();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _foundDevices = devices;
    });

    if (devices.isEmpty) {
      _setMessage(
        _provision.lastError ?? 'Yakında VisionSen kurulum cihazı bulunamadı.',
        error: true,
      );
      return;
    }

    if (devices.length == 1) {
      await _connectDevice(devices.first);
      return;
    }

    _setMessage(
      '${devices.length} VisionSen cihazı bulundu. Bağlanmak istediğiniz cihazı seçin.',
    );
  }

  Future<void> _connectDevice(ProvisioningWifiDevice device) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _saved = false;
      _connectingSsid = device.ssid;
      _message = '${device.ssid} cihazına bağlanılıyor...';
      _messageIsError = false;
    });

    final connected = await _provision.connectToDevice(device.ssid);
    if (!mounted) return;
    if (!connected) {
      setState(() {
        _busy = false;
        _connectingSsid = null;
      });
      _setMessage(
        _provision.lastError ?? 'VisionSen cihazına bağlanılamadı.',
        error: true,
      );
      return;
    }

    await _readInfo();
  }

  Future<void> _readInfo() async {
    if (!_connected) return;
    setState(() => _busy = true);
    final info = await _provision.readDeviceInfo();
    if (!mounted) return;

    if (info == null) {
      setState(() {
        _busy = false;
        _connectingSsid = null;
      });
      _setMessage(
        _provision.lastError ?? 'VisionSen cihazına ulaşılamadı.',
        error: true,
      );
      return;
    }

    final deviceType = info['device_type']?.toString() ?? '';
    final protocol = info['protocol_version'] as int?;
    final transport = info['transport']?.toString() ?? '';
    if (transport != 'wifi_softap' ||
        protocol == null ||
        !VisionSenCompatibility.isSupportedIdentity(deviceType, protocol)) {
      await _provision.disconnect();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _connectingSsid = null;
      });
      _setMessage(
        'Seçilen ağ desteklenen VisionSen OIM3 kurulum cihazı değil.',
        error: true,
      );
      return;
    }

    final configured =
        info['configured'] == true || '${info['configured']}' == 'true';
    final serial = info['serial']?.toString().trim() ?? '';
    final serialLocked = info['serial_locked'] == true ||
        '${info['serial_locked']}' == 'true';
    final identitySource = info['identity_source']?.toString().trim() ?? '';
    final name = info['device_name']?.toString().trim() ?? '';
    final interval = info['send_interval_minutes'] as int? ?? 1;

    if (serial.isEmpty || !serialLocked || identitySource != 'factory_data') {
      await _provision.disconnect();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _connectingSsid = null;
      });
      _setMessage(
        'Cihaz üretici seri kimliğini doğrulamadı. factory_data seri numarası gerekli.',
        error: true,
      );
      return;
    }
    if (name.isNotEmpty) _deviceName.text = name;
    if (DeviceConfig.isSupportedSendInterval(interval)) {
      _sendInterval = interval;
    }

    _config.deviceAlreadyConfigured = configured;
    setState(() {
      _busy = false;
      _deviceInfo = info;
      _saved = false;
      _connectingSsid = null;
    });
    _setMessage(
      configured
          ? 'Cihaz bulundu ve yerel API doğrulandı. Ayar değişikliği için mevcut firma anahtarını girin.'
          : 'Cihaz bulundu ve yerel API doğrulandı. Wi-Fi ve sunucu bilgilerini doldurup kaydedin.',
    );
  }

  Future<void> _disconnect({bool showMessage = true}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _provision.disconnect();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _deviceInfo = null;
      _connectingSsid = null;
    });
    if (showMessage) {
      _setMessage(
        'Cihaz Wi-Fi bağlantısı sonlandırıldı. Normal internet bağlantınız kullanılabilir.',
      );
    }
  }

  String? _prepareConfig() {
    _config
      ..ssid = _ssid.text.trim()
      ..password = _password.text
      ..deviceName = _deviceName.text.trim()
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

  Future<void> _save() async {
    if (_busy || !_connected) return;
    final validation = _prepareConfig();
    if (validation != null) {
      _setMessage(validation, error: true);
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });
    final ok = await _provision.writeConfiguration(_config);
    if (!mounted) return;

    if (!ok) {
      setState(() => _busy = false);
      _setMessage(_friendlyProvisionError(_provision.lastError), error: true);
      return;
    }

    await _provision.disconnect();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = true;
      _deviceInfo = null;
      _foundDevices = const [];
      _connectingSsid = null;
    });
    _setMessage(
      'Ayarlar kaydedildi. Cihaz bağlantısı kapatıldı; ESP yeniden başlıyor ve hedef Wi-Fi ağına bağlanacak.',
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
      case 'ERROR:SERIAL_READ_ONLY':
        return 'Seri numarası üretici kimliğidir ve mobil uygulamadan değiştirilemez.';
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

  InputDecoration _decoration(
    String label,
    IconData icon, {
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
    );
  }

  IconData _signalIcon(int bars) {
    if (bars >= 4) return Icons.signal_wifi_4_bar;
    if (bars == 3) return Icons.network_wifi_3_bar;
    if (bars == 2) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  Widget _deviceList() {
    if (_foundDevices.isEmpty || _connected) return const SizedBox.shrink();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bulunan VisionSen cihazları',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _scanDevices,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Yenile'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._foundDevices.map(
            (device) => Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppTheme.panel2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.line),
              ),
              child: ListTile(
                leading: Icon(
                  _signalIcon(device.signalBars),
                  color: AppTheme.cyan,
                ),
                title: Text(
                  device.ssid,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${device.rssi} dBm • Kurulum cihazı',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                trailing: _busy && _connectingSsid == device.ssid
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _connectDevice(device),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                'OIM3 v2.1.4 • Üretici seri kimliği + konum izinsiz bağlantı',
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
                    Text('2. CİHAZLARI BUL düğmesine dokunun.'),
                    SizedBox(height: 6),
                    Text(
                      '3. Android cihaz seçim ekranında VISIONSEN-OIM3 cihazını seçin. Konum izni kullanılmaz.',
                    ),
                    SizedBox(height: 6),
                    Text(
                      '4. Android 13+ cihazlarda Yakındaki Wi-Fi cihazları izni istenebilir. Bu izin konum bilgisi için kullanılmaz.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Kurulum bitince veya uygulamadan ayrılınca cihaz bağlantısı otomatik kapatılır.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: _busy
                    ? 'İŞLEM YAPILIYOR...'
                    : _connected
                        ? 'CİHAZ BAĞLANTISINI KES'
                        : 'CİHAZLARI BUL',
                icon: _connected ? Icons.link_off : Icons.wifi_find,
                onPressed: _busy
                    ? null
                    : _connected
                        ? () => _disconnect()
                        : _scanDevices,
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
              if (_foundDevices.isNotEmpty && !_connected) ...[
                const SizedBox(height: 14),
                _deviceList(),
              ],
              if (_connected) ...[
                const SizedBox(height: 10),
                SecondaryButton(
                  text: 'CİHAZI YENİDEN KONTROL ET',
                  onPressed: _busy ? null : _readInfo,
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
                      Text(
                        'Kurulum ağı: ${_provision.connectedSsid ?? WifiProvisionService.apNamePattern}',
                      ),
                      Text(
                        'Telefon yerel IP: ${_provision.connectedLocalIp ?? '-'}',
                      ),
                      Text('Firmware: ${info['fw'] ?? '-'}'),
                      Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 15, color: AppTheme.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Üretici seri no: ${info['serial'] ?? '-'}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      Text('HW-ID: ${info['hw_id'] ?? '-'}'),
                      Text('MAC: ${info['mac'] ?? '-'}'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    children: [
                      TextField(
                        controller: _ssid,
                        decoration: _decoration(
                          'Bağlanılacak Wi-Fi ağı (SSID)',
                          Icons.wifi,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: !_showWifiPassword,
                        decoration: _decoration(
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
                        decoration: _decoration(
                          'Cihaz adı',
                          Icons.label_outline,
                          hint: 'Depo Sensör 1',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _sendInterval,
                        decoration: _decoration(
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
                        decoration: _decoration(
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
                          decoration: _decoration(
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
                          decoration: _decoration(
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
                        text: _busy
                            ? 'CİHAZA KAYDEDİLİYOR...'
                            : 'AYARLARI CİHAZA KAYDET',
                        icon: Icons.save_outlined,
                        onPressed: _busy ? null : _save,
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
                    _scanDevices();
                  },
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Mobil v1.6.6+24 • Üretici seri kimliği salt-okunur',
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
