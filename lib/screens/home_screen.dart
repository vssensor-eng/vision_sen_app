import 'package:flutter/material.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppBackground(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.panel2,
                    border: Border.all(color: AppTheme.cyan.withOpacity(.22)),
                    boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(.16), blurRadius: 34)],
                  ),
                  child: const Icon(Icons.bluetooth_connected, size: 58, color: AppTheme.cyan),
                ),
                const SizedBox(height: 28),
                const Text('VISIONSEN', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2.3)),
                const SizedBox(height: 5),
                const Text('DEVICE SETUP', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 32),
                const Text(
                  'ESP32 cihazınızı Bluetooth ile bulun,\nayarlarını güvenli şekilde güncelleyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted, height: 1.5, fontSize: 14),
                ),
                const SizedBox(height: 38),
                PrimaryButton(
                  text: 'BAŞLAYALIM',
                  icon: Icons.bluetooth_searching,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScanScreen(ble: BleService()))),
                ),
                const Spacer(flex: 3),
                const Text('BLE DEVICE CONFIGURATION', style: TextStyle(color: AppTheme.muted, fontSize: 10, letterSpacing: 1.3)),
                const SizedBox(height: 6),
                const Text('v1.2.6', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      );
}
