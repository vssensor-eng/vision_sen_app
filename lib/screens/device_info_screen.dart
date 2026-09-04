import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'server_screen.dart';

class DeviceInfoScreen extends StatefulWidget {
  final DeviceConfig config;
  final BleService ble;
  const DeviceInfoScreen({super.key, required this.config, required this.ble});
  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  late final TextEditingController name, serial, key, currentKey;
  bool showKey = false;
  bool showCurrentKey = false;
  bool changeCompanyKey = false;

  bool get _alreadyConfigured => widget.config.deviceAlreadyConfigured;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.config.deviceName);
    serial = TextEditingController(text: widget.config.serial);
    changeCompanyKey = _alreadyConfigured && widget.config.changeCompanyKey;
    key = TextEditingController(text: changeCompanyKey ? widget.config.companyKey : '');
    currentKey = TextEditingController(text: widget.config.currentCompanyKey);
    key.addListener(_refresh);
    currentKey.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    key.removeListener(_refresh);
    currentKey.removeListener(_refresh);
    name.dispose();
    serial.dispose();
    key.dispose();
    currentKey.dispose();
    super.dispose();
  }

  Widget _keyField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback toggle,
  }) {
    final value = controller.text.trim();
    final validation = value.isEmpty ? null : DeviceConfig.validateCompanyKey(value, label: label);
    final ok = value.isNotEmpty && validation == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: !show,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: IconButton(
              onPressed: toggle,
              icon: Icon(show ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.isEmpty
              ? '${DeviceConfig.minCompanyKeyLength}-${DeviceConfig.maxCompanyKeyLength} karakter olmalı'
              : ok
                  ? '${value.length} karakter — uygun'
                  : (validation ?? 'Firma anahtarı geçersiz.'),
          style: TextStyle(
            fontSize: 11,
            color: value.isEmpty ? AppTheme.muted : (ok ? AppTheme.green : Colors.redAccent),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              children: [
                StepHeader(step: 5, title: 'CİHAZ BİLGİLERİ'),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Cihaz Adı')),
                const SizedBox(height: 14),
                TextField(
                  controller: serial,
                  decoration: const InputDecoration(
                    labelText: 'Seri Numarası',
                    helperText: 'Eklentideki kayıtla büyük/küçük harf dahil aynı olmalı',
                    helperStyle: TextStyle(fontSize: 10, color: AppTheme.muted),
                  ),
                ),
                const SizedBox(height: 14),

                if (_alreadyConfigured) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(.5)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu cihaz daha önce kurulmuş. Herhangi bir ayarı (WiFi dahil) değiştirebilmek '
                          'için cihazda kayıtlı mevcut firma anahtarıyla yetkilendirme gerekir.',
                          style: TextStyle(color: Colors.amber, fontSize: 11.5),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  _keyField(
                    controller: currentKey,
                    label: 'Mevcut Firma Anahtarı',
                    show: showCurrentKey,
                    toggle: () => setState(() => showCurrentKey = !showCurrentKey),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bu değer güvenlik nedeniyle cihazdan okunamaz. Yanlış girilirse cihaz tüm güncellemeyi reddeder.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: changeCompanyKey,
                    title: const Text('Firma anahtarını değiştir'),
                    subtitle: const Text(
                      'Kapalıysa mevcut firma anahtarı korunur.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                    onChanged: (v) => setState(() => changeCompanyKey = v),
                  ),
                  if (changeCompanyKey) ...[
                    const SizedBox(height: 8),
                    _keyField(
                      controller: key,
                      label: 'Yeni Firma Anahtarı',
                      show: showKey,
                      toggle: () => setState(() => showKey = !showKey),
                    ),
                  ],
                ] else ...[
                  _keyField(
                    controller: key,
                    label: 'Firma Anahtarı (Device Key)',
                    show: showKey,
                    toggle: () => setState(() => showKey = !showKey),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Firma anahtarı sunucunuz tarafından sağlanan cihaz anahtarı olmalıdır.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
                PrimaryButton(
                  text: 'İLERİ',
                  onPressed: () {
                    widget.config.deviceName = name.text.trim();
                    widget.config.serial = serial.text.trim();
                    if (_alreadyConfigured) {
                      widget.config.currentCompanyKey = currentKey.text.trim();
                      widget.config.changeCompanyKey = changeCompanyKey;
                      widget.config.companyKey = changeCompanyKey
                          ? key.text.trim()
                          : widget.config.currentCompanyKey;
                    } else {
                      widget.config.currentCompanyKey = '';
                      widget.config.changeCompanyKey = false;
                      widget.config.companyKey = key.text.trim();
                    }
                    Navigator.push(
                      c,
                      MaterialPageRoute(builder: (_) => ServerScreen(config: widget.config, ble: widget.ble)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
