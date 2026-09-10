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
    final items = catalog.entries.where((entry) {
      final raw = entry.value;
      if (raw is! Map) return false;
      final info = Map<String, dynamic>.from(raw);
      return info['selectable'] != false;
    }).map((entry) => entry.key).toList();
    items.sort((a, b) => metricLabel(a, catalog).compareTo(metricLabel(b, catalog)));
    return items;
  }

  Future<void> _save() async {
    final available = _availableMetrics().toSet();
    final selected = _metrics.where(available.contains).toList();
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty || _locationId == null || selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cihaz adı, seri numarası, konum ve en az bir sensör seçin.')));
      return;
    }
    if (selected.length > 16) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tek işlemde en fazla 16 sensör seçilebilir.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cihaz web hesabınıza eklendi.')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.session.error ?? 'Cihaz eklenemedi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.session.locations.where((l) => l['type'] == 'room' || l['type'] == 'cabinet').toList();
    final catalog = widget.session.metricCatalog;
    final available = _availableMetrics();
    return Scaffold(
      body: AppBackground(
        child: AnimatedBuilder(
          animation: widget.session,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
            children: [
              MobileTopBar(title: 'Web’e Cihaz Ekle', subtitle: 'Ortam İzleme 2.5.48 ile uyumlu kayıt', actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Cihaz adı', prefixIcon: Icon(Icons.label_outline))),
                    const SizedBox(height: 12),
                    TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Seri numarası / cihaz kodu', hintText: 'ESP-001', prefixIcon: Icon(Icons.qr_code_2))),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _locationId,
                      decoration: const InputDecoration(labelText: 'Oda / dolap', prefixIcon: Icon(Icons.meeting_room_outlined)),
                      items: targets.map((l) => DropdownMenuItem<int>(value: int.tryParse('${l['id']}'), child: Text(l['name']?.toString() ?? 'Konum'))).where((e) => e.value != null).toList(),
                      onChanged: (v) => setState(() => _locationId = v),
                    ),
                    const SizedBox(height: 20),
                    const Text('Cihaz sensörleri', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    const Text('Liste doğrudan web tarafındaki güncel sensör kataloğundan gelir.', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
                    const SizedBox(height: 8),
                    if (available.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Sensör kataloğu alınamadı. Önce verileri yenileyin.', style: TextStyle(color: AppTheme.muted)),
                      )
                    else
                      ...available.map((metric) => CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _metrics.contains(metric),
                            title: Text(metricLabel(metric, catalog)),
                            subtitle: metricUnit(metric, catalog).isEmpty ? null : Text(metricUnit(metric, catalog), style: const TextStyle(color: AppTheme.muted, fontSize: 10)),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                if (_metrics.length < 16) _metrics.add(metric);
                              } else {
                                _metrics.remove(metric);
                              }
                            }),
                          )),
                    const SizedBox(height: 16),
                    PrimaryButton(text: widget.session.busy ? 'KAYDEDİLİYOR...' : 'WEB’E CİHAZ EKLE', icon: Icons.cloud_upload_outlined, onPressed: widget.session.busy || !widget.session.canManage ? null : _save),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.session.canManage
                    ? 'Bu ekran cihaz ve seçtiğiniz sensörleri web hesabına kaydeder. Fiziksel ESP’nin Wi-Fi/BLE ayarları için “Yapılandır” sekmesini kullanın.'
                    : 'Cihaz ekleme yalnız firma yöneticisi hesabında kullanılabilir. İzleyici hesabı bina, oda, cihaz, sensör ve alarm verilerini görüntüleyebilir.',
                style: const TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
