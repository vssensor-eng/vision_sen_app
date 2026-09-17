import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'mobile_widgets.dart';

class ProfileScreen extends StatelessWidget {
  final AppSession session;
  const ProfileScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) => AppBackground(
        child: AnimatedBuilder(
          animation: session,
          builder: (context, _) {
            final user = session.user;
            final company = session.company;
            return ListView(
              padding: const EdgeInsets.only(bottom: 30),
              children: [
                const MobileTopBar(title: 'Hesabım', subtitle: 'VisionSen mobil uygulama'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      Panel(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: AppTheme.panel2,
                              child: Text((user['name']?.toString().trim().isNotEmpty == true ? user['name'].toString().trim()[0] : 'V').toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.cyan)),
                            ),
                            const SizedBox(height: 12),
                            Text(user['name']?.toString() ?? 'Kullanıcı', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(user['email']?.toString() ?? user['login']?.toString() ?? '', style: const TextStyle(color: AppTheme.muted)),
                            const SizedBox(height: 6),
                            Text(company['name']?.toString() ?? '', style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Panel(
                        child: Column(
                          children: [
                            _row(Icons.badge_outlined, 'Rol', user['role']?.toString() == 'manager' ? 'Yönetici' : 'İzleyici'),
                            const Divider(color: AppTheme.line),
                            _row(Icons.business_outlined, 'Firma', company['name']?.toString() ?? '—'),
                            const Divider(color: AppTheme.line),
                            _row(Icons.cloud_outlined, 'Veri saklama', '${company['retention_days'] ?? '—'} gün'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SecondaryButton(text: 'ÇIKIŞ YAP', onPressed: () => session.logout()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Icon(icon, color: AppTheme.cyan), const SizedBox(width: 12), Expanded(child: Text(label)), Text(value, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700))]),
      );
}
