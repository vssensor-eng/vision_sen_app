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

  Future<void> _delete(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final name = item['name']?.toString() ?? 'Konum';
    final confirmed = await confirmDelete(
      context,
      '$name silinsin mi?',
      'Bu işlem kalıcıdır. Bağlı oda, dolap veya cihaz varsa sunucu silmeye izin vermez.',
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
        if (value == 'edit') {
          _openEditor(context, item: item, type: type);
        } else if (value == 'delete') {
          _delete(context, item);
        } else if (value == 'room') {
          _openEditor(
            context,
            type: 'room',
            parentId: int.tryParse('${item['id']}'),
          );
        } else if (value == 'cabinet') {
          _openEditor(
            context,
            type: 'cabinet',
            parentId: int.tryParse('${item['id']}'),
          );
        }
      },
      itemBuilder: (_) => [
        if (type == 'building')
          const PopupMenuItem(
            value: 'room',
            child: ListTile(
              leading: Icon(Icons.add),
              title: Text('Oda ekle'),
            ),
          ),
        if (type == 'room')
          const PopupMenuItem(
            value: 'cabinet',
            child: ListTile(
              leading: Icon(Icons.add),
              title: Text('Dolap ekle'),
            ),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Düzenle'),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Sil'),
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
                  title: 'Binalar ve Odalar',
                  subtitle: 'Bina → oda → dolap yönetimi',
                  actions: [
                    if (session.canManage)
                      IconButton(
                        tooltip: 'Bina ekle',
                        onPressed: () {
                          _openEditor(context, type: 'building');
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppTheme.cyan,
                        ),
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
                                  onPressed: () {
                                    _openEditor(context, type: 'building');
                                  },
                                ),
                              ],
                            ],
                          ),
                        )
                      : Column(
                          children: buildings.map((building) {
                            final buildingId =
                                int.tryParse('${building['id']}') ?? 0;
                            final rooms = session.locations
                                .where(
                                  (location) =>
                                      location['type'] == 'room' &&
                                      int.tryParse('${location['parent_id']}') ==
                                          buildingId,
                                )
                                .toList();

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
                                    child: const Icon(
                                      Icons.apartment,
                                      color: AppTheme.cyan,
                                    ),
                                  ),
                                  title: Text(
                                    building['name']?.toString() ?? 'Bina',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${rooms.length} oda',
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: session.canManage
                                      ? _menu(
                                          context,
                                          building,
                                          type: 'building',
                                        )
                                      : const Icon(Icons.expand_more),
                                  children: [
                                    if (rooms.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          18,
                                          0,
                                          18,
                                          18,
                                        ),
                                        child: Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Bu binada oda yok.',
                                                style: TextStyle(
                                                  color: AppTheme.muted,
                                                ),
                                              ),
                                            ),
                                            if (session.canManage)
                                              TextButton.icon(
                                                onPressed: () {
                                                  _openEditor(
                                                    context,
                                                    type: 'room',
                                                    parentId: buildingId,
                                                  );
                                                },
                                                icon: const Icon(Icons.add),
                                                label: const Text('Oda'),
                                              ),
                                          ],
                                        ),
                                      )
                                    else
                                      ...rooms.map((room) {
                                        final roomId =
                                            int.tryParse('${room['id']}') ?? 0;
                                        final cabinets = session.locations
                                            .where(
                                              (location) =>
                                                  location['type'] == 'cabinet' &&
                                                  int.tryParse(
                                                        '${location['parent_id']}',
                                                      ) ==
                                                      roomId,
                                            )
                                            .toList();

                                        return Column(
                                          children: [
                                            ListTile(
                                              contentPadding:
                                                  const EdgeInsets.fromLTRB(
                                                18,
                                                2,
                                                8,
                                                2,
                                              ),
                                              leading: const Icon(
                                                Icons.meeting_room_outlined,
                                                color: AppTheme.green,
                                              ),
                                              title: Text(
                                                room['name']?.toString() ?? 'Oda',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              subtitle: Text(
                                                '${cabinets.length} dolap',
                                                style: const TextStyle(
                                                  color: AppTheme.muted,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              trailing: session.canManage
                                                  ? _menu(
                                                      context,
                                                      room,
                                                      type: 'room',
                                                    )
                                                  : const Icon(
                                                      Icons.chevron_right,
                                                    ),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        RoomDetailScreen(
                                                      session: session,
                                                      room: room,
                                                      building: building,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            if (cabinets.isNotEmpty)
                                              ...cabinets.map(
                                                (cabinet) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    left: 30,
                                                  ),
                                                  child: ListTile(
                                                    dense: true,
                                                    leading: const Icon(
                                                      Icons.inventory_2_outlined,
                                                      color: AppTheme.cyan,
                                                      size: 20,
                                                    ),
                                                    title: Text(
                                                      cabinet['name']
                                                              ?.toString() ??
                                                          'Dolap',
                                                    ),
                                                    subtitle: const Text(
                                                      'Odaya bağlı alt konum',
                                                      style: TextStyle(
                                                        color: AppTheme.muted,
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                    trailing: session.canManage
                                                        ? _menu(
                                                            context,
                                                            cabinet,
                                                            type: 'cabinet',
                                                          )
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      }),
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
