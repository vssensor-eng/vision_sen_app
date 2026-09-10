import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AppSession session;

  @override
  void initState() {
    super.initState();
    session = AppSession();
    session.restore();
  }

  @override
  void dispose() {
    session.api.close();
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          if (session.initializing) {
            return const Scaffold(
              backgroundColor: AppTheme.navy,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return session.authenticated ? MainShell(session: session) : LoginScreen(session: session);
        },
      );
}
