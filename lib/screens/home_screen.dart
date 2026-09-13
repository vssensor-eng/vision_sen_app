import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleService _ble = BleService();
  bool _bluetoothActionRunning = false;
  Future<bool> _requestBluetoothConsent() async {
    if (_bluetoothActionRunning) return false;

    final state = await _ble.getAdapterState();
    if (!mounted) return false;
    if (state == BluetoothAdapterState.on) return true;
    if (state == BluetoothAdapterState.unavailable) {
      await _showBluetoothUnavailable();
      return false;
    }

    final approved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.bluetooth, color: AppTheme.cyan),
                SizedBox(width: 10),
                Expanded(child: Text('Bluetooth kapalı')),
              ],
            ),
            content: const Text(
              'VisionSen cihazlarını bulmak ve kurmak için telefonunuzun Bluetooth bağlantısının açık olması gerekir.\n\nBluetooth açılsın mı?',
              style: TextStyle(height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ŞİMDİ DEĞİL'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.bluetooth),
                label: const Text('BLUETOOTH\'U AÇ'),
              ),
            ],
          ),
        ) ??
        false;

    if (!approved || !mounted) return false;

    setState(() => _bluetoothActionRunning = true);
    final enabled = await _ble.enableBluetoothAfterUserConsent();
    if (!mounted) return enabled;
    setState(() => _bluetoothActionRunning = false);

    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth açılmadı. Devam etmek için Bluetooth erişimine izin verin ve açma isteğini onaylayın.'),
        ),
      );
    }
    return enabled;
  }

  Future<void> _showBluetoothUnavailable() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bluetooth kullanılamıyor'),
        content: const Text('Bu cihazda Bluetooth kullanılamıyor veya sistem tarafından erişime kapalı.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('TAMAM'),
          ),
        ],
      ),
    );
  }

  Future<void> _startSetup() async {
    if (_bluetoothActionRunning) return;

    var state = await _ble.getAdapterState();
    if (!mounted) return;

    if (state != BluetoothAdapterState.on) {
      final enabled = await _requestBluetoothConsent();
      if (!enabled || !mounted) return;
      state = await _ble.getAdapterState();
      if (state != BluetoothAdapterState.on) return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanScreen(ble: _ble)),
    );
  }

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
                const Text('CİHAZ YAPILANDIRMA', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 32),
                const Text(
                  'ESP32 cihazınızı Bluetooth ile bulun,\nayarlarını mevcut BLE akışıyla yapılandırın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted, height: 1.5, fontSize: 14),
                ),
                const SizedBox(height: 38),
                PrimaryButton(
                  text: _bluetoothActionRunning ? 'BLUETOOTH AÇILIYOR...' : 'BAŞLAYALIM',
                  icon: _bluetoothActionRunning ? Icons.hourglass_top : Icons.bluetooth_searching,
                  onPressed: _bluetoothActionRunning ? null : _startSetup,
                ),
                const Spacer(flex: 3),
                const Text('LOGIN KORUMALI BLE DEVICE CONFIGURATION', style: TextStyle(color: AppTheme.muted, fontSize: 10, letterSpacing: 1.1)),
                const SizedBox(height: 6),
                const Text('Mobil v1.3.0', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      );
}
