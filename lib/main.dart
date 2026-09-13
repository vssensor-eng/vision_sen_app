import 'package:flutter/material.dart';
import 'screens/mobile/auth_gate.dart';
import 'theme/app_theme.dart';

void main() => runApp(const VisionSenApp());

class VisionSenApp extends StatelessWidget {
  const VisionSenApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VisionSen Mobil',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const AuthGate(),
      );
}
