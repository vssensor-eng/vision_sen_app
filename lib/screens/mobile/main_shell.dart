import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/wifi_provision_service.dart';
import '../../theme/app_theme.dart';
import '../wifi_provision_screen.dart';
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

class _MainShellState extends State<MainShell> {
  final WifiProvisionService _provision = WifiProvisionService();
  int index = 0;

  @override
  void initState() {
    super.initState();
    _provision.connectionNotifier.addListener(_onProvisioningStateChanged);
  }

  @override
  void dispose() {
    _provision.connectionNotifier.removeListener(_onProvisioningStateChanged);
    _provision.close();
    super.dispose();
  }

  void _onProvisioningStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openIndex(int value) async {
    if (!mounted || value == index) return;

    if (index == 4 && value != 4 && _provision.isConnected) {
      await _provision.disconnect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cihaz Wi-Fi bağlantısı sonlandırıldı.'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    if (!mounted) return;
    setState(() => index = value);
  }

  Future<void> _handleSystemBack(bool didPop) async {
    if (didPop || !_provision.isConnected) return;
    await _provision.disconnect();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Önce cihaz Wi-Fi bağlantısı sonlandırıldı. Çıkmak için geri tuşuna tekrar basın.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
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
      WifiProvisionScreen(provision: _provision),
      ProfileScreen(session: widget.session),
    ];

    return PopScope(
      canPop: !_provision.isConnected,
      onPopInvoked: _handleSystemBack,
      child: Scaffold(
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: NavigationBar(
          height: 70,
          backgroundColor: AppTheme.navy2,
          indicatorColor: AppTheme.cyan.withOpacity(.14),
          selectedIndex: index,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          onDestinationSelected: (value) => _openIndex(value),
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
              icon: Icon(Icons.wifi_tethering_outlined),
              selectedIcon: Icon(Icons.wifi_tethering),
              label: 'Yapılandır',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
