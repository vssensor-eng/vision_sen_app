import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'wifi_screen.dart';

class VerifyScreen extends StatefulWidget {
  final BleDeviceModel device;
  final BleService ble;
  final DeviceConfig config;
  const VerifyScreen({super.key, required this.device, required this.ble, required this.config});
  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  // 0..2 = gerçek işlem adımları, 3 = tamamlandı
  int step = 0;
  bool failed = false;
  String errorText = '';
  Map<String, dynamic>? info;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      step = 0;
      failed = false;
      errorText = '';
    });

    final advertisedProtocol = widget.device.protocolVersion;
    if (advertisedProtocol != null &&
        !VisionSenCompatibility.isSupportedProtocol(advertisedProtocol)) {
      setState(() {
        failed = true;
        errorText = 'Bu cihaz BLE protokol v$advertisedProtocol kullanıyor. '
            'Bu uygulama bu protokol sürümünü desteklemiyor.';
      });
      return;
    }

    // 1) Bağlan
    final connected = await widget.ble.connect(widget.device);
    if (!mounted) return;
    if (!connected) {
      setState(() {
        failed = true;
        errorText = 'Cihaza bağlanılamadı.\n\nCihazın 60 saniyelik Bluetooth kurulum '
            'penceresi kapanmış olabilir. Cihazı fişten çekip tekrar takın ve '
            'hemen yeniden deneyin.';
      });
      return;
    }
    setState(() => step = 1);

    // 2) Cihaz bilgilerini oku
    final deviceInfo = await widget.ble.readDeviceInfo();
    if (!mounted) return;
    if (deviceInfo == null) {
      setState(() {
        failed = true;
        errorText = 'Cihaz bilgileri okunamadı.\n\nBağlandığınız cihaz VisionSen BLE '
            'kimlik şemasını yayınlamıyor olabilir.';
      });
      await widget.ble.disconnect();
      return;
    }
    setState(() {
      info = deviceInfo;
      step = 2;
    });

    // 3) Doğrula: uyumluluk firmware sürümüne göre değil, cihaz tipi +
    // protokol sürümüne göre belirlenir. Firmware yalnızca bilgi amaçlıdır.
    final serial = (deviceInfo['serial'] ?? '').toString();
    final protocol = deviceInfo['protocol_version'];
    final deviceType = (deviceInfo['device_type'] ?? '').toString();

    if (deviceInfo['protocol_mismatch'] == true) {
      setState(() {
        failed = true;
        errorText = 'Cihazın reklam paketindeki BLE protokolü ile INFO verisi eşleşmiyor. '
            'Güvenli kurulum için işlem durduruldu.';
      });
      await widget.ble.disconnect();
      return;
    }
    if (deviceInfo['identity_fields_valid'] != true || protocol is! int || deviceType.isEmpty) {
      setState(() {
        failed = true;
        errorText = 'Firmware zorunlu VisionSen kimlik alanlarını göndermiyor. '
            'Bu uygulama yalnızca device_type ve protocol_version alanlarını açıkça bildiren firmware ile çalışır.';
      });
      await widget.ble.disconnect();
      return;
    }
    if (!VisionSenCompatibility.isSupportedIdentity(deviceType, protocol)) {
      setState(() {
        failed = true;
        errorText = 'Bu firmware kimliği desteklenmiyor: '
            '${VisionSenCompatibility.deviceTypeLabel(deviceType)} / BLE protokol v$protocol.';
      });
      await widget.ble.disconnect();
      return;
    }
    setState(() => step = 3);

    // Cihazdan gelen gerçek değerleri forma ön-doldur. Bu ayrı bir ağ/oturum
    // işlemi değildir; doğrulamanın sonucudur.
    final configured = deviceInfo['configured'] == true;
    widget.config.deviceAlreadyConfigured = configured;
    if (serial.isNotEmpty && !DeviceConfig.isPlaceholderSerial(serial) && (configured || widget.config.serial.isEmpty)) {
      widget.config.serial = serial;
    }
    if (widget.config.deviceName.isEmpty) widget.config.deviceName = widget.device.name;

    if (!mounted) return;
  }

  @override
  Widget build(BuildContext c) {
    final labels = ['Cihaza bağlanılıyor', 'Cihaz bilgileri okunuyor', 'Cihaz uyumluluğu doğrulanıyor'];
    final done = step >= 3;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              StepHeader(step: 3, title: 'CİHAZ DOĞRULAMA'),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (failed ? Colors.redAccent : AppTheme.green).withOpacity(.1),
                  border: Border.all(color: (failed ? Colors.redAccent : AppTheme.green).withOpacity(.5)),
                ),
                child: Icon(failed ? Icons.error_outline : Icons.security, size: 60, color: failed ? Colors.redAccent : AppTheme.green),
              ),
              const SizedBox(height: 20),
              Text(
                failed
                    ? 'Doğrulama başarısız'
                    : done
                        ? 'Cihaz doğrulandı'
                        : 'Cihazla şifreli BLE bağlantısı kuruluyor...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (failed)
                Panel(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(errorText, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                  ),
                )
              else ...[
                Panel(
                  child: Column(
                    children: List.generate(
                      labels.length,
                      (i) => ListTile(
                        dense: true,
                        leading: Icon(
                          i < step ? Icons.check_circle : (i == step ? Icons.sync : Icons.radio_button_unchecked),
                          color: i < step ? AppTheme.green : (i == step ? AppTheme.cyan : Colors.white24),
                        ),
                        title: Text(labels[i]),
                      ),
                    ),
                  ),
                ),
                if (info != null) ...[
                  const SizedBox(height: 12),
                  Panel(
                    child: Column(
                      children: [
                        _row('Seri Numarası', (info!['serial'] ?? '-').toString()),
                        _row('Cihaz Tipi', VisionSenCompatibility.deviceTypeLabel((info!['device_type'] ?? '').toString())),
                        _row('BLE Protokolü', 'v${info!['protocol_version']}'),
                        _row('Firmware', ((info!['fw'] ?? '').toString().trim().isEmpty) ? '—' : info!['fw'].toString()),
                        _row('MAC', (info!['mac'] ?? '-').toString()),
                        _row('Durum', (info!['configured'] == true) ? 'Daha önce kurulmuş' : 'Kurulum bekliyor'),
                      ],
                    ),
                  ),
                ],
              ],
              const Spacer(),
              if (failed)
                PrimaryButton(text: 'TEKRAR DENE', onPressed: _run)
              else if (done)
                PrimaryButton(
                  text: 'DEVAM',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WifiScreen(config: widget.config, ble: widget.ble)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(a, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
          const Spacer(),
          Flexible(child: Text(b, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );
}
