import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'device_detail_screen.dart';
import 'history_screen.dart';
import 'mobile_widgets.dart';
import 'sensor_chart.dart';

class DetailScreen extends StatefulWidget {
  final AppSession session;

  const DetailScreen({super.key, required this.session});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  int? buildingId;
  int? roomId;
  int? cabinetId;
  int? trendSensorId;
  bool trendLoading = false;
  String? trendError;
  List<Map<String, dynamic>> trendPoints = const [];
  int _trendRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectInitialBuilding();
    });
  }

  List<Map<String, dynamic>> get _buildings => widget.session.locations
      .where((location) => location['type'] == 'building')
      .toList();

  List<Map<String, dynamic>> get _rooms => widget.session.locations
      .where(
        (location) =>
            location['type'] == 'room' &&
            int.tryParse('${location['parent_id']}') == buildingId,
      )
      .toList();

  List<Map<String, dynamic>> get _cabinets => widget.session.locations
      .where(
        (location) =>
            location['type'] == 'cabinet' &&
            int.tryParse('${location['parent_id']}') == roomId,
      )
      .toList();

  int? get _focusId => cabinetId ?? roomId ?? buildingId;

  void _selectInitialBuilding() {
    if (!mounted) return;
    final buildings = _buildings;
    if (buildings.isEmpty) return;

    final currentIsValid = buildingId != null &&
        buildings.any(
          (building) => int.tryParse('${building['id']}') == buildingId,
        );
    if (currentIsValid) {
      _syncTrendSensor();
      return;
    }

    setState(() {
      buildingId = int.tryParse('${buildings.first['id']}');
      roomId = null;
      cabinetId = null;
    });
    _syncTrendSensor();
  }

  Set<int> _descendantIds(int rootId) {
    final result = <int>{rootId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final location in widget.session.locations) {
        final id = int.tryParse('${location['id']}');
        final parentId = int.tryParse('${location['parent_id']}');
        if (id != null &&
            parentId != null &&
            result.contains(parentId) &&
            !result.contains(id)) {
          result.add(id);
          changed = true;
        }
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _scopeDevices() {
    final focusId = _focusId;
    if (focusId == null) return const [];
    final locationIds = _descendantIds(focusId);
    return widget.session.devices
        .where(
          (device) =>
              locationIds.contains(int.tryParse('${device['location_id']}')),
        )
        .toList();
  }

  List<Map<String, dynamic>> _scopeSensors() {
    final deviceIds = _scopeDevices()
        .map((device) => int.tryParse('${device['id']}'))
        .whereType<int>()
        .toSet();
    return widget.session.sensors
        .where(
          (sensor) =>
              deviceIds.contains(int.tryParse('${sensor['device_id']}')) &&
              truthy(sensor['enabled']),
        )
        .toList();
  }

  List<Map<String, dynamic>> _scopeAlarms() {
    final focusId = _focusId;
    if (focusId == null) return const [];
    final locationIds = _descendantIds(focusId);
    final deviceIds = _scopeDevices()
        .map((device) => int.tryParse('${device['id']}'))
        .whereType<int>()
        .toSet();

    return widget.session.alarms.where((alarm) {
      final alarmLocationId = int.tryParse('${alarm['location_id']}');
      final alarmDeviceId = int.tryParse('${alarm['device_id']}');
      return (alarmLocationId != null && locationIds.contains(alarmLocationId)) ||
          (alarmDeviceId != null && deviceIds.contains(alarmDeviceId));
    }).toList();
  }

  Map<String, dynamic>? _deviceFor(dynamic deviceId) {
    for (final device in widget.session.devices) {
      if ('${device['id']}' == '$deviceId') {
        return device;
      }
    }
    return null;
  }

  Map<String, dynamic>? _sensorFor(int? sensorId) {
    if (sensorId == null) return null;
    for (final sensor in _scopeSensors()) {
      if (int.tryParse('${sensor['id']}') == sensorId) {
        return sensor;
      }
    }
    return null;
  }

  void _syncTrendSensor() {
    final sensors = _scopeSensors();
    final nextId = sensors.isEmpty ? null : int.tryParse('${sensors.first['id']}');
    setState(() {
      trendSensorId = nextId;
      trendPoints = const [];
      trendError = null;
    });
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    final sensorId = trendSensorId;
    final requestId = ++_trendRequestId;
    if (sensorId == null) {
      if (mounted) {
        setState(() {
          trendLoading = false;
          trendPoints = const [];
          trendError = null;
        });
      }
      return;
    }

    setState(() {
      trendLoading = true;
      trendError = null;
    });

    try {
      final data = await widget.session.api.history(sensorId, hours: 24);
      if (!mounted || requestId != _trendRequestId) return;
      final raw = data['points'];
      setState(() {
        trendPoints = raw is List
            ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : const [];
        trendLoading = false;
      });
    } catch (exception) {
      if (!mounted || requestId != _trendRequestId) return;
      setState(() {
        trendError = exception.toString();
        trendLoading = false;
      });
    }
  }

  void _changeBuilding(int? value) {
    setState(() {
      buildingId = value;
      roomId = null;
      cabinetId = null;
    });
    _syncTrendSensor();
  }

  void _changeRoom(int? value) {
    setState(() {
      roomId = value == 0 ? null : value;
      cabinetId = null;
    });
    _syncTrendSensor();
  }

  void _changeCabinet(int? value) {
    setState(() {
      cabinetId = value == 0 ? null : value;
    });
    _syncTrendSensor();
  }

  Future<void> _refresh() async {
    await widget.session.refresh();
    if (!mounted) return;
    final buildings = _buildings;
    setState(() {
      buildingId = buildings.isEmpty
          ? null
          : int.tryParse('${buildings.first['id']}');
      roomId = null;
      cabinetId = null;
    });
    _syncTrendSensor();
  }

  Widget _buildSelectors() {
    return Panel(
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            value: buildingId,
            decoration: const InputDecoration(
              labelText: 'Bina',
              prefixIcon: Icon(Icons.apartment_outlined),
            ),
            hint: const Text('Bina seçin'),
            items: _buildings
                .map(
                  (building) => DropdownMenuItem<int>(
                    value: int.tryParse('${building['id']}'),
                    child: Text(building['name']?.toString() ?? 'Bina'),
                  ),
                )
                .where((item) => item.value != null)
                .toList(),
            onChanged: _changeBuilding,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: roomId ?? 0,
            decoration: const InputDecoration(
              labelText: 'Oda',
              prefixIcon: Icon(Icons.meeting_room_outlined),
            ),
            items: [
              const DropdownMenuItem<int>(
                value: 0,
                child: Text('Binanın tamamı'),
              ),
              ..._rooms
                  .map(
                    (room) => DropdownMenuItem<int>(
                      value: int.tryParse('${room['id']}'),
                      child: Text(room['name']?.toString() ?? 'Oda'),
                    ),
                  )
                  .where((item) => item.value != null),
            ],
            onChanged: buildingId == null ? null : _changeRoom,
          ),
          if (roomId != null) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: cabinetId ?? 0,
              decoration: const InputDecoration(
                labelText: 'Dolap',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: 0,
                  child: Text('Odanın tamamı'),
                ),
                ..._cabinets
                    .map(
                      (cabinet) => DropdownMenuItem<int>(
                        value: int.tryParse('${cabinet['id']}'),
                        child: Text(cabinet['name']?.toString() ?? 'Dolap'),
                      ),
                    )
                    .where((item) => item.value != null),
              ],
              onChanged: _changeCabinet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScopeSummary(
    List<Map<String, dynamic>> devices,
    List<Map<String, dynamic>> sensors,
    List<Map<String, dynamic>> alarms,
  ) {
    final offlineMinutes =
        int.tryParse('${widget.session.company['offline_minutes'] ?? 3}') ?? 3;
    final freshSensorCount = sensors.where((sensor) {
      final device = _deviceFor(sensor['device_id']);
      final latestAt = parseServerTime(sensor['latest_at']);
      return device != null &&
          isOnline(device, offlineMinutes: offlineMinutes) &&
          latestAt != null &&
          DateTime.now().difference(latestAt).inMinutes <= offlineMinutes;
    }).length;
    final quality = sensors.isEmpty
        ? null
        : (freshSensorCount * 100 / sensors.length).round();

    DateTime? latest;
    for (final sensor in sensors) {
      final sensorTime = parseServerTime(sensor['latest_at']);
      if (sensorTime != null && (latest == null || sensorTime.isAfter(latest))) {
        latest = sensorTime;
      }
    }

    final path = _focusId == null
        ? 'Konum seçilmedi'
        : locationPath(widget.session.locations, _focusId);

    return Column(
      children: [
        Panel(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withOpacity(.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.place_outlined, color: AppTheme.cyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'İzlenen Konum',
                      style: TextStyle(color: AppTheme.muted, fontSize: 10),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      path,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      latest == null
                          ? 'Henüz veri yok'
                          : 'Son veri ${ago(latest.toUtc().toIso8601String())}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.65,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            MetricTile(
              icon: Icons.health_and_safety_outlined,
              label: 'Veri Kalitesi',
              value: quality == null ? '—' : '%$quality',
              color: quality == 100
                  ? AppTheme.green
                  : const Color(0xFFFFB85C),
            ),
            MetricTile(
              icon: Icons.memory,
              label: 'Cihaz',
              value: '${devices.length}',
            ),
            MetricTile(
              icon: Icons.sensors,
              label: 'Sensör',
              value: '${sensors.length}',
              color: AppTheme.green,
            ),
            MetricTile(
              icon: Icons.warning_amber_rounded,
              label: 'Aktif Alarm',
              value: '${alarms.length}',
              color: alarms.isEmpty
                  ? AppTheme.green
                  : const Color(0xFFFF6B6B),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard(Map<String, dynamic> sensor) {
    final metric = sensor['metric']?.toString() ?? '';
    final catalog = widget.session.metricCatalog;
    final device = _deviceFor(sensor['device_id']);
    final sourcePath = locationPath(
      widget.session.locations,
      device == null ? null : device['location_id'],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryScreen(
                session: widget.session,
                sensor: sensor,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppTheme.panel.withOpacity(.95),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: metricColor(metric).withOpacity(.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  metricIcon(metric),
                  color: metricColor(metric),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sensor['name']?.toString() ??
                          metricLabel(metric, catalog),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device == null ? 'Cihaz' : device['name'] ?? 'Cihaz'} · ${sourcePath.isEmpty ? 'Konum yok' : sourcePath}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ago(sensor['latest_at']),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatValue(
                      sensor['latest_value'],
                      metricUnit(metric, catalog),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Icon(Icons.chevron_right, color: AppTheme.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrend(List<Map<String, dynamic>> sensors) {
    final catalog = widget.session.metricCatalog;
    final selectedSensor = _sensorFor(trendSensorId);
    final selectedMetric = selectedSensor == null
        ? ''
        : selectedSensor['metric']?.toString() ?? '';

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '24 Saat Trend',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (sensors.isNotEmpty)
            DropdownButtonFormField<int>(
              value: trendSensorId,
              decoration: const InputDecoration(
                labelText: 'Grafik sensörü',
                prefixIcon: Icon(Icons.show_chart),
              ),
              items: sensors
                  .map((sensor) {
                    final metric = sensor['metric']?.toString() ?? '';
                    final device = _deviceFor(sensor['device_id']);
                    return DropdownMenuItem<int>(
                      value: int.tryParse('${sensor['id']}'),
                      child: Text(
                        '${sensor['name'] ?? metricLabel(metric, catalog)} · ${device == null ? '' : device['name'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  })
                  .where((item) => item.value != null)
                  .toList(),
              onChanged: (value) {
                setState(() => trendSensorId = value);
                _loadTrend();
              },
            ),
          const SizedBox(height: 12),
          if (trendLoading)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (trendError != null)
            Text(
              trendError!,
              style: const TextStyle(color: Color(0xFFFF7A7A)),
            )
          else if (trendPoints.isEmpty)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'Bu aralıkta grafik verisi yok.',
                  style: TextStyle(color: AppTheme.muted),
                ),
              ),
            )
          else
            SensorLineChart(
              points: trendPoints,
              unit: metricUnit(selectedMetric, catalog),
              hours: 24,
              height: 240,
            ),
        ],
      ),
    );
  }

  Widget _buildAlarms(List<Map<String, dynamic>> alarms) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Aktif Alarmlar',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Text(
                '${alarms.length}',
                style: TextStyle(
                  color: alarms.isEmpty
                      ? AppTheme.green
                      : const Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (alarms.isEmpty)
            const Text(
              'Bu konumda aktif alarm bulunmuyor.',
              style: TextStyle(color: AppTheme.muted),
            )
          else
            ...alarms.take(5).map(
                  (alarm) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF6B6B),
                    ),
                    title: Text(
                      alarm['sensor_name']?.toString() ??
                          alarm['kind']?.toString() ??
                          'Alarm',
                    ),
                    subtitle: Text(
                      '${alarm['device_name'] ?? ''} · ${alarm['location_name'] ?? locationPath(widget.session.locations, alarm['location_id'])}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10,
                      ),
                    ),
                    trailing: Text(
                      ago(alarm['opened_at']),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDevices(List<Map<String, dynamic>> devices) {
    final offlineMinutes =
        int.tryParse('${widget.session.company['offline_minutes'] ?? 3}') ?? 3;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cihazlar',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Text(
                '${devices.length}',
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (devices.isEmpty)
            const Text(
              'Bu konumda cihaz yok.',
              style: TextStyle(color: AppTheme.muted),
            )
          else
            ...devices.map(
              (device) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.memory,
                  color: isOnline(device, offlineMinutes: offlineMinutes)
                      ? AppTheme.green
                      : AppTheme.muted,
                ),
                title: Text(
                  device['name']?.toString() ??
                      device['code']?.toString() ??
                      'Cihaz',
                ),
                subtitle: Text(
                  '${device['code'] ?? ''} · ${locationPath(widget.session.locations, device['location_id'])}',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeviceDetailScreen(
                        session: widget.session,
                        device: device,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = _scopeDevices();
    final sensors = _scopeSensors();
    final alarms = _scopeAlarms();

    return AppBackground(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            MobileTopBar(
              title: 'Detay Görünüm',
              subtitle: 'Bina / oda / dolap bazlı canlı izleme',
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: AppTheme.green),
                      SizedBox(width: 6),
                      Text(
                        'Canlı Veri',
                        style: TextStyle(
                          color: AppTheme.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_buildings.isEmpty)
                    const Panel(
                      child: Text(
                        'Detay görünümü için önce bir bina oluşturun.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    )
                  else ...[
                    _buildSelectors(),
                    const SizedBox(height: 12),
                    _buildScopeSummary(devices, sensors, alarms),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Canlı Sensör Değerleri',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${sensors.length} sensör',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (sensors.isEmpty)
                      const Panel(
                        child: Text(
                          'Bu kapsamda izlemeye alınmış sensör yok.',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                      )
                    else
                      ...sensors.map(_buildSensorCard),
                    const SizedBox(height: 10),
                    _buildTrend(sensors),
                    const SizedBox(height: 14),
                    _buildAlarms(alarms),
                    const SizedBox(height: 14),
                    _buildDevices(devices),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
