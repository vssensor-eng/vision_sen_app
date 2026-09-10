import 'package:flutter/material.dart';

import '../../services/app_session.dart';
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
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _address;
  int? _parentId;

  @override
  void initState() {
    super.initState();
    final item = widget.location;
    _name = TextEditingController(
      text: item == null ? '' : item['name']?.toString() ?? '',
    );
    _description = TextEditingController(
      text: item == null ? '' : item['description']?.toString() ?? '',
    );
    _address = TextEditingController(
      text: item == null ? '' : item['address']?.toString() ?? '',
    );
    _parentId = item == null
        ? widget.parentId
        : int.tryParse('${item['parent_id']}');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  String get _type {
    final item = widget.location;
    return item == null ? widget.type : item['type']?.toString() ?? widget.type;
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

    final item = widget.location;
    final ok = await widget.session.saveLocation(
      id: item == null ? null : int.tryParse('${item['id']}'),
      name: _name.text.trim(),
      type: _type,
      parentId: _parentId,
      description: _description.text.trim(),
      address: _address.text.trim(),
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
    final parentType = _type == 'room' ? 'building' : 'room';
    final parents = widget.session.locations
        .where((location) => location['type'] == parentType)
        .toList();
    final editing = widget.location != null;
    final title = editing
        ? 'Konumu Düzenle'
        : _type == 'building'
            ? 'Bina Ekle'
            : _type == 'room'
                ? 'Oda Ekle'
                : 'Dolap Ekle';

    return Scaffold(
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
          children: [
            MobileTopBar(
              title: title,
              subtitle: _type == 'building'
                  ? 'Bina bilgileri'
                  : _type == 'room'
                      ? 'Binaya bağlı oda'
                      : 'Odaya bağlı dolap',
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
                        labelText: _type == 'room' ? 'Bina' : 'Oda',
                        prefixIcon: const Icon(Icons.account_tree_outlined),
                      ),
                      items: parents
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: int.tryParse('${item['id']}'),
                              child: Text(
                                locationPath(widget.session.locations, item['id']),
                              ),
                            ),
                          )
                          .where((item) => item.value != null)
                          .toList(),
                      onChanged: editing
                          ? null
                          : (value) => setState(() => _parentId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  if (_type == 'building') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _address,
                      decoration: const InputDecoration(
                        labelText: 'Adres (opsiyonel)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ],
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
