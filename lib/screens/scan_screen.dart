import 'dart:async';
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
  static const int _scanDurationSeconds = 60;

  List<BleDeviceModel> devices = [];
  bool scanning = true;
  String? scanError;
  int _remainingSeconds = _scanDurationSeconds;
  Timer? _countdownTimer;
  int _scanGeneration = 0;
  bool _openingDevice = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _scanGeneration++;
    _countdownTimer?.cancel();
    // dispose senkron olduğu için await edilmez; BleService güvenli şekilde
    // açık taramayı kapatır.
    unawaited(widget.ble.stopScan());
    super.dispose();
  }

  List<BleDeviceModel> _sorted(List<BleDeviceModel> input) =>
      [...input]..sort((a, b) => b.rssi.compareTo(a.rssi));

  Future<void> _scan() async {
    final generation = ++_scanGeneration;
    _countdownTimer?.cancel();

    setState(() {
      devices = [];
      scanning = true;
      scanError = null;
      _remainingSeconds = _scanDurationSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || generation != _scanGeneration || !scanning) {
        timer.cancel();
        return;
      }
      final remaining = _scanDurationSeconds - timer.tick;
      setState(() => _remainingSeconds = remaining.clamp(0, _scanDurationSeconds).toInt());
    });

    final result = await widget.ble.scan(
      timeout: const Duration(seconds: _scanDurationSeconds),
      onUpdate: (current) {
        if (!mounted || generation != _scanGeneration || _openingDevice) return;
        setState(() => devices = _sorted(current));
      },
    );

    if (!mounted || generation != _scanGeneration || _openingDevice) return;
    _countdownTimer?.cancel();
    setState(() {
      devices = _sorted(result);
      scanError = widget.ble.lastScanError;
      scanning = false;
      _remainingSeconds = 0;
    });
  }

  Future<void> _selectDevice(BleDeviceModel device) async {
    if (_openingDevice) return;

    _openingDevice = true;
    _scanGeneration++;
    _countdownTimer?.cancel();

    if (mounted) {
      setState(() => scanning = false);
    }

    await widget.ble.stopScan();
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDeviceScreen(device: device, ble: widget.ble),
      ),
    );

    if (!mounted) return;
    _openingDevice = false;
    setState(() {});
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

  Widget _deviceList() {
    if (devices.isEmpty) {
      if (scanning) {
        return const Center(
          child: Panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bluetooth_searching, color: AppTheme.cyan, size: 34),
                SizedBox(height: 12),
                Text(
                  'VisionSen cihazı bulunduğunda burada anında listelenecek.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bluetooth_disabled, color: Colors.amber, size: 34),
              const SizedBox(height: 12),
              Text(
                scanError ?? '60 saniyelik tarama tamamlandı; VisionSen cihazı bulunamadı.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (scanError == null)
                const Text(
                  'Cihaza enerji verildiğinden ve BLE kurulum penceresinin açık olduğundan emin olup tekrar tarayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.4),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (c, i) {
        final d = devices[i];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openingDevice ? null : () => _selectDevice(d),
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
                      Text(
                        '${_status(d)}  •  RSSI: ${d.rssi} dBm',
                        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.muted),
              ],
            ),
          ),
        );
      },
    );
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
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cyan.withOpacity(.45)),
                    boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(.08), blurRadius: 30)],
                  ),
                  child: Center(
                    child: Icon(
                      scanning ? Icons.bluetooth_searching : Icons.bluetooth,
                      size: 54,
                      color: AppTheme.cyan,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  scanning
                      ? devices.isEmpty
                          ? 'Yakındaki VisionSen cihazları aranıyor...'
                          : '${devices.length} cihaz bulundu • tarama devam ediyor'
                      : scanError != null
                          ? devices.isEmpty
                              ? 'Tarama tamamlanamadı'
                              : '${devices.length} cihaz bulundu • tarama durdu'
                          : devices.isEmpty
                              ? 'VisionSen cihazı bulunamadı'
                              : '${devices.length} cihaz bulundu',
                  style: TextStyle(
                    color: !scanning && devices.isEmpty ? Colors.amber : Colors.white70,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(child: _deviceList()),
                const SizedBox(height: 12),
                if (scanning) ...[
                  LinearProgressIndicator(
                    value: (_scanDurationSeconds - _remainingSeconds) / _scanDurationSeconds,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tarama devam ediyor • $_remainingSeconds sn kaldı',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Bir cihaz seçtiğinizde tarama durur ve kuruluma devam edilir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ] else
                  TextButton.icon(
                    onPressed: _openingDevice ? null : _scan,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tekrar tara'),
                  ),
              ],
            ),
          ),
        ),
      );
}
