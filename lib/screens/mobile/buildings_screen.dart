import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';
import 'room_detail_screen.dart';

class BuildingsScreen extends StatelessWidget {
  final AppSession session;
  const BuildingsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) => AppBackground(
        child: AnimatedBuilder(
          animation: session,
          builder: (context, _) {
            final buildings = session.locations.where((l) => l['type'] == 'building').toList();
            return RefreshIndicator(
              onRefresh: session.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const MobileTopBar(title: 'Binalar ve Odalar', subtitle: 'Web panelinde oluşturduğunuz konumlar'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: buildings.isEmpty
                        ? const Panel(child: Text('Web panelinde henüz bina oluşturulmamış.', style: TextStyle(color: AppTheme.muted)))
                        : Column(
                            children: buildings.map((building) {
                              final id = int.tryParse('${building['id']}') ?? 0;
                              final rooms = session.locations.where((l) => l['type'] == 'room' && int.tryParse('${l['parent_id']}') == id).toList();
                              final roomIds = rooms.map((e) => int.tryParse('${e['id']}') ?? -1).toSet();
                              final deviceCount = session.devices.where((d) => roomIds.contains(int.tryParse('${d['location_id']}'))).length;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Panel(
                                  padding: const EdgeInsets.all(0),
                                  child: ExpansionTile(
                                    shape: const Border(),
                                    collapsedShape: const Border(),
                                    leading: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(color: AppTheme.cyan.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.apartment, color: AppTheme.cyan),
                                    ),
                                    title: Text(building['name']?.toString() ?? 'Bina', style: const TextStyle(fontWeight: FontWeight.w900)),
                                    subtitle: Text('${rooms.length} oda • $deviceCount cihaz', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                                    children: rooms.isEmpty
                                        ? const [Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 18), child: Align(alignment: Alignment.centerLeft, child: Text('Bu binada oda yok.', style: TextStyle(color: AppTheme.muted))))]
                                        : rooms.map((room) => ListTile(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                                              leading: const Icon(Icons.meeting_room_outlined, color: AppTheme.green),
                                              title: Text(room['name']?.toString() ?? 'Oda'),
                                              trailing: const Icon(Icons.chevron_right),
                                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(session: session, room: room, building: building))),
                                            )).toList(),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}
