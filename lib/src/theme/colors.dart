import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CyberTheme {
  // Ultra-clean premium dark mode palette
  static const Color darkBg = Color(0xFF06070C); // Deep obsidian
  static const Color cardBg = Color(0xFF0E101A); // Clean dark panel background
  static const Color gridBg = Color(0xFF08090E); // Slightly darker grid arena
  static const Color neonCyan = Color(0xFF00E5FF); // Electric Sky Cyan
  static const Color neonPink = Color(0xFFFF2D7F); // Deep Hot Pink
  static const Color neonGreen = Color(0xFF00E676); // Minty Neon Green
  static const Color neonYellow = Color(0xFFFFD600); // Rich Cyber Yellow
  static const Color neonPurple = Color(
    0xFF8E24AA,
  ); // Darker purple for UI highlights
  static const Color textMain = Color(
    0xFFF1F5F9,
  ); // Slate-50 high contrast text
  static const Color textMuted = Color(0xFF64748B); // Slate-500 muted text
  static const Color borderTranslucent = Color(
    0x1F64748B,
  ); // Modern thin divider border color

  // Premium glow effect with soft blur
  static List<BoxShadow> neonGlow(Color color, {double radius = 12.0}) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: radius,
      spreadRadius: -2.0,
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.08),
      blurRadius: radius * 2,
      spreadRadius: 2.0,
    ),
  ];

  // Technical sci-fi typography
  static TextStyle fontHeading({double size = 24, Color color = textMain}) {
    return GoogleFonts.orbitron(
      fontSize: size,
      fontWeight: FontWeight.bold,
      color: color,
      letterSpacing: 1.2,
    );
  }

  static TextStyle fontSubheading({double size = 19, Color color = textMain}) {
    return GoogleFonts.orbitron(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 1.0,
    );
  }

  static TextStyle fontBody({
    double size = 16,
    Color color = textMain,
    bool bold = false,
  }) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
  }

  static TextStyle fontCode({double size = 12, Color color = textMain}) {
    return GoogleFonts.shareTechMono(
      fontSize: size,
      color: color,
      letterSpacing: 0.5,
    );
  }
}
