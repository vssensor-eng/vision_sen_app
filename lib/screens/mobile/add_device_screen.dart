import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';

class AddDeviceScreen extends StatefulWidget {
  final AppSession session;

  const AddDeviceScreen({super.key, required this.session});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  static const _defaultTimezones = [
    'Europe/Istanbul',
    'UTC',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Paris',
    'Asia/Dubai',
    'Asia/Baku',
    'Asia/Riyadh',
    'America/New_York',
  ];

  final _name = TextEditingController();
  final _code = TextEditingController();
  int? _buildingId;
  int? _floorId;
  int? _locationId;
  late String _timezone;
  int _sendInterval = 1;
  final Set<String> _metrics = {'temperature', 'humidity', 'dew_point'};

  @override
  void initState() {
    super.initState();
    final companyTimezone = widget.session.company['timezone']?.toString().trim() ?? '';
    _timezone = companyTimezone.isEmpty ? 'Europe/Istanbul' : companyTimezone;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
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
    result.sort((a, b) => metricLabel(a, catalog).compareTo(metricLabel(b, catalog)));
    return result;
  }

  List<String> _timezones() {
    final zones = <String>{_timezone, ..._defaultTimezones};
    return zones.toList();
  }

  List<Map<String, dynamic>> get _buildings => widget.session.locations
      .where((item) => item['type'] == 'building')
      .toList();

  List<Map<String, dynamic>> get _floors => widget.session.locations
      .where(
        (item) =>
            item['type'] == 'floor' &&
            int.tryParse('${item['parent_id']}') == _buildingId,
      )
      .toList();

  List<Map<String, dynamic>> get _rooms {
    final parentId = _floorId ?? _buildingId;
    if (parentId == null) return const [];
    return widget.session.locations
        .where(
          (item) =>
              item['type'] == 'room' &&
              int.tryParse('${item['parent_id']}') == parentId,
        )
        .toList();
  }

  List<Map<String, dynamic>> _targetsForRooms(List<Map<String, dynamic>> rooms) {
    final ids = rooms.map((room) => int.tryParse('${room['id']}')).whereType<int>().toSet();
    final cabinets = widget.session.locations
        .where(
          (item) =>
              item['type'] == 'cabinet' &&
              ids.contains(int.tryParse('${item['parent_id']}')),
        )
        .toList();
    return [...rooms, ...cabinets];
  }

  Future<void> _save() async {
    final available = _availableMetrics().toSet();
    final selected = _metrics.where(available.contains).toList();
    if (_name.text.trim().isEmpty ||
        _code.text.trim().isEmpty ||
        _locationId == null ||
        selected.isEmpty) {
      showSessionMessage(
        context,
        'Cihaz adı, seri numarası, oda/dolap ve en az bir sensör seçin.',
      );
      return;
    }
    if (selected.length > 16) {
      showSessionMessage(context, 'Tek işlemde en fazla 16 sensör seçilebilir.');
      return;
    }
    if (!DeviceConfig.isSupportedSendInterval(_sendInterval)) {
      showSessionMessage(context, 'Gönderim aralığı 1, 5 veya 15 dakika olmalı.');
      return;
    }

    final ok = await widget.session.addDevice(
      name: _name.text.trim(),
      code: _code.text.trim(),
      locationId: _locationId!,
      timezone: _timezone,
      sendIntervalMinutes: _sendInterval,
      metrics: selected,
    );
    if (!mounted) return;
    if (ok) {
      showSessionMessage(context, 'Cihaz ve ilk sensörler web hesabına eklendi.');
      Navigator.pop(context);
    } else {
      showSessionMessage(context, widget.session.error ?? 'Cihaz eklenemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.session.metricCatalog;
    final available = _availableMetrics();
    final floors = _floors;
    final rooms = _rooms;
    final targets = _targetsForRooms(rooms);
    final usingLegacyRooms = _buildingId != null && floors.isEmpty;

    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
          children: [
            MobileTopBar(
              title: 'Cihaz Ekle',
              subtitle: 'Ortam İzleme 2.5.77 mobil yönetim',
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
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Cihaz adı',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Seri numarası / cihaz kodu',
                      hintText: 'ESP-001',
                      prefixIcon: Icon(Icons.qr_code_2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _buildingId,
                    decoration: const InputDecoration(
                      labelText: 'Bina',
                      prefixIcon: Icon(Icons.apartment),
                    ),
                    items: _buildings
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: int.tryParse('${item['id']}'),
                            child: Text(item['name']?.toString() ?? 'Bina'),
                          ),
                        )
                        .where((item) => item.value != null)
                        .toList(),
                    onChanged: (value) => setState(() {
                      _buildingId = value;
                      _floorId = null;
                      _locationId = null;
                    }),
                  ),
                  if (_buildingId != null && floors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _floorId,
                      decoration: const InputDecoration(
                        labelText: 'Kat',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: floors
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: int.tryParse('${item['id']}'),
                              child: Text(item['name']?.toString() ?? 'Kat'),
                            ),
                          )
                          .where((item) => item.value != null)
                          .toList(),
                      onChanged: (value) => setState(() {
                        _floorId = value;
                        _locationId = null;
                      }),
                    ),
                  ],
                  if (usingLegacyRooms) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Bu binada kat kaydı yok; eski doğrudan bina→oda kayıtları gösteriliyor.',
                      style: TextStyle(color: Colors.amber, fontSize: 10),
                    ),
                  ],
                  if ((_floorId != null || usingLegacyRooms) && targets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _locationId,
                      decoration: const InputDecoration(
                        labelText: 'Oda / dolap',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                      items: targets
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: int.tryParse('${item['id']}'),
                              child: Text(locationPath(widget.session.locations, item['id'])),
                            ),
                          )
                          .where((item) => item.value != null)
                          .toList(),
                      onChanged: (value) => setState(() => _locationId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _timezone,
                    decoration: const InputDecoration(
                      labelText: 'Saat dilimi',
                      prefixIcon: Icon(Icons.public),
                    ),
                    items: _timezones()
                        .map(
                          (zone) => DropdownMenuItem<String>(value: zone, child: Text(zone)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _timezone = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _sendInterval,
                    decoration: const InputDecoration(
                      labelText: 'Gönderim aralığı',
                      prefixIcon: Icon(Icons.schedule_send_outlined),
                    ),
                    items: DeviceConfig.supportedSendIntervals
                        .map(
                          (minutes) => DropdownMenuItem<int>(
                            value: minutes,
                            child: Text('$minutes dakika'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _sendInterval = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('İlk sensörler', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  const Text(
                    'Sonradan cihaz detayından yeni sensör ekleyebilir, düzenleyebilir veya silebilirsiniz.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  ...available.map(
                    (metric) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _metrics.contains(metric),
                      secondary: Icon(metricIcon(metric), color: metricColor(metric)),
                      title: Text(metricLabel(metric, catalog)),
                      subtitle: metricUnit(metric, catalog).isEmpty
                          ? null
                          : Text(
                              metricUnit(metric, catalog),
                              style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                            ),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            if (_metrics.length < 16) _metrics.add(metric);
                          } else {
                            _metrics.remove(metric);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: widget.session.busy ? 'KAYDEDİLİYOR...' : 'CİHAZI EKLE',
                    icon: Icons.cloud_upload_outlined,
                    onPressed: widget.session.busy || !widget.session.canManage ? null : _save,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Fiziksel ESP Wi-Fi/BLE ayarları ayrı tutulur. Bunun için login sonrasında Yapılandır sekmesini kullanın.',
              style: TextStyle(color: AppTheme.muted, fontSize: 10, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
