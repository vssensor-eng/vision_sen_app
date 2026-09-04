import 'package:flutter/material.dart';

class AppTheme {
  static const navy = Color(0xFF061525);
  static const navy2 = Color(0xFF091C2D);
  static const panel = Color(0xFF0D2237);
  static const panel2 = Color(0xFF102A42);
  static const cyan = Color(0xFF2AA9E8);
  static const blue = Color(0xFF268FEA);
  static const green = Color(0xFF65D46F);
  static const text = Color(0xFFF4F8FC);
  static const muted = Color(0xFF8FA5B9);
  static const line = Color(0x263D6078);

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: cyan,
          secondary: green,
          surface: panel,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14, color: text),
          bodySmall: TextStyle(fontSize: 12, color: muted),
          titleMedium: TextStyle(fontWeight: FontWeight.w800),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          labelStyle: const TextStyle(color: muted, fontSize: 13),
          hintStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: line),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: cyan, width: 1.2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      );
}
