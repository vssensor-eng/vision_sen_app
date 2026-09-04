import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'select_device_screen.dart';

class ScanScreen extends StatefulWidget {
  final BleService ble;
  const ScanScreen({super.key, required this.ble});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BleDeviceModel> devices = [];
  bool scanning = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => scanning = true);
    final d = await widget.ble.scan();
    if (mounted) {
      setState(() {
        devices = [...d]..sort((a, b) => b.rssi.compareTo(a.rssi));
        scanning = false;
      });
    }
  }

  String _status(BleDeviceModel d) {
    final protocol = d.protocolVersion;
    if (protocol != null && !VisionSenCompatibility.isSupportedProtocol(protocol)) {
      return 'BLE protokol v$protocol desteklenmiyor';
    }
    if (d.configured == true) return 'Kurulu';
    if (d.configured == false) return 'Kurulum bekliyor';
    return 'Durum bağlantıda okunacak';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                StepHeader(step: 1, title: 'CİHAZ TARA', onBack: () => Navigator.pop(context)),
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cyan.withOpacity(.45)),
                    boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(.08), blurRadius: 30)],
                  ),
                  child: Center(child: Icon(scanning ? Icons.bluetooth_searching : Icons.bluetooth, size: 58, color: AppTheme.cyan)),
                ),
                const SizedBox(height: 18),
                Text(scanning ? 'Yakındaki cihazlar aranıyor...' : 'Cihazlar bulundu', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (c, i) {
                      final d = devices[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SelectDeviceScreen(device: d, ble: widget.ble))),
                        child: Panel(
                          child: Row(
                            children: [
                              const Icon(Icons.memory, color: AppTheme.cyan),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('${_status(d)}  •  RSSI: ${d.rssi} dBm', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Icon(Icons.signal_cellular_alt, color: d.rssi > -60 ? AppTheme.green : Colors.amber),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                TextButton.icon(onPressed: _scan, icon: const Icon(Icons.refresh), label: const Text('Tekrar tara')),
              ],
            ),
          ),
        ),
      );
}
