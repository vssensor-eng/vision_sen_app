import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'history_screen.dart';
import 'mobile_widgets.dart';

class DeviceDetailScreen extends StatelessWidget {
  final AppSession session;
  final Map<String, dynamic> device;
  const DeviceDetailScreen({super.key, required this.session, required this.device});

  @override
  Widget build(BuildContext context) {
    final sensorList = session.sensors.where((s) => '${s['device_id']}' == '${device['id']}').toList();
    final offlineMinutes = int.tryParse('${session.company['offline_minutes'] ?? 3}') ?? 3;
    final online = isOnline(device, offlineMinutes: offlineMinutes);
    Map<String, dynamic>? location;
    for (final item in session.locations) {
      if ('${item['id']}' == '${device['location_id']}') { location = item; break; }
    }
    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            MobileTopBar(
              title: device['name']?.toString() ?? device['code']?.toString() ?? 'Cihaz',
              subtitle: location?['name']?.toString() ?? 'Konum atanmamış',
              actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Panel(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(color: AppTheme.panel2, borderRadius: BorderRadius.circular(15)),
                              child: const Icon(Icons.memory, color: AppTheme.cyan, size: 30),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(device['code']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      StatusDot(color: online ? AppTheme.green : const Color(0xFFFF6B6B)),
                                      const SizedBox(width: 6),
                                      Text(online ? 'Çevrimiçi' : 'Çevrimdışı', style: TextStyle(color: online ? AppTheme.green : const Color(0xFFFF6B6B), fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(ago(device['last_seen']), style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _SmallStatus(icon: Icons.battery_5_bar, label: 'Batarya', value: formatValue(device['battery_percent'], '%'), color: AppTheme.green)),
                            const SizedBox(width: 9),
                            Expanded(child: _SmallStatus(icon: Icons.network_wifi, label: 'Sinyal', value: formatValue(device['signal_dbm'], 'dBm'), color: AppTheme.cyan)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerLeft, child: Text('Canlı Sensörler (${sensorList.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                  const SizedBox(height: 10),
                  if (sensorList.isEmpty)
                    const Panel(child: Text('Bu cihaz için sensör kaydı bulunmuyor.', style: TextStyle(color: AppTheme.muted)))
                  else
                    ...sensorList.map((sensor) {
                      final metric = sensor['metric']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Panel(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
                            leading: const CircleAvatar(backgroundColor: AppTheme.panel2, child: Icon(Icons.show_chart, color: AppTheme.cyan)),
                            title: Text(metricLabel(metric), style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('${sensor['channel'] ?? ''} • ${ago(sensor['latest_at'])}', style: const TextStyle(color: AppTheme.muted, fontSize: 10)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(formatValue(sensor['latest_value'], metricUnit(metric)), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                const SizedBox(width: 3),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(session: session, sensor: sensor))),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cihaz Bilgileri', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        _InfoRow('Firmware', device['firmware_version']?.toString() ?? '—'),
                        _InfoRow('Yerel IP', device['local_ip']?.toString() ?? '—'),
                        _InfoRow('Son görülen IP', device['last_ip']?.toString() ?? '—'),
                        _InfoRow('Güç kaynağı', device['power_source']?.toString() ?? '—'),
                      ],
                    ),
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

class _SmallStatus extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SmallStatus({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: AppTheme.panel2, borderRadius: BorderRadius.circular(13)),
        child: Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 10)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]))]),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: AppTheme.muted))), Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)))]),
      );
}
