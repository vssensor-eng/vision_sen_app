import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'alarms_screen.dart';
import 'mobile_widgets.dart';

class DashboardScreen extends StatelessWidget {
  final AppSession session;
  const DashboardScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) => AppBackground(
        child: AnimatedBuilder(
          animation: session,
          builder: (context, _) {
            final locations = session.locations;
            final devices = session.devices;
            final sensors = session.sensors;
            final company = session.company;
            final offlineMinutes = int.tryParse('${company['offline_minutes'] ?? 3}') ?? 3;
            final buildings = locations.where((e) => e['type'] == 'building').length;
            final rooms = locations.where((e) => e['type'] == 'room').length;
            final online = devices.where((d) => isOnline(d, offlineMinutes: offlineMinutes)).length;
            final activeAlarms = session.alarms.length;
            final name = session.user['name']?.toString().trim();
            final latestSensors = sensors.where((s) => s['enabled'].toString() == '1' || s['enabled'] == true).take(4).toList();

            return RefreshIndicator(
              onRefresh: session.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  MobileTopBar(
                    title: name == null || name.isEmpty ? 'Genel Bakış' : 'Merhaba, $name',
                    subtitle: company['name']?.toString() ?? 'VisionSen',
                    actions: [
                      IconButton(onPressed: session.busy ? null : session.refresh, icon: const Icon(Icons.refresh, color: AppTheme.cyan)),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmsScreen(session: session))),
                            icon: const Icon(Icons.notifications_none),
                          ),
                          if (activeAlarms > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Color(0xFFFF5C5C), shape: BoxShape.circle),
                                child: Text('$activeAlarms', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (session.error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0x33FF5C5C), borderRadius: BorderRadius.circular(12)),
                            child: Text(session.error!, style: const TextStyle(color: Color(0xFFFF8A8A))),
                          ),
                          const SizedBox(height: 12),
                        ],
                        GridView.count(
                          crossAxisCount: 2,
                          childAspectRatio: 1.65,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            MetricTile(icon: Icons.apartment, label: 'Binalar', value: '$buildings'),
                            MetricTile(icon: Icons.meeting_room_outlined, label: 'Odalar', value: '$rooms', color: AppTheme.green),
                            MetricTile(icon: Icons.sensors, label: 'Çevrimiçi Cihaz', value: '$online / ${devices.length}'),
                            MetricTile(icon: Icons.warning_amber_rounded, label: 'Aktif Alarm', value: '$activeAlarms', color: activeAlarms > 0 ? const Color(0xFFFF6B6B) : AppTheme.green),
                          ],
                        ),
                        const SizedBox(height: 22),
                        const Text('Canlı Sensörler', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (latestSensors.isEmpty)
                          const Panel(child: Text('Henüz izlenen sensör bulunmuyor.', style: TextStyle(color: AppTheme.muted)))
                        else
                          ...latestSensors.map((sensor) {
                            final metric = sensor['metric']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Panel(
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                                child: Row(
                                  children: [
                                    const Icon(Icons.show_chart, color: AppTheme.cyan),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(metricLabel(metric), style: const TextStyle(fontWeight: FontWeight.w800)),
                                          Text(sensor['channel']?.toString() ?? '', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Text(formatValue(sensor['latest_value'], metricUnit(metric)), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 12),
                        Panel(
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(color: AppTheme.green.withOpacity(.12), borderRadius: BorderRadius.circular(13)),
                                child: const Icon(Icons.bluetooth_searching, color: AppTheme.green),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Cihaz Yapılandırma', style: TextStyle(fontWeight: FontWeight.w900)),
                                    SizedBox(height: 2),
                                    Text('BLE kurulumu yalnız giriş yaptıktan sonra Yapılandır sekmesinden başlatılır.', style: TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.35)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}
