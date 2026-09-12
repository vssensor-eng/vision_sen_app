import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../services/app_session.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';

class DeviceEditorScreen extends StatefulWidget {
  final AppSession session;
  final Map<String, dynamic> device;

  const DeviceEditorScreen({
    super.key,
    required this.session,
    required this.device,
  });

  @override
  State<DeviceEditorScreen> createState() => _DeviceEditorScreenState();
}

class _DeviceEditorScreenState extends State<DeviceEditorScreen> {
  static const _defaultTimezones = [
    'Europe/Istanbul',
    'UTC',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Paris',
    'Asia/Dubai',
    'Asia/Baku',
    'Asia/Riyadh',
    'America/New_York',
  ];

  late final TextEditingController _name;
  late final TextEditingController _code;
  int? _locationId;
  late String _timezone;
  late int _sendInterval;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.device['name']?.toString() ?? '');
    _code = TextEditingController(text: widget.device['code']?.toString() ?? '');
    _locationId = int.tryParse('${widget.device['location_id']}');
    final zone = widget.device['timezone']?.toString().trim() ?? '';
    final companyZone = widget.session.company['timezone']?.toString().trim() ?? '';
    _timezone = zone.isNotEmpty
        ? zone
        : (companyZone.isNotEmpty ? companyZone : 'Europe/Istanbul');
    final rawInterval = int.tryParse('${widget.device['send_interval_minutes']}') ?? 1;
    _sendInterval = DeviceConfig.isSupportedSendInterval(rawInterval) ? rawInterval : 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  List<String> _timezones() => <String>{_timezone, ..._defaultTimezones}.toList();

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showSessionMessage(context, 'Cihaz adını girin.');
      return;
    }
    final ok = await widget.session.updateDevice(
      int.parse('${widget.device['id']}'),
      name: _name.text.trim(),
      code: _code.text.trim(),
      locationId: _locationId,
      timezone: _timezone,
      sendIntervalMinutes: _sendInterval,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      showSessionMessage(context, widget.session.error ?? 'Cihaz güncellenemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.session.locations
        .where((item) => item['type'] == 'room' || item['type'] == 'cabinet')
        .toList();

    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
          children: [
            MobileTopBar(
              title: 'Cihazı Düzenle',
              subtitle: widget.device['code']?.toString(),
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Panel(
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Cihaz adı',
                      prefixIcon: Icon(Icons.memory),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Seri numarası / cihaz kodu',
                      prefixIcon: Icon(Icons.qr_code_2),
                      helperText: 'Mevcut cihaz kodu bu ekranda değiştirilmez.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _locationId,
                    decoration: const InputDecoration(
                      labelText: 'Oda / dolap',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Atanmamış'),
                      ),
                      ...targets
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: int.tryParse('${item['id']}'),
                              child: Text(locationPath(widget.session.locations, item['id'])),
                            ),
                          )
                          .where((item) => item.value != null),
                    ],
                    onChanged: (value) => setState(() => _locationId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _timezone,
                    decoration: const InputDecoration(
                      labelText: 'Saat dilimi',
                      prefixIcon: Icon(Icons.public),
                    ),
                    items: _timezones()
                        .map(
                          (zone) => DropdownMenuItem<String>(value: zone, child: Text(zone)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _timezone = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _sendInterval,
                    decoration: const InputDecoration(
                      labelText: 'Gönderim aralığı',
                      prefixIcon: Icon(Icons.schedule_send_outlined),
                    ),
                    items: DeviceConfig.supportedSendIntervals
                        .map(
                          (minutes) => DropdownMenuItem<int>(
                            value: minutes,
                            child: Text('$minutes dakika'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _sendInterval = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    text: widget.session.busy
                        ? 'KAYDEDİLİYOR...'
                        : 'DEĞİŞİKLİKLERİ KAYDET',
                    icon: Icons.save_outlined,
                    onPressed: widget.session.busy ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
