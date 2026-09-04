import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'device_info_screen.dart';

class WifiScreen extends StatefulWidget {
  final DeviceConfig config;
  final BleService ble;
  const WifiScreen({super.key, required this.config, required this.ble});
  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  late final TextEditingController ssid;
  late final TextEditingController pass;
  bool show = false;
  String? error;

  @override
  void initState() {
    super.initState();
    ssid = TextEditingController(text: widget.config.ssid);
    pass = TextEditingController(text: widget.config.password);
  }

  @override
  void dispose() {
    ssid.dispose();
    pass.dispose();
    super.dispose();
  }

  void _next() {
    final trimmedSsid = ssid.text.trim();
    if (trimmedSsid.isEmpty) {
      setState(() => error = 'WiFi ağ adı (SSID) boş bırakılamaz.');
      return;
    }
    widget.config.ssid = trimmedSsid;
    widget.config.password = pass.text;
    Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceInfoScreen(config: widget.config, ble: widget.ble)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppBackground(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                StepHeader(step: 4, title: 'WİFİ BİLGİLERİ'),
                const SectionIcon(icon: Icons.wifi_rounded),
                const SizedBox(height: 24),
                TextField(
                  controller: ssid,
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'WiFi Ağı (SSID)',
                    hintText: 'Ağ adını elle yazın',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Yalnızca 2.4 GHz ağlar desteklenir. Ağ adını cihazınızın Wi-Fi ayarlarından kontrol edip buraya birebir yazın.',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pass,
                  obscureText: !show,
                  decoration: InputDecoration(
                    labelText: 'WiFi Şifresi',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => show = !show),
                      icon: Icon(show ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const Spacer(),
                PrimaryButton(text: 'İLERİ', onPressed: _next),
              ],
            ),
          ),
        ),
      );
}
