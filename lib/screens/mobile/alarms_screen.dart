import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';

class AlarmsScreen extends StatefulWidget {
  final AppSession session;
  const AlarmsScreen({super.key, required this.session});
  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  bool closed = false;
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> items = const [];

  @override
  void initState() {
    super.initState();
    items = widget.session.alarms;
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.session.api.alarms(state: closed ? 'closed' : 'open');
      final raw = data['items'];
      items = raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
            children: [
              MobileTopBar(title: 'Alarmlar', subtitle: closed ? 'Geçmiş alarmlar' : 'Aktif alarmlar', actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
              Row(
                children: [
                  Expanded(child: ChoiceChip(label: const Text('Aktif'), selected: !closed, onSelected: (_) { setState(() => closed = false); _load(); })),
                  const SizedBox(width: 8),
                  Expanded(child: ChoiceChip(label: const Text('Geçmiş'), selected: closed, onSelected: (_) { setState(() => closed = true); _load(); })),
                ],
              ),
              const SizedBox(height: 14),
              if (loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
              if (error != null) Panel(child: Text(error!, style: const TextStyle(color: Color(0xFFFF7A7A)))),
              if (!loading && error == null && items.isEmpty) const Panel(child: Text('Bu durumda alarm bulunmuyor.', style: TextStyle(color: AppTheme.muted))),
              ...items.map((alarm) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Panel(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: const Color(0xFFFF5C5C).withOpacity(.14), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(alarm['sensor_name']?.toString() ?? alarm['kind']?.toString() ?? 'Alarm', style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text('${alarm['device_name'] ?? ''} • ${alarm['location_name'] ?? ''}', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                                const SizedBox(height: 5),
                                Text('Değer: ${formatValue(alarm['last_value'])}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(ago(alarm['opened_at']), style: const TextStyle(color: AppTheme.muted, fontSize: 10)),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      );
}
