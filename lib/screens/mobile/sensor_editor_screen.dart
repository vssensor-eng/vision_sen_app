import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';

class SensorEditorScreen extends StatefulWidget {
  final AppSession session;
  final Map<String, dynamic> device;
  final Map<String, dynamic>? sensor;

  const SensorEditorScreen({
    super.key,
    required this.session,
    required this.device,
    this.sensor,
  });

  @override
  State<SensorEditorScreen> createState() => _SensorEditorScreenState();
}

class _SensorEditorScreenState extends State<SensorEditorScreen> {
  String? _metric;
  bool _enabled = true;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  int _alarmValue = 1;

  @override
  void initState() {
    super.initState();
    final sensor = widget.sensor;
    _metric = sensor == null ? null : sensor['metric']?.toString();
    _enabled = sensor == null ? true : truthy(sensor['enabled']);
    _minController = TextEditingController(
      text: sensor == null ? '' : sensor['min_value']?.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: sensor == null ? '' : sensor['max_value']?.toString() ?? '',
    );
    _alarmValue = sensor == null
        ? 1
        : int.tryParse('${sensor['alarm_value'] ?? 1}') ?? 1;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  List<String> _availableMetrics() {
    final catalog = widget.session.metricCatalog;
    final result = catalog.entries
        .where((entry) {
          final value = entry.value;
          if (value is! Map) return false;
          return Map<String, dynamic>.from(value)['selectable'] != false;
        })
        .map((entry) => entry.key)
        .toList();
    result.sort(
      (a, b) => metricLabel(a, catalog).compareTo(metricLabel(b, catalog)),
    );
    return result;
  }

  Future<void> _save() async {
    final metric = _metric;
    if (metric == null) {
      showSessionMessage(context, 'Sensör türünü seçin.');
      return;
    }

    final digital = metric == 'smoke' || metric == 'fire';
    final minValue = double.tryParse(
      _minController.text.trim().replaceAll(',', '.'),
    );
    final maxValue = double.tryParse(
      _maxController.text.trim().replaceAll(',', '.'),
    );
    if (!digital && minValue != null && maxValue != null && minValue >= maxValue) {
      showSessionMessage(context, 'Alt eşik üst eşikten küçük olmalı.');
      return;
    }

    final sensor = widget.sensor;
    final ok = await widget.session.saveSensor(
      id: sensor == null ? null : int.parse('${sensor['id']}'),
      deviceId: int.parse('${widget.device['id']}'),
      metric: metric,
      enabled: _enabled,
      minValue: digital ? null : minValue,
      maxValue: digital ? null : maxValue,
      alarmValue: _alarmValue,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      showSessionMessage(context, widget.session.error ?? 'Sensör kaydedilemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.session.metricCatalog;
    final available = _availableMetrics();
    final digital = _metric == 'smoke' || _metric == 'fire';
    final editing = widget.sensor != null;

    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
          children: [
            MobileTopBar(
              title: editing ? 'Sensörü Düzenle' : 'Sensör Ekle',
              subtitle: widget.device['name']?.toString(),
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _metric,
                    decoration: const InputDecoration(
                      labelText: 'Sensör türü',
                      prefixIcon: Icon(Icons.sensors),
                    ),
                    items: available
                        .map(
                          (metric) => DropdownMenuItem<String>(
                            value: metric,
                            child: Text(
                              '${metricLabel(metric, catalog)}${metricUnit(metric, catalog).isEmpty ? '' : ' · ${metricUnit(metric, catalog)}'}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: editing
                        ? null
                        : (value) => setState(() => _metric = value),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'İzlemeye al',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Sensör aktif izlemeye dahil edilir.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  if (_metric != null) ...[
                    const SizedBox(height: 8),
                    if (digital)
                      DropdownButtonFormField<int>(
                        value: _alarmValue,
                        decoration: const InputDecoration(labelText: 'Alarm değeri'),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 = Alarm')),
                          DropdownMenuItem(value: 0, child: Text('0 = Alarm')),
                        ],
                        onChanged: (value) {
                          setState(() => _alarmValue = value ?? 1);
                        },
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: const InputDecoration(labelText: 'Alt eşik'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _maxController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: const InputDecoration(labelText: 'Üst eşik'),
                            ),
                          ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 18),
                  PrimaryButton(
                    text: widget.session.busy
                        ? 'KAYDEDİLİYOR...'
                        : 'SENSÖRÜ KAYDET',
                    icon: Icons.save_outlined,
                    onPressed: widget.session.busy ? null : _save,
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
