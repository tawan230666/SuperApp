import 'package:flutter/material.dart';
import 'design_tokens.dart';

ThemeData buildCapitalTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'NotoSansThai',
  colorScheme: const ColorScheme.light(
    primary: green,
    onPrimary: Colors.white,
    secondary: green,
    onSecondary: Colors.white,
    secondaryContainer: mint,
    onSecondaryContainer: ink,
    surface: surface,
    onSurface: ink,
    surfaceContainerHighest: mint,
    outline: border,
    error: Color(0xFFAD5142),
  ),
  scaffoldBackgroundColor: canvas,
  appBarTheme: const AppBarTheme(
    backgroundColor: surface,
    foregroundColor: ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    toolbarHeight: 72,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    titleTextStyle: const TextStyle(
      fontFamily: 'NotoSansThai',
      fontSize: 21,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: surface,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: charcoal,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: green,
    linearTrackColor: mint,
  ),
  dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 28),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: surface,
    indicatorColor: mint,
    iconTheme: WidgetStatePropertyAll(IconThemeData(color: green)),
    elevation: 0,
    height: 74,
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: charcoal,
    indicatorColor: Color(0xFF175344),
    selectedIconTheme: IconThemeData(color: Colors.white),
    unselectedIconTheme: IconThemeData(color: railText),
    selectedLabelTextStyle: TextStyle(
      fontFamily: 'NotoSansThai',
      color: Colors.white,
      fontWeight: FontWeight.w700,
    ),
    unselectedLabelTextStyle: TextStyle(
      fontFamily: 'NotoSansThai',
      color: railText,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'NotoSansThai',
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: canvas,
    selectedColor: mint,
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    labelStyle: const TextStyle(
      fontFamily: 'NotoSansThai',
      color: ink,
      fontSize: 12,
    ),
    padding: const EdgeInsets.all(7),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: green, width: 1.5),
    ),
    filled: true,
    fillColor: Color(0xFFF8FAF9),
    labelStyle: const TextStyle(fontFamily: 'NotoSansThai', color: muted),
    contentPadding: const EdgeInsets.all(18),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: ink),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
    headlineMedium: TextStyle(
      fontSize: 30,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
  ),
);
