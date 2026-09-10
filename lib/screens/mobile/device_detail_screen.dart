import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'device_editor_screen.dart';
import 'history_screen.dart';
import 'mobile_widgets.dart';
import 'sensor_editor_screen.dart';

class DeviceDetailScreen extends StatelessWidget {
  final AppSession session;
  final Map<String, dynamic> device;

  const DeviceDetailScreen({
    super.key,
    required this.session,
    required this.device,
  });

  Map<String, dynamic> _currentDevice() {
    for (final item in session.devices) {
      if ('${item['id']}' == '${device['id']}') {
        return item;
      }
    }
    return device;
  }

  Future<void> _handleDeviceAction(
    BuildContext context,
    String action,
    Map<String, dynamic> currentDevice,
  ) async {
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeviceEditorScreen(
            session: session,
            device: currentDevice,
          ),
        ),
      );
      return;
    }

    if (action == 'add') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SensorEditorScreen(
            session: session,
            device: currentDevice,
          ),
        ),
      );
      return;
    }

    if (action == 'delete') {
      final confirmed = await confirmDelete(
        context,
        'Cihaz silinsin mi?',
        'Cihaza bağlı sensör varsa önce sensörleri silin. Bu işlem kalıcıdır.',
      );
      if (!confirmed) return;

      final ok = await session.deleteDevice(
        int.parse('${currentDevice['id']}'),
      );
      if (!context.mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        showSessionMessage(
          context,
          session.error ?? 'Cihaz silinemedi.',
        );
      }
    }
  }

  Future<void> _handleSensorAction(
    BuildContext context,
    String action,
    Map<String, dynamic> currentDevice,
    Map<String, dynamic> sensor,
  ) async {
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SensorEditorScreen(
            session: session,
            device: currentDevice,
            sensor: sensor,
          ),
        ),
      );
      return;
    }

    if (action == 'delete') {
      final confirmed = await confirmDelete(
        context,
        'Sensör silinsin mi?',
        'Sensör ve ona ait ölçüm/alarm geçmişi kalıcı olarak silinir.',
      );
      if (!confirmed) return;

      final ok = await session.deleteSensor(int.parse('${sensor['id']}'));
      if (!context.mounted) return;
      showSessionMessage(
        context,
        ok ? 'Sensör silindi.' : session.error ?? 'Sensör silinemedi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: AnimatedBuilder(
          animation: session,
          builder: (context, _) {
            final currentDevice = _currentDevice();
            final sensors = session.sensors
                .where(
                  (sensor) =>
                      '${sensor['device_id']}' == '${currentDevice['id']}',
                )
                .toList();
            final catalog = session.metricCatalog;
            final offlineMinutes =
                int.tryParse('${session.company['offline_minutes'] ?? 3}') ?? 3;
            final online = isOnline(
              currentDevice,
              offlineMinutes: offlineMinutes,
            );
            final path = locationPath(
              session.locations,
              currentDevice['location_id'],
            );

            return ListView(
              padding: const EdgeInsets.only(bottom: 30),
              children: [
                MobileTopBar(
                  title: currentDevice['name']?.toString() ??
                      currentDevice['code']?.toString() ??
                      'Cihaz',
                  subtitle: path.isEmpty ? 'Konum atanmamış' : path,
                  actions: [
                    if (session.canManage)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          _handleDeviceAction(
                            context,
                            value,
                            currentDevice,
                          );
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'add',
                            child: ListTile(
                              leading: Icon(Icons.add_chart),
                              title: Text('Sensör ekle'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Cihazı düzenle'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Cihazı sil'),
                            ),
                          ),
                        ],
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
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
                                  decoration: BoxDecoration(
                                    color: AppTheme.panel2,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(
                                    Icons.memory,
                                    color: online
                                        ? AppTheme.green
                                        : AppTheme.cyan,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentDevice['code']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        online ? 'Çevrimiçi' : 'Çevrimdışı',
                                        style: TextStyle(
                                          color: online
                                              ? AppTheme.green
                                              : const Color(0xFFFF6B6B),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  ago(currentDevice['last_seen']),
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: MetricTile(
                                    icon: Icons.battery_5_bar,
                                    label: 'Batarya',
                                    value: formatValue(
                                      currentDevice['battery_percent'],
                                      '%',
                                    ),
                                    color: AppTheme.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: MetricTile(
                                    icon: Icons.network_wifi,
                                    label: 'Sinyal',
                                    value: formatValue(
                                      currentDevice['signal_dbm'],
                                      'dBm',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Sensörler (${sensors.length})',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (session.canManage)
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SensorEditorScreen(
                                      session: session,
                                      device: currentDevice,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Sensör'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (sensors.isEmpty)
                        const Panel(
                          child: Text(
                            'Bu cihaz için sensör kaydı bulunmuyor.',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                        )
                      else
                        ...sensors.map((sensor) {
                          final metric = sensor['metric']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Panel(
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.fromLTRB(12, 7, 7, 7),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      metricColor(metric).withOpacity(.12),
                                  child: Icon(
                                    metricIcon(metric),
                                    color: metricColor(metric),
                                  ),
                                ),
                                title: Text(
                                  sensor['name']?.toString() ??
                                      metricLabel(metric, catalog),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  '${sensor['channel'] ?? ''} • ${ago(sensor['latest_at'])}',
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formatValue(
                                        sensor['latest_value'],
                                        metricUnit(metric, catalog),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (session.canManage)
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          _handleSensorAction(
                                            context,
                                            value,
                                            currentDevice,
                                            sensor,
                                          );
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Düzenle'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Sil'),
                                          ),
                                        ],
                                      )
                                    else
                                      const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HistoryScreen(
                                        session: session,
                                        sensor: sensor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cihaz Bilgileri',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              'Firmware',
                              currentDevice['firmware_version']?.toString() ??
                                  '—',
                            ),
                            _InfoRow(
                              'Yerel IP',
                              currentDevice['local_ip']?.toString() ?? '—',
                            ),
                            _InfoRow(
                              'Son görülen IP',
                              currentDevice['last_ip']?.toString() ?? '—',
                            ),
                            _InfoRow(
                              'Güç kaynağı',
                              currentDevice['power_source']?.toString() ?? '—',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
