import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'add_device_screen.dart';
import 'device_detail_screen.dart';
import 'mobile_widgets.dart';

class DevicesScreen extends StatelessWidget {
  final AppSession session;
  const DevicesScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) => AppBackground(
        child: AnimatedBuilder(
          animation: session,
          builder: (context, _) {
            final devices = session.devices;
            final locationMap = {for (final l in session.locations) '${l['id']}': l};
            final offlineMinutes = int.tryParse('${session.company['offline_minutes'] ?? 3}') ?? 3;
            return RefreshIndicator(
              onRefresh: session.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  MobileTopBar(
                    title: 'Cihazlarım',
                    subtitle: '${devices.length} kayıtlı cihaz',
                    actions: [
                      if (session.canManage)
                        IconButton(
                          tooltip: 'Web\'e cihaz ekle',
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddDeviceScreen(session: session))),
                          icon: const Icon(Icons.add_circle_outline, color: AppTheme.cyan),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: devices.isEmpty
                        ? Panel(
                            child: Column(
                              children: [
                                const Icon(Icons.sensors_off_outlined, size: 46, color: AppTheme.muted),
                                const SizedBox(height: 12),
                                Text(
                                  session.canManage ? 'Web hesabınızda cihaz bulunmuyor.' : 'Web hesabınızda görüntülenecek cihaz bulunmuyor.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppTheme.muted),
                                ),
                                if (session.canManage) ...[
                                  const SizedBox(height: 16),
                                  PrimaryButton(
                                    text: 'CİHAZ EKLE',
                                    icon: Icons.add,
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddDeviceScreen(session: session))),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : Column(
                            children: devices.map((device) {
                              final online = isOnline(device, offlineMinutes: offlineMinutes);
                              final loc = locationMap['${device['location_id']}'];
                              final sensorCount = session.sensors.where((s) => '${s['device_id']}' == '${device['id']}').length;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Panel(
                                  padding: EdgeInsets.zero,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(color: AppTheme.panel2, borderRadius: BorderRadius.circular(14)),
                                      child: const Icon(Icons.memory, color: AppTheme.cyan),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(device['name']?.toString() ?? device['code']?.toString() ?? 'Cihaz', style: const TextStyle(fontWeight: FontWeight.w900))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: (online ? AppTheme.green : const Color(0xFFFF6B6B)).withOpacity(.13), borderRadius: BorderRadius.circular(20)),
                                          child: Text(online ? 'Çevrimiçi' : 'Çevrimdışı', style: TextStyle(color: online ? AppTheme.green : const Color(0xFFFF6B6B), fontSize: 10, fontWeight: FontWeight.w800)),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text('${loc?['name'] ?? 'Konum yok'} • $sensorCount sensör • ${ago(device['last_seen'])}', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceDetailScreen(session: session, device: device))),
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
