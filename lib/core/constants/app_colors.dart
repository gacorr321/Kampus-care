import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const primary = Color(0xFF1565C0);
  static const primaryLight = Color(0xFF1E88E5);
  static const primaryDark = Color(0xFF0D47A1);

  // Secondary
  static const secondary = Color(0xFF42A5F5);
  static const secondaryLight = Color(0xFF90CAF9);

  // Background & Surface
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F4F8);

  // Status Colors
  static const error = Color(0xFFD32F2F);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF57C00);
  static const info = Color(0xFF0288D1);

  // Text Colors
  static const textDark = Color(0xFF1A237E);
  static const textPrimary = Color(0xFF263238);
  static const textSecondary = Color(0xFF546E7A);
  static const textLight = Color(0xFF90A4AE);
  static const textHint = Color(0xFFB0BEC5);

  // Divider & Border
  static const divider = Color(0xFFE0E6ED);
  static const border = Color(0xFFCFD8DC);

  // Shadow
  static const shadow = Color(0xFF1A237E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softGradient = LinearGradient(
    colors: [Color(0xFFE3F2FD), Color(0xFFF5F7FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
