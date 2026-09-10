import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../home_screen.dart';
import 'buildings_screen.dart';
import 'dashboard_screen.dart';
import 'devices_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  final AppSession session;
  const MainShell({super.key, required this.session});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(session: widget.session),
      BuildingsScreen(session: widget.session),
      DevicesScreen(session: widget.session),
      const HomeScreen(),
      ProfileScreen(session: widget.session),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: AppTheme.navy2,
        indicatorColor: AppTheme.cyan.withOpacity(.14),
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.apartment_outlined), selectedIcon: Icon(Icons.apartment), label: 'Binalar'),
          NavigationDestination(icon: Icon(Icons.sensors_outlined), selectedIcon: Icon(Icons.sensors), label: 'Cihazlar'),
          NavigationDestination(icon: Icon(Icons.bluetooth_searching), selectedIcon: Icon(Icons.bluetooth_connected), label: 'Yapılandır'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
