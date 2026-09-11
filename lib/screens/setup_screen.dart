import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'complete_screen.dart';

class SetupScreen extends StatefulWidget {
  final DeviceConfig config;
  final BleService ble;
  const SetupScreen({super.key, required this.config, required this.ble});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool sending = true;
  bool failed = false;
  String? errorCode;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      sending = true;
      failed = false;
      errorCode = null;
    });

    final ok = await widget.ble.writeConfiguration(widget.config);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        sending = false;
        failed = true;
        errorCode = widget.ble.lastError;
      });
      return;
    }

    await widget.ble.disconnect();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CompleteScreen(config: widget.config)),
    );
  }

  String _explain(String? code) {
    if (code != null && !code.startsWith('ERROR:')) return code;
    switch (code) {
      case 'ERROR:SSID':
        return 'Cihaz WiFi ağ adını reddetti. SSID boş olamaz.';
      case 'ERROR:URL':
        return 'Cihaz sunucu adresini reddetti. Alan adı/IP, port veya adres biçimini kontrol edin.';
      case 'ERROR:URL_SCHEME':
        return 'Cihaz sunucu adresini reddetti. Adres http:// veya https:// ile başlamalıdır.';
      case 'ERROR:SERIAL':
        return 'Cihaz seri numarasını reddetti. Gerçek seri numarasını kullanın; 1-64 karakter ve yalnızca harf, rakam, tire/alt çizgi olabilir.';
      case 'ERROR:KEY_LENGTH':
        return 'Cihaz firma anahtarını reddetti. 32-128 karakter ve geçerli karakterlerden oluşmalıdır.';
      case 'ERROR:KEY_MISMATCH':
        return 'Bu cihaz daha önce kurulmuş. Girilen firma anahtarı cihazda kayıtlı mevcut firma anahtarıyla eşleşmiyor. Doğru mevcut firma anahtarını girip tekrar deneyin.';
      case 'ERROR:DEVICE_NAME':
        return 'Cihaz adı BLE reklamı için geçersiz. Adı boş bırakmayın, kontrol karakteri kullanmayın ve en fazla 28 UTF-8 byte kullanın.';
      case 'ERROR:JSON':
      case 'ERROR:TOO_LARGE':
        return 'Ayar paketi cihaza eksik veya bozuk ulaştı. Cihaza yaklaşıp tekrar deneyin.';
      case 'ERROR:SAVE':
        return 'Cihaz ayarları kalıcı hafızasına tam olarak yazamadı. Cihazı yeniden başlatıp tekrar deneyin.';
      default:
        return 'Bluetooth bağlantısı kesildi veya kurulum penceresi kapanmış olabilir. Cihazı yeniden açıp tekrar deneyin.';
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                StepHeader(step: 8, title: 'KURULUM'),
                const SizedBox(height: 38),
                if (failed) ...[
                  const Icon(
                    Icons.error_outline,
                    size: 72,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Ayarlar cihaza gönderilemedi',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _explain(errorCode),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(),
                  PrimaryButton(text: 'TEKRAR DENE', onPressed: _start),
                ] else ...[
                  const SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      strokeWidth: 7,
                      color: AppTheme.cyan,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    sending
                        ? 'Ayarlar cihaza güvenli BLE bağlantısı üzerinden gönderiliyor...'
                        : 'Tamamlanıyor...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  const Panel(
                    child: Row(
                      children: [
                        Icon(Icons.save_outlined, color: AppTheme.cyan),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bu ekran yalnızca cihazın ayarları kabul edip kalıcı hafızaya kaydetmesini bekler. Wi-Fi ve sunucu erişimi sonraki cihaz çalışma döngüsünde gerçekleşir.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
