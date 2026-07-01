/// アプリ全体で共通のパレット。本詳細画面 (Figma 準拠) をベースに、
/// 各画面から参照して見た目を統一する。
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color bg = Color(0xFFF7F3EE);
  static const Color fg = Color(0xFF2C2416);
  static const Color primary = Color(0xFF4A3728);
  static const Color primaryFg = Color(0xFFF7F3EE);
  static const Color secondary = Color(0xFFE8DFD4);
  static const Color secondaryFg = Color(0xFF4A3728);
  static const Color muted = Color(0xFFEDE5DA);
  static const Color mutedFg = Color(0xFF7A6A58);
  static const Color accent = Color(0xFFC9A96E);
  static const Color border = Color(0x1F4A3728); // ~12% dark brown
  static const Color starIdle = Color(0xFFC5B8A8);
  static const Color favoritePink = Color(0xFFE05252);
  static const Color favoriteBg = Color(0xFFFDE8E8);
  static const Color headerBg = Color(0xFF3A2A1E);
  static const Color asideStart = Color(0xFF4A3728);
  static const Color asideMid = Color(0xFF5E4535);
  static const Color asideEnd = Color(0xFF7A5A42);
}
