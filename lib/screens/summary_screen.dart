import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'setup_screen.dart';

class SummaryScreen extends StatelessWidget {
  final DeviceConfig config;
  final BleService ble;
  const SummaryScreen({super.key, required this.config, required this.ble});

  @override
  Widget build(BuildContext context) {
    final error = config.validate();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              StepHeader(step: 7, title: 'AYAR ÖZETİ'),
              Panel(
                child: Column(children: [
                  _r('Cihaz Adı', config.deviceName.isEmpty ? '—' : config.deviceName),
                  _r('Seri Numarası', config.serial.isEmpty ? '—' : config.serial),
                  _r('WiFi Ağı', config.ssid.isEmpty ? '—' : config.ssid),
                  _r('WiFi Şifresi', config.password.isEmpty ? '—' : '•' * config.password.length),
                  if (config.deviceAlreadyConfigured) ...[
                    _r(
                      'Mevcut Firma Anahtarı',
                      config.currentCompanyKey.isEmpty ? '—' : '${config.currentCompanyKey.length} karakter (doğrulama için)',
                    ),
                    _r(
                      'Firma Anahtarı Değişikliği',
                      config.changeCompanyKey ? 'Yeni anahtar kaydedilecek' : 'Yapılmayacak',
                    ),
                    if (config.changeCompanyKey)
                      _r(
                        'Yeni Firma Anahtarı',
                        config.companyKey.isEmpty ? '—' : '${config.companyKey.length} karakter',
                      ),
                  ] else
                    _r('Firma Anahtarı', config.companyKey.isEmpty ? '—' : '${config.companyKey.length} karakter'),
                  _r('Sunucu', config.serverUrl.isEmpty ? '—' : (Uri.tryParse(config.serverUrl)?.host ?? config.serverUrl)),
                  _r('Zaman Dilimi', config.timezone),
                ]),
              ),
              const SizedBox(height: 18),
              if (error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withOpacity(.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(child: Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                  ]),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.green.withOpacity(.4)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.shield_outlined, color: AppTheme.green),
                    SizedBox(width: 10),
                    Expanded(child: Text('Bilgiler BLE bağlantısı üzerinden cihazınıza gönderilecektir.', style: TextStyle(color: AppTheme.green, fontSize: 12))),
                  ]),
                ),
              const Spacer(),
              if (error != null)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('GERİ DÖN VE DÜZELT'),
                )
              else
                PrimaryButton(
                  text: 'CİHAZI GÜNCELLE',
                  icon: Icons.upload_rounded,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SetupScreen(config: config, ble: ble))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _r(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(a, style: const TextStyle(color: AppTheme.muted)),
          const Spacer(),
          Flexible(child: Text(b, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}
