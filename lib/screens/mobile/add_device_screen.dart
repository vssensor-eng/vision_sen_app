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

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty || _locationId == null || _metrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cihaz adı, seri numarası, konum ve en az bir sensör seçin.')));
      return;
    }
    final ok = await widget.session.addDevice(
      name: _name.text.trim(),
      code: _code.text.trim(),
      locationId: _locationId!,
      metrics: _metrics.toList(),
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
    const available = ['temperature', 'humidity', 'dew_point', 'pressure', 'co2'];
    return Scaffold(
      body: AppBackground(
        child: AnimatedBuilder(
          animation: widget.session,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
            children: [
              MobileTopBar(title: 'Web’e Cihaz Ekle', subtitle: 'Web panelinde henüz kayıtlı olmayan cihaz', actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
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
                    const Text('İlk kayıt sırasında oluşturulacak sensör kanallarını seçin.', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
                    const SizedBox(height: 8),
                    ...available.map((metric) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _metrics.contains(metric),
                          title: Text(metricLabel(metric)),
                          onChanged: (v) => setState(() => v == true ? _metrics.add(metric) : _metrics.remove(metric)),
                        )),
                    const SizedBox(height: 16),
                    PrimaryButton(text: widget.session.busy ? 'KAYDEDİLİYOR...' : 'WEB’E CİHAZ EKLE', icon: Icons.cloud_upload_outlined, onPressed: widget.session.busy ? null : _save),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Bu ekran web hesabına cihaz kaydı oluşturur. Fiziksel ESP’nin Wi-Fi/BLE ayarları için ana menüdeki “Yapılandır” sekmesini kullanın.', style: TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
