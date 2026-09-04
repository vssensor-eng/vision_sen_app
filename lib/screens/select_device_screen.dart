import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'verify_screen.dart';

class SelectDeviceScreen extends StatelessWidget {
  final BleDeviceModel device;
  final BleService ble;
  const SelectDeviceScreen({super.key, required this.device, required this.ble});

  @override
  Widget build(BuildContext context) {
    final isVisionSen = device.isVisionSen;
    final protocol = device.protocolVersion;
    final protocolSupported = protocol == null || VisionSenCompatibility.isSupportedProtocol(protocol);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              StepHeader(step: 2, title: 'CİHAZI SEÇ'),
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cyan.withOpacity(.6)),
                  color: AppTheme.panel,
                ),
                child: const Icon(Icons.router, size: 90, color: Colors.white70),
              ),
              const SizedBox(height: 18),
              Text(device.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Panel(
                child: Column(children: [
                  _row('Tür', isVisionSen ? 'VisionSen cihazı' : 'Bilinmiyor'),
                  _row('BLE Protokolü', protocol == null ? 'Bağlantıda okunacak' : 'v$protocol${protocolSupported ? '' : ' — desteklenmiyor'}'),
                  _row('Sinyal', '${device.rssi} dBm'),
                  _row('Cihaz Kimliği', device.mac),
                ]),
              ),
              if (!isVisionSen) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(.5)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu cihaz VisionSen servisini yayınlamıyor. Bağlantı büyük ihtimalle başarısız olacak.',
                        style: TextStyle(color: Colors.amber, fontSize: 11.5),
                      ),
                    ),
                  ]),
                ),
              ],
              if (isVisionSen && !protocolSupported) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.block, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu cihaz BLE protokol v$protocol kullanıyor. Bu uygulama bu protokol sürümünü desteklemiyor.',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                      ),
                    ),
                  ]),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                text: protocolSupported ? 'BAĞLAN' : 'PROTOKOL DESTEKLENMİYOR',
                icon: protocolSupported ? Icons.bluetooth_connected : Icons.block,
                onPressed: protocolSupported
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => VerifyScreen(device: device, ble: ble, config: DeviceConfig())),
                        )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Text(a, style: const TextStyle(color: AppTheme.muted)),
          const Spacer(),
          Flexible(child: Text(b, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
