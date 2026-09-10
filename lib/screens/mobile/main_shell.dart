import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/alarm_notification_service.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../home_screen.dart';
import 'buildings_screen.dart';
import 'dashboard_screen.dart';
import 'detail_screen.dart';
import 'devices_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  final AppSession session;

  const MainShell({super.key, required this.session});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int index = 0;
  Timer? _alarmTimer;
  bool _pollingAlarms = false;
  final Set<String> _knownAlarmIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAlarmWatcher());
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollAlarms();
    }
  }

  Future<void> _startAlarmWatcher() async {
    await AlarmNotificationService.instance.initialize();
    _knownAlarmIds
      ..clear()
      ..addAll(widget.session.alarms.map(_alarmKey));

    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _pollAlarms(),
    );
  }

  Future<void> _pollAlarms() async {
    if (_pollingAlarms || !widget.session.authenticated) return;
    _pollingAlarms = true;
    try {
      final data = await widget.session.api.alarms(state: 'open');
      final raw = data['items'];
      final items = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      final currentIds = items.map(_alarmKey).toSet();
      final newItems = items
          .where((alarm) => !_knownAlarmIds.contains(_alarmKey(alarm)))
          .toList();

      _knownAlarmIds
        ..clear()
        ..addAll(currentIds);
      widget.session.replaceOpenAlarms(items);

      for (final alarm in newItems) {
        await AlarmNotificationService.instance.showAlarm(alarm);
      }
    } catch (_) {
      // Alarm izleme hatası ana uygulama akışını veya BLE kurulumunu bozmaz.
    } finally {
      _pollingAlarms = false;
    }
  }

  String _alarmKey(Map<String, dynamic> alarm) {
    final id = alarm['id'];
    if (id != null && '$id'.isNotEmpty) return '$id';
    return '${alarm['kind']}:${alarm['device_id']}:${alarm['sensor_id']}:${alarm['opened_at']}';
  }

  void _openIndex(int value) {
    if (!mounted) return;
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        session: widget.session,
        onOpenDetail: () => _openIndex(1),
        onOpenDevices: () => _openIndex(3),
      ),
      DetailScreen(session: widget.session),
      BuildingsScreen(session: widget.session),
      DevicesScreen(session: widget.session),
      const HomeScreen(),
      ProfileScreen(session: widget.session),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: AppTheme.navy2,
        indicatorColor: AppTheme.cyan.withOpacity(.14),
        selectedIndex: index,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: _openIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana',
          ),
          NavigationDestination(
            icon: Icon(Icons.visibility_outlined),
            selectedIcon: Icon(Icons.visibility),
            label: 'Detay',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Binalar',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors),
            label: 'Cihazlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            selectedIcon: Icon(Icons.bluetooth_connected),
            label: 'Yapılandır',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
