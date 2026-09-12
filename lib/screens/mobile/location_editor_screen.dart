import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';

class LocationEditorScreen extends StatefulWidget {
  final AppSession session;
  final Map<String, dynamic>? location;
  final String type;
  final int? parentId;

  const LocationEditorScreen({
    super.key,
    required this.session,
    this.location,
    required this.type,
    this.parentId,
  });

  @override
  State<LocationEditorScreen> createState() => _LocationEditorScreenState();
}

class _LocationEditorScreenState extends State<LocationEditorScreen> {
  static const buildingTypes = [
    'Ofis',
    'Fabrika',
    'Depo',
    'Laboratuvar',
    'Hastane',
    'Okul',
    'Konut',
    'Kamu Binası',
    'Ticari Bina',
    'Diğer',
  ];
  static const roomTypes = [
    'Ofis',
    'Toplantı Odası',
    'Laboratuvar',
    'Depo',
    'Server Odası',
    'Mutfak',
    'Arşiv',
    'Teknik Oda',
    'Üretim Alanı',
    'Sınıf',
    'Diğer',
  ];

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _address;
  late final TextEditingController _area;
  int? _parentId;
  String _usageType = '';

  @override
  void initState() {
    super.initState();
    final item = widget.location;
    _name = TextEditingController(text: item?['name']?.toString() ?? '');
    _description = TextEditingController(text: item?['description']?.toString() ?? '');
    _address = TextEditingController(text: item?['address']?.toString() ?? '');
    _area = TextEditingController(
      text: item?['area_m2'] == null ? '' : '${item!['area_m2']}',
    );
    _parentId = item == null ? widget.parentId : int.tryParse('${item['parent_id']}');
    _usageType = item?['usage_type']?.toString() ?? '';
    if (_usageType.isEmpty) {
      if (_type == 'building') _usageType = buildingTypes.first;
      if (_type == 'room') _usageType = roomTypes.first;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _area.dispose();
    super.dispose();
  }

  String get _type => widget.location?['type']?.toString() ?? widget.type;

  String? get _parentType {
    switch (_type) {
      case 'floor':
        return 'building';
      case 'room':
        return 'floor';
      case 'cabinet':
        return 'room';
      default:
        return null;
    }
  }

  String get _title {
    if (widget.location != null) return 'Konumu Düzenle';
    switch (_type) {
      case 'building':
        return 'Bina Ekle';
      case 'floor':
        return 'Kat Ekle';
      case 'room':
        return 'Oda Ekle';
      default:
        return 'Dolap Ekle';
    }
  }

  String get _subtitle {
    switch (_type) {
      case 'building':
        return 'Bina bilgileri';
      case 'floor':
        return 'Binaya bağlı kat';
      case 'room':
        return 'Kata bağlı oda';
      default:
        return 'Odaya bağlı dolap';
    }
  }

  String get _parentLabel {
    switch (_type) {
      case 'floor':
        return 'Bina';
      case 'room':
        return 'Kat';
      default:
        return 'Oda';
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showSessionMessage(context, 'Ad alanını doldurun.');
      return;
    }
    if (_type != 'building' && _parentId == null) {
      showSessionMessage(context, 'Üst konumu seçin.');
      return;
    }

    num? areaM2;
    if (_type == 'room' && _area.text.trim().isNotEmpty) {
      areaM2 = num.tryParse(_area.text.trim().replaceAll(',', '.'));
      if (areaM2 == null || areaM2 <= 0 || areaM2 > 100000) {
        showSessionMessage(context, 'Oda alanı 0 ile 100000 m² arasında olmalı.');
        return;
      }
    }

    final item = widget.location;
    final ok = await widget.session.saveLocation(
      id: item == null ? null : int.tryParse('${item['id']}'),
      name: _name.text.trim(),
      type: _type,
      parentId: _parentId,
      description: _description.text.trim(),
      address: _address.text.trim(),
      usageType: _usageType,
      areaM2: areaM2,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      showSessionMessage(context, widget.session.error ?? 'Konum kaydedilemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentType = _parentType;
    final parents = parentType == null
        ? <Map<String, dynamic>>[]
        : widget.session.locations.where((location) => location['type'] == parentType).toList();
    final editing = widget.location != null;

    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
          children: [
            MobileTopBar(
              title: _title,
              subtitle: _subtitle,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Panel(
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Ad',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  if (_type != 'building') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _parentId,
                      decoration: InputDecoration(
                        labelText: _parentLabel,
                        prefixIcon: const Icon(Icons.account_tree_outlined),
                        helperText: editing
                            ? 'Mevcut kaydın üst konumu sonradan değiştirilemez.'
                            : null,
                      ),
                      items: parents
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: int.tryParse('${item['id']}'),
                              child: Text(locationPath(widget.session.locations, item['id'])),
                            ),
                          )
                          .where((item) => item.value != null)
                          .toList(),
                      onChanged: editing ? null : (value) => setState(() => _parentId = value),
                    ),
                    if (!editing && parents.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _type == 'room'
                            ? 'Önce binaya bir kat ekleyin.'
                            : 'Gerekli üst konumu önce oluşturun.',
                        style: const TextStyle(color: Colors.amber, fontSize: 11),
                      ),
                    ],
                  ],
                  if (_type == 'building' || _type == 'room') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _usageType.isEmpty ? null : _usageType,
                      decoration: InputDecoration(
                        labelText: _type == 'building' ? 'Bina kullanım tipi' : 'Oda kullanım tipi',
                        prefixIcon: Icon(
                          _type == 'building' ? Icons.apartment : Icons.meeting_room_outlined,
                        ),
                      ),
                      items: (_type == 'building' ? buildingTypes : roomTypes)
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _usageType = value ?? ''),
                    ),
                  ],
                  if (_type == 'building') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _address,
                      decoration: const InputDecoration(
                        labelText: 'Adres (opsiyonel)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bina görseli web panelindeki bina düzenleme ekranından yönetilir.',
                        style: TextStyle(color: AppTheme.muted, fontSize: 10.5),
                      ),
                    ),
                  ],
                  if (_type == 'room') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _area,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Oda alanı (m², opsiyonel)',
                        prefixIcon: Icon(Icons.square_foot),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    text: widget.session.busy ? 'KAYDEDİLİYOR...' : 'KAYDET',
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
