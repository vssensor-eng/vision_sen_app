import 'package:flutter/material.dart';

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
  late final TextEditingController _name;
  late final TextEditingController _code;
  int? _locationId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.device['name']?.toString() ?? '');
    _code = TextEditingController(text: widget.device['code']?.toString() ?? '');
    _locationId = int.tryParse('${widget.device['location_id']}');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

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
                              child: Text(
                                locationPath(widget.session.locations, item['id']),
                              ),
                            ),
                          )
                          .where((item) => item.value != null),
                    ],
                    onChanged: (value) => setState(() => _locationId = value),
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
