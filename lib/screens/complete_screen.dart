import 'package:flutter/material.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

class CompleteScreen extends StatelessWidget {
  final DeviceConfig config;
  const CompleteScreen({super.key, required this.config});

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  StepHeader(step: 9, title: 'TAMAMLANDI', onBack: null),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.green.withOpacity(.1),
                      border: Border.all(color: AppTheme.green, width: 2),
                    ),
                    child: const Icon(Icons.check_rounded, size: 80, color: AppTheme.green),
                  ),
                  const SizedBox(height: 18),
                  const Text('Ayarlar gönderildi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                    'Cihaz ayarları kaydetti ve yeniden başlıyor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  // Yalnızca uygulamanın GERÇEKTEN bildiği, cihaza gönderilen değerler
                  // gösterilir. Wi-Fi bağlantısı, sunucu erişimi ve sinyal gücü BLE
                  // bağlantısı kesildiği için uygulama tarafından bilinemez.
                  Panel(
                    child: Column(children: [
                      _r('Cihaz Adı', config.deviceName.isEmpty ? '—' : config.deviceName),
                      _r('Seri Numarası', config.serial),
                      _r('WiFi Ağı', config.ssid),
                      _r('Sunucu', Uri.tryParse(config.serverUrl)?.host ?? config.serverUrl),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cyan.withOpacity(.4)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: AppTheme.cyan, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cihazın Wi-Fi ve sunucuya gerçekten bağlandığını doğrulamak için '
                          'yönetim panelinden cihazın veri gönderip göndermediğini kontrol edin. '
                          'Ölçümler yaklaşık bir dakika içinde görünmeye başlar.',
                          style: TextStyle(color: AppTheme.cyan, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(text: 'BİTİR', onPressed: () => Navigator.popUntil(c, (r) => r.isFirst)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _r(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Text(a, style: const TextStyle(color: AppTheme.muted)),
          const Spacer(),
          Flexible(child: Text(b, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}
