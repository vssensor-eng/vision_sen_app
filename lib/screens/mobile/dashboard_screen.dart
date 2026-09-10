import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'alarms_screen.dart';
import 'mobile_widgets.dart';

class DashboardScreen extends StatelessWidget {
  final AppSession session;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onOpenDevices;

  const DashboardScreen({
    super.key,
    required this.session,
    this.onOpenDetail,
    this.onOpenDevices,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          final locations = session.locations;
          final devices = session.devices;
          final sensors = session.sensors;
          final alarms = session.alarms;
          final offlineMinutes =
              int.tryParse('${session.company['offline_minutes'] ?? 3}') ?? 3;

          final buildingCount =
              locations.where((item) => item['type'] == 'building').length;
          final roomCount =
              locations.where((item) => item['type'] == 'room').length;
          final activeSensorCount =
              sensors.where((sensor) => truthy(sensor['enabled'])).length;
          final onlineDevices = devices
              .where(
                (device) => isOnline(
                  device,
                  offlineMinutes: offlineMinutes,
                ),
              )
              .toList();
          final offlineDevices = devices
              .where(
                (device) => !isOnline(
                  device,
                  offlineMinutes: offlineMinutes,
                ),
              )
              .toList();
          final activeAlarmCount = alarms.length;
          final onlineRatio = devices.isEmpty
              ? 0.0
              : onlineDevices.length / devices.length;
          final sensorRatio = sensors.isEmpty
              ? 0.0
              : activeSensorCount / sensors.length;
          final userName = session.user['name']?.toString().trim();
          final latestSeen = _latestSeen(devices);
          final systemHealthy = activeAlarmCount == 0 && offlineDevices.isEmpty;

          return RefreshIndicator(
            onRefresh: session.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                MobileTopBar(
                  title: userName == null || userName.isEmpty
                      ? 'Sistem Özeti'
                      : 'Merhaba, $userName',
                  subtitle: session.company['name']?.toString() ?? 'VisionSen',
                  actions: [
                    IconButton(
                      onPressed: session.busy ? null : session.refresh,
                      icon: const Icon(Icons.refresh, color: AppTheme.cyan),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          onPressed: () => _openAlarms(context),
                          icon: const Icon(Icons.notifications_none),
                        ),
                        if (activeAlarmCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5C5C),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$activeAlarmCount',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
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
                          decoration: BoxDecoration(
                            color: const Color(0x33FF5C5C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            session.error!,
                            style: const TextStyle(color: Color(0xFFFF8A8A)),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _SystemHero(
                        healthy: systemHealthy,
                        alarmCount: activeAlarmCount,
                        offlineCount: offlineDevices.length,
                        latestSeen: latestSeen,
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 1.55,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          MetricTile(
                            icon: Icons.apartment,
                            label: 'Bina',
                            value: '$buildingCount',
                          ),
                          MetricTile(
                            icon: Icons.meeting_room_outlined,
                            label: 'Oda',
                            value: '$roomCount',
                            color: AppTheme.green,
                          ),
                          MetricTile(
                            icon: Icons.memory,
                            label: 'Cihaz',
                            value: '${devices.length}',
                          ),
                          MetricTile(
                            icon: Icons.wifi,
                            label: 'Çevrimiçi',
                            value: '${onlineDevices.length} / ${devices.length}',
                            color: AppTheme.green,
                          ),
                          MetricTile(
                            icon: Icons.sensors,
                            label: 'Aktif Sensör',
                            value: '$activeSensorCount',
                          ),
                          MetricTile(
                            icon: Icons.warning_amber_rounded,
                            label: 'Aktif Alarm',
                            value: '$activeAlarmCount',
                            color: activeAlarmCount > 0
                                ? const Color(0xFFFF6B6B)
                                : AppTheme.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Sistem Durumu',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Panel(
                        child: Column(
                          children: [
                            _HealthRow(
                              icon: Icons.router_outlined,
                              label: 'Cihaz erişilebilirliği',
                              value: devices.isEmpty
                                  ? 'Cihaz yok'
                                  : '%${(onlineRatio * 100).round()}',
                              progress: onlineRatio,
                              color: offlineDevices.isEmpty
                                  ? AppTheme.green
                                  : AppTheme.cyan,
                            ),
                            const SizedBox(height: 16),
                            _HealthRow(
                              icon: Icons.sensors_outlined,
                              label: 'Aktif sensör oranı',
                              value: sensors.isEmpty
                                  ? 'Sensör yok'
                                  : '%${(sensorRatio * 100).round()}',
                              progress: sensorRatio,
                              color: AppTheme.cyan,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 19,
                                  color: AppTheme.muted,
                                ),
                                const SizedBox(width: 9),
                                const Expanded(
                                  child: Text(
                                    'Son cihaz verisi',
                                    style: TextStyle(color: AppTheme.muted),
                                  ),
                                ),
                                Text(
                                  latestSeen == null ? 'Henüz veri yok' : ago(latestSeen),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Son Alarmlar',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _openAlarms(context),
                            child: const Text('Tümünü Gör'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (alarms.isEmpty)
                        const Panel(
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: AppTheme.green,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Aktif alarm bulunmuyor.',
                                  style: TextStyle(color: AppTheme.muted),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...alarms.take(3).map(
                              (alarm) => Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: _AlarmSummary(
                                  alarm: alarm,
                                  session: session,
                                  onTap: () => _openAlarms(context),
                                ),
                              ),
                            ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Çevrimdışı Cihazlar',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (offlineDevices.isNotEmpty)
                            Text(
                              '${offlineDevices.length}',
                              style: const TextStyle(
                                color: Color(0xFFFF8A8A),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (offlineDevices.isEmpty)
                        const Panel(
                          child: Row(
                            children: [
                              Icon(Icons.wifi, color: AppTheme.green),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tüm cihazlar erişilebilir durumda.',
                                  style: TextStyle(color: AppTheme.muted),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Panel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Column(
                            children: offlineDevices.take(3).map((device) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: const CircleAvatar(
                                  backgroundColor: AppTheme.panel2,
                                  child: Icon(
                                    Icons.portable_wifi_off,
                                    color: Color(0xFFFF7A7A),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  device['name']?.toString() ??
                                      device['code']?.toString() ??
                                      'Cihaz',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${device['code'] ?? ''} · ${ago(device['last_seen'])}',
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: onOpenDevices,
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'Hızlı Erişim',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.visibility_outlined,
                              label: 'Detay',
                              onTap: onOpenDetail,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.sensors_outlined,
                              label: 'Cihazlar',
                              onTap: onOpenDevices,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.notifications_active_outlined,
                              label: 'Alarmlar',
                              onTap: () => _openAlarms(context),
                            ),
                          ),
                        ],
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

  void _openAlarms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlarmsScreen(session: session)),
    );
  }

  static String? _latestSeen(List<Map<String, dynamic>> devices) {
    DateTime? latest;
    String? rawLatest;
    for (final device in devices) {
      final raw = device['last_seen']?.toString();
      if (raw == null || raw.isEmpty) continue;
      final normalized = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null && (latest == null || parsed.isAfter(latest))) {
        latest = parsed;
        rawLatest = raw;
      }
    }
    return rawLatest;
  }
}

class _SystemHero extends StatelessWidget {
  final bool healthy;
  final int alarmCount;
  final int offlineCount;
  final String? latestSeen;

  const _SystemHero({
    required this.healthy,
    required this.alarmCount,
    required this.offlineCount,
    required this.latestSeen,
  });

  @override
  Widget build(BuildContext context) {
    final color = healthy ? AppTheme.green : const Color(0xFFFF7A7A);
    final title = healthy ? 'Sistem Normal' : 'Dikkat Gerekiyor';
    final detail = healthy
        ? 'Aktif alarm yok ve tüm cihazlar erişilebilir.'
        : '$alarmCount aktif alarm · $offlineCount çevrimdışı cihaz';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(.16),
            AppTheme.panel.withOpacity(.96),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              healthy ? Icons.verified_outlined : Icons.warning_amber_rounded,
              color: color,
              size: 31,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  latestSeen == null
                      ? 'Henüz cihaz verisi alınmadı.'
                      : 'Son veri ${ago(latestSeen)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _HealthRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 7,
            backgroundColor: AppTheme.panel2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _AlarmSummary extends StatelessWidget {
  final Map<String, dynamic> alarm;
  final AppSession session;
  final VoidCallback onTap;

  const _AlarmSummary({
    required this.alarm,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sensorId = '${alarm['sensor_id'] ?? ''}';
    final deviceId = '${alarm['device_id'] ?? ''}';
    final locationId = '${alarm['location_id'] ?? ''}';
    final sensor = _find(session.sensors, sensorId);
    final device = _find(session.devices, deviceId);
    final location = _find(session.locations, locationId);
    final metric = alarm['sensor_metric']?.toString() ??
        sensor?['metric']?.toString() ??
        alarm['kind']?.toString() ??
        '';
    final title = alarm['sensor_name']?.toString() ??
        sensor?['name']?.toString() ??
        metricLabel(metric, session.metricCatalog);
    final where = alarm['location_name']?.toString() ??
        location?['name']?.toString() ??
        'Konum';
    final deviceName = alarm['device_name']?.toString() ??
        device?['name']?.toString() ??
        device?['code']?.toString() ??
        'Cihaz';

    return Panel(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0x33FF5C5C),
          child: Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFF7A7A),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '$where · $deviceName · ${ago(alarm['opened_at'])}',
          style: const TextStyle(color: AppTheme.muted, fontSize: 10),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  static Map<String, dynamic>? _find(
    List<Map<String, dynamic>> items,
    String id,
  ) {
    for (final item in items) {
      if ('${item['id']}' == id) return item;
    }
    return null;
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.cyan),
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
