import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'summary_screen.dart';

class ServerScreen extends StatefulWidget {
  final DeviceConfig config;
  final BleService ble;
  const ServerScreen({super.key, required this.config, required this.ble});
  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  late TextEditingController url;
  String? error;

  @override
  void initState() {
    super.initState();
    url = TextEditingController(text: widget.config.serverUrl);
  }

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  StepHeader(step: 6, title: 'SUNUCU BİLGİLERİ'),
                  const CircleAvatar(radius: 42, backgroundColor: AppTheme.panel2, child: Icon(Icons.language, size: 44, color: AppTheme.cyan)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: url,
                    maxLines: 2,
                    onChanged: (_) { if (error != null) setState(() => error = null); },
                    decoration: InputDecoration(labelText: 'API / POST Adresi', hintText: 'https://sunucu-adresi.com/...', errorText: error),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cihaz hem http:// hem https:// destekler; güvenlik ayrıca cihazın gönderdiği dijital imza ile sağlanır.',
                      style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: widget.config.timezone,
                    decoration: const InputDecoration(labelText: 'Zaman Dilimi'),
                    items: const [
                      DropdownMenuItem(value: '(UTC+03:00) İstanbul', child: Text('(UTC+03:00) İstanbul')),
                      DropdownMenuItem(value: '(UTC+00:00) UTC', child: Text('(UTC+00:00) UTC')),
                    ],
                    onChanged: (v) => setState(() => widget.config.timezone = v!),
                  ),
                  const SizedBox(height: 30),
                  PrimaryButton(
                    text: 'İLERİ',
                    onPressed: () {
                      final value = url.text.trim();
                      final validation = DeviceConfig.validateServerUrl(value);
                      if (validation != null) {
                        setState(() => error = validation);
                        return;
                      }
                      widget.config.serverUrl = value;
                      Navigator.push(c, MaterialPageRoute(builder: (_) => SummaryScreen(config: widget.config, ble: widget.ble)));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
