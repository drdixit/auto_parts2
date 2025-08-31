import 'package:flutter/material.dart';

/// Centralized semantic color tokens for the app.
class AppColors {
  // Surfaces
  // Off-white surface used instead of pure white to avoid harsh contrast.
  // Hex: #F7FAFC
  static const Color surface = Color(0xFFF7FAFC);
  static const Color surfaceMuted = Color(0xFFF3F4F6); // light gray
  // Use the same off-white as surface for light backgrounds to keep visuals consistent.
  static const Color surfaceLight = Color(0xFFF7FAFC);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  // Semantic
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  // Controls
  static const Color buttonNeutral = Color(0xFF111827);
  static const Color chipSelected = Color(0xFF10B981);
  // Utility
  static const Color transparent = Color(0x00000000);
}
