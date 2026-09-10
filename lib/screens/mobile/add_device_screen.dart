import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';

class AddDeviceScreen extends StatefulWidget {
  final AppSession session;

  const AddDeviceScreen({super.key, required this.session});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  int? _locationId;
  final Set<String> _metrics = {'temperature', 'humidity', 'dew_point'};

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  List<String> _availableMetrics() {
    final catalog = widget.session.metricCatalog;
    final result = catalog.entries
        .where((entry) {
          final value = entry.value;
          if (value is! Map) return false;
          return Map<String, dynamic>.from(value)['selectable'] != false;
        })
        .map((entry) => entry.key)
        .toList();
    result.sort(
      (a, b) => metricLabel(a, catalog).compareTo(metricLabel(b, catalog)),
    );
    return result;
  }

  Future<void> _save() async {
    final available = _availableMetrics().toSet();
    final selected = _metrics.where(available.contains).toList();
    if (_name.text.trim().isEmpty ||
        _code.text.trim().isEmpty ||
        _locationId == null ||
        selected.isEmpty) {
      showSessionMessage(
        context,
        'Cihaz adı, seri numarası, konum ve en az bir sensör seçin.',
      );
      return;
    }
    if (selected.length > 16) {
      showSessionMessage(context, 'Tek işlemde en fazla 16 sensör seçilebilir.');
      return;
    }

    final ok = await widget.session.addDevice(
      name: _name.text.trim(),
      code: _code.text.trim(),
      locationId: _locationId!,
      metrics: selected,
    );
    if (!mounted) return;
    if (ok) {
      showSessionMessage(context, 'Cihaz ve ilk sensörler web hesabına eklendi.');
      Navigator.pop(context);
    } else {
      showSessionMessage(context, widget.session.error ?? 'Cihaz eklenemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.session.locations
        .where((item) => item['type'] == 'room' || item['type'] == 'cabinet')
        .toList();
    final catalog = widget.session.metricCatalog;
    final available = _availableMetrics();

    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
          children: [
            MobileTopBar(
              title: 'Cihaz Ekle',
              subtitle: 'Ortam İzleme 2.5.50 mobil yönetim',
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Cihaz adı',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Seri numarası / cihaz kodu',
                      hintText: 'ESP-001',
                      prefixIcon: Icon(Icons.qr_code_2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _locationId,
                    decoration: const InputDecoration(
                      labelText: 'Oda / dolap',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                    items: targets
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: int.tryParse('${item['id']}'),
                            child: Text(
                              locationPath(widget.session.locations, item['id']),
                            ),
                          ),
                        )
                        .where((item) => item.value != null)
                        .toList(),
                    onChanged: (value) => setState(() => _locationId = value),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'İlk sensörler',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Sonradan cihaz detayından yeni sensör ekleyebilir, düzenleyebilir veya silebilirsiniz.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  ...available.map(
                    (metric) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _metrics.contains(metric),
                      secondary: Icon(
                        metricIcon(metric),
                        color: metricColor(metric),
                      ),
                      title: Text(metricLabel(metric, catalog)),
                      subtitle: metricUnit(metric, catalog).isEmpty
                          ? null
                          : Text(
                              metricUnit(metric, catalog),
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 10,
                              ),
                            ),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            if (_metrics.length < 16) {
                              _metrics.add(metric);
                            }
                          } else {
                            _metrics.remove(metric);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: widget.session.busy ? 'KAYDEDİLİYOR...' : 'CİHAZI EKLE',
                    icon: Icons.cloud_upload_outlined,
                    onPressed: widget.session.busy || !widget.session.canManage
                        ? null
                        : _save,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Fiziksel ESP Wi-Fi/BLE ayarları ayrı tutulur. Bunun için login sonrasında Yapılandır sekmesini kullanın.',
              style: TextStyle(color: AppTheme.muted, fontSize: 10, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
