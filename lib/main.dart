import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(const VisionSenApp());

class VisionSenApp extends StatelessWidget {
  const VisionSenApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VISIONSEN Device Setup',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const HomeScreen(),
      );
}
