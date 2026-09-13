import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';
import 'sensor_chart.dart';

class HistoryScreen extends StatefulWidget {
  final AppSession session;
  final Map<String, dynamic> sensor;

  const HistoryScreen({
    super.key,
    required this.session,
    required this.sensor,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int hours = 24;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> points = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.session.api.history(
        int.parse('${widget.sensor['id']}'),
        hours: hours,
      );
      final raw = data['points'];
      points = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const [];
    } catch (exception) {
      error = exception.toString();
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _rangeLabel(int value) {
    switch (value) {
      case 1:
        return '1 Sa';
      case 6:
        return '6 Sa';
      case 24:
        return '24 Sa';
      case 168:
        return '7 Gün';
      case 720:
        return '30 Gün';
      case 2160:
        return '90 Gün';
      default:
        return '$value Sa';
    }
  }

  double? _number(dynamic value) => double.tryParse('$value');

  Map<String, dynamic>? _deviceForSensor() {
    for (final device in widget.session.devices) {
      if ('${device['id']}' == '${widget.sensor['device_id']}') {
        return device;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final metric = widget.sensor['metric']?.toString() ?? '';
    final catalog = widget.session.metricCatalog;
    final label =
        widget.sensor['name']?.toString() ?? metricLabel(metric, catalog);
    final device = _deviceForSensor();
    final path = locationPath(
      widget.session.locations,
      device == null ? null : device['location_id'],
    );
    final unit = metricUnit(metric, catalog);

    double? minValue;
    double? maxValue;
    for (final point in points) {
      final minimum = _number(point['min_value']) ?? _number(point['value']);
      final maximum = _number(point['max_value']) ?? _number(point['value']);
      if (minimum != null) {
        if (minValue == null || minimum < minValue) {
          minValue = minimum;
        }
      }
      if (maximum != null) {
        if (maxValue == null || maximum > maxValue) {
          maxValue = maximum;
        }
      }
    }

    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
          children: [
            MobileTopBar(
              title: label,
              subtitle:
                  '${device == null ? 'Cihaz' : device['name'] ?? 'Cihaz'} · ${path.isEmpty ? 'Konum yok' : path}',
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in const [1, 6, 24, 168, 720, 2160])
                  ChoiceChip(
                    selected: hours == option,
                    label: Text(_rangeLabel(option)),
                    onSelected: (_) {
                      setState(() => hours = option);
                      _load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: metricColor(metric).withOpacity(.13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          metricIcon(metric),
                          color: metricColor(metric),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metricLabel(metric, catalog),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'X: zaman · Y: ${unit.isEmpty ? 'değer' : unit}',
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
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                            ? Center(
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF7A7A),
                                  ),
                                ),
                              )
                            : points.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Bu aralıkta veri yok.',
                                      style: TextStyle(color: AppTheme.muted),
                                    ),
                                  )
                                : SensorLineChart(
                                    points: points,
                                    unit: unit,
                                    hours: hours,
                                    height: 300,
                                  ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    icon: metricIcon(metric),
                    label: 'Güncel',
                    value: formatValue(widget.sensor['latest_value'], unit),
                    color: metricColor(metric),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricTile(
                    icon: Icons.arrow_downward,
                    label: 'Minimum',
                    value: minValue == null
                        ? '—'
                        : formatValue(minValue, unit),
                    color: AppTheme.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    icon: Icons.arrow_upward,
                    label: 'Maksimum',
                    value: maxValue == null
                        ? '—'
                        : formatValue(maxValue, unit),
                    color: const Color(0xFFFFB85C),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricTile(
                    icon: Icons.update,
                    label: 'Son Güncelleme',
                    value: ago(widget.sensor['latest_at']),
                    color: AppTheme.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Grafikte ortalama kartı gösterilmez. Y ekseni ölçüm birimini, X ekseni zaman aralığını gösterir.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
