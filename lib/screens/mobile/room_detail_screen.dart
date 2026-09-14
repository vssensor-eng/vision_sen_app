import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'device_detail_screen.dart';
import 'mobile_widgets.dart';

class RoomDetailScreen extends StatelessWidget {
  final AppSession session;
  final Map<String, dynamic> room;
  final Map<String, dynamic> building;
  const RoomDetailScreen({super.key, required this.session, required this.room, required this.building});

  @override
  Widget build(BuildContext context) {
    final roomId = int.tryParse('${room['id']}') ?? 0;
    final cabinets = session.locations.where((l) => l['type'] == 'cabinet' && int.tryParse('${l['parent_id']}') == roomId).toList();
    final locationIds = {roomId, ...cabinets.map((e) => int.tryParse('${e['id']}') ?? -1)};
    final devices = session.devices.where((d) => locationIds.contains(int.tryParse('${d['location_id']}'))).toList();
    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            MobileTopBar(
              title: room['name']?.toString() ?? 'Oda',
              subtitle: building['name']?.toString(),
              actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Panel(
                    child: Row(
                      children: [
                        const SectionIcon(icon: Icons.meeting_room_outlined, color: AppTheme.green),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${devices.length} cihaz', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              Text('${cabinets.length} dolap / alt konum', style: const TextStyle(color: AppTheme.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (devices.isEmpty)
                    const Panel(child: Text('Bu odada kayıtlı cihaz bulunmuyor.', style: TextStyle(color: AppTheme.muted)))
                  else
                    ...devices.map((device) {
                      final sensors = session.sensors.where((s) => int.tryParse('${s['device_id']}') == int.tryParse('${device['id']}')).toList();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Panel(
                          padding: const EdgeInsets.all(0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                            leading: const CircleAvatar(backgroundColor: AppTheme.panel2, child: Icon(Icons.sensors, color: AppTheme.cyan)),
                            title: Text(device['name']?.toString() ?? device['code']?.toString() ?? 'Cihaz', style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('${device['code'] ?? ''} • ${sensors.length} sensör', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceDetailScreen(session: session, device: device))),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
