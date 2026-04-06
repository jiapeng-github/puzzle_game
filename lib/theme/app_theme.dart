import 'package:flutter/material.dart';

/// 应用主题配置 - 卡通休闲风格
class AppTheme {
  // 主色调
  static const Color primaryColor = Color(0xFF4FC3F7);   // 天蓝
  static const Color secondaryColor = Color(0xFFFF7043); // 橙色
  static const Color accentColor = Color(0xFFFFD54F);    // 金黄
  static const Color backgroundColor = Color(0xFFFFF9E6); // 暖白
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xFF2D2D2D);
  static const Color textMedium = Color(0xFF5A5A5A);

  // 游戏卡片颜色（与各游戏对应）
  static const List<Color> gameColors = [
    Color(0xFF6C63FF), // 紫色 - 五子棋
    Color(0xFFFF7043), // 橙色 - 2048
    Color(0xFF43C6AC), // 青绿 - 消消乐
    Color(0xFF4FC3F7), // 天蓝 - 飞行棋
    Color(0xFF81C784), // 草绿 - 数独
    Color(0xFFEF476F), // 红色 - 记忆翻牌
  ];

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          surface: backgroundColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        fontFamily: 'sans-serif',
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            color: textMedium,
          ),
        ),
      );
}
