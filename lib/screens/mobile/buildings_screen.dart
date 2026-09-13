import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'location_editor_screen.dart';
import 'mobile_widgets.dart';
import 'room_detail_screen.dart';

class BuildingsScreen extends StatelessWidget {
  final AppSession session;

  const BuildingsScreen({super.key, required this.session});

  Future<void> _openEditor(
    BuildContext context, {
    Map<String, dynamic>? item,
    required String type,
    int? parentId,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationEditorScreen(
          session: session,
          location: item,
          type: type,
          parentId: parentId,
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? 'Konum';
    final confirmed = await confirmDelete(
      context,
      '$name silinsin mi?',
      'Bu işlem kalıcıdır. Bağlı alt konum veya cihaz varsa sunucu silmeye izin vermez.',
    );
    if (!confirmed) return;
    final ok = await session.deleteLocation(int.parse('${item['id']}'));
    if (!context.mounted) return;
    showSessionMessage(
      context,
      ok ? 'Konum silindi.' : session.error ?? 'Konum silinemedi.',
    );
  }

  PopupMenuButton<String> _menu(
    BuildContext context,
    Map<String, dynamic> item, {
    required String type,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        final id = int.tryParse('${item['id']}');
        if (value == 'edit') {
          _openEditor(context, item: item, type: type);
        } else if (value == 'delete') {
          _delete(context, item);
        } else if (value == 'floor' && id != null) {
          _openEditor(context, type: 'floor', parentId: id);
        } else if (value == 'room' && id != null) {
          _openEditor(context, type: 'room', parentId: id);
        } else if (value == 'cabinet' && id != null) {
          _openEditor(context, type: 'cabinet', parentId: id);
        }
      },
      itemBuilder: (_) => [
        if (type == 'building')
          const PopupMenuItem(
            value: 'floor',
            child: ListTile(leading: Icon(Icons.add), title: Text('Kat ekle')),
          ),
        if (type == 'floor')
          const PopupMenuItem(
            value: 'room',
            child: ListTile(leading: Icon(Icons.add), title: Text('Oda ekle')),
          ),
        if (type == 'room')
          const PopupMenuItem(
            value: 'cabinet',
            child: ListTile(leading: Icon(Icons.add), title: Text('Dolap ekle')),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Düzenle')),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Sil')),
        ),
      ],
    );
  }

  Widget _roomTile(
    BuildContext context,
    Map<String, dynamic> room,
    Map<String, dynamic> building,
  ) {
    final roomId = int.tryParse('${room['id']}') ?? 0;
    final cabinets = session.locations
        .where(
          (location) =>
              location['type'] == 'cabinet' &&
              int.tryParse('${location['parent_id']}') == roomId,
        )
        .toList();
    final usage = room['usage_type']?.toString().trim() ?? '';
    final area = room['area_m2'];
    final meta = <String>[
      if (usage.isNotEmpty) usage,
      if (area != null && '$area'.isNotEmpty) '$area m²',
      '${cabinets.length} dolap',
    ].join(' • ');

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(24, 2, 8, 2),
          leading: const Icon(Icons.meeting_room_outlined, color: AppTheme.green),
          title: Text(
            room['name']?.toString() ?? 'Oda',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            meta,
            style: const TextStyle(color: AppTheme.muted, fontSize: 10),
          ),
          trailing: session.canManage
              ? _menu(context, room, type: 'room')
              : const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomDetailScreen(
                session: session,
                room: room,
                building: building,
              ),
            ),
          ),
        ),
        if (cabinets.isNotEmpty)
          ...cabinets.map(
            (cabinet) => Padding(
              padding: const EdgeInsets.only(left: 42),
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppTheme.cyan,
                  size: 20,
                ),
                title: Text(cabinet['name']?.toString() ?? 'Dolap'),
                subtitle: const Text(
                  'Odaya bağlı alt konum',
                  style: TextStyle(color: AppTheme.muted, fontSize: 9),
                ),
                trailing: session.canManage
                    ? _menu(context, cabinet, type: 'cabinet')
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          final buildings = session.locations
              .where((location) => location['type'] == 'building')
              .toList();

          return RefreshIndicator(
            onRefresh: session.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                MobileTopBar(
                  title: 'Binalar, Katlar ve Odalar',
                  subtitle: 'Bina → kat → oda → dolap yönetimi',
                  actions: [
                    if (session.canManage)
                      IconButton(
                        tooltip: 'Bina ekle',
                        onPressed: () => _openEditor(context, type: 'building'),
                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.cyan),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: buildings.isEmpty
                      ? Panel(
                          child: Column(
                            children: [
                              const Text(
                                'Henüz bina oluşturulmamış.',
                                style: TextStyle(color: AppTheme.muted),
                              ),
                              if (session.canManage) ...[
                                const SizedBox(height: 14),
                                PrimaryButton(
                                  text: 'BİNA EKLE',
                                  icon: Icons.add_business,
                                  onPressed: () => _openEditor(context, type: 'building'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Column(
                          children: buildings.map((building) {
                            final buildingId = int.tryParse('${building['id']}') ?? 0;
                            final floors = session.locations
                                .where(
                                  (location) =>
                                      location['type'] == 'floor' &&
                                      int.tryParse('${location['parent_id']}') == buildingId,
                                )
                                .toList();
                            final legacyRooms = session.locations
                                .where(
                                  (location) =>
                                      location['type'] == 'room' &&
                                      int.tryParse('${location['parent_id']}') == buildingId,
                                )
                                .toList();
                            final floorIds = floors
                                .map((floor) => int.tryParse('${floor['id']}'))
                                .whereType<int>()
                                .toSet();
                            final floorRoomCount = session.locations
                                .where(
                                  (location) =>
                                      location['type'] == 'room' &&
                                      floorIds.contains(int.tryParse('${location['parent_id']}')),
                                )
                                .length;
                            final usage = building['usage_type']?.toString().trim() ?? '';
                            final address = building['address']?.toString().trim() ?? '';
                            final subtitle = <String>[
                              if (usage.isNotEmpty) usage,
                              '${floors.length} kat',
                              '${floorRoomCount + legacyRooms.length} oda',
                              if (address.isNotEmpty) address,
                            ].join(' • ');

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Panel(
                                padding: EdgeInsets.zero,
                                child: ExpansionTile(
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppTheme.cyan.withOpacity(.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.apartment, color: AppTheme.cyan),
                                  ),
                                  title: Text(
                                    building['name']?.toString() ?? 'Bina',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  subtitle: Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                                  ),
                                  trailing: session.canManage
                                      ? _menu(context, building, type: 'building')
                                      : const Icon(Icons.expand_more),
                                  children: [
                                    if (floors.isEmpty && legacyRooms.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                                        child: Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Bu binada henüz kat yok.',
                                                style: TextStyle(color: AppTheme.muted),
                                              ),
                                            ),
                                            if (session.canManage)
                                              TextButton.icon(
                                                onPressed: () => _openEditor(
                                                  context,
                                                  type: 'floor',
                                                  parentId: buildingId,
                                                ),
                                                icon: const Icon(Icons.add),
                                                label: const Text('Kat'),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ...floors.map((floor) {
                                      final floorId = int.tryParse('${floor['id']}') ?? 0;
                                      final rooms = session.locations
                                          .where(
                                            (location) =>
                                                location['type'] == 'room' &&
                                                int.tryParse('${location['parent_id']}') == floorId,
                                          )
                                          .toList();
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.panel2.withOpacity(.45),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: ExpansionTile(
                                            shape: const Border(),
                                            collapsedShape: const Border(),
                                            leading: const Icon(Icons.layers_outlined, color: AppTheme.cyan),
                                            title: Text(
                                              floor['name']?.toString() ?? 'Kat',
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                            subtitle: Text(
                                              '${rooms.length} oda',
                                              style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                                            ),
                                            trailing: session.canManage
                                                ? _menu(context, floor, type: 'floor')
                                                : const Icon(Icons.expand_more),
                                            children: [
                                              if (rooms.isEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                                                  child: Row(
                                                    children: [
                                                      const Expanded(
                                                        child: Text(
                                                          'Bu katta oda yok.',
                                                          style: TextStyle(color: AppTheme.muted),
                                                        ),
                                                      ),
                                                      if (session.canManage)
                                                        TextButton.icon(
                                                          onPressed: () => _openEditor(
                                                            context,
                                                            type: 'room',
                                                            parentId: floorId,
                                                          ),
                                                          icon: const Icon(Icons.add),
                                                          label: const Text('Oda'),
                                                        ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                ...rooms.map(
                                                  (room) => _roomTile(context, room, building),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                    if (legacyRooms.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(18, 8, 18, 4),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Eski kayıtlar • doğrudan binaya bağlı odalar',
                                            style: TextStyle(
                                              color: Colors.amber,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      ...legacyRooms.map(
                                        (room) => _roomTile(context, room, building),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
