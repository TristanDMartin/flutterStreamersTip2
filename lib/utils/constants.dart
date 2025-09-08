import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF9248D2);
  static const Color secondary = Color(0xFF7768DF);
  static const Color tertiary = Color(0xFF1670DE);
  static const Color lightBlue = Color(0xFF3C8BD6);
  static const Color lightestBlue = Color(0xFF4897D2);
  
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Colors.grey;
}

class AppSizes {
  static const double padding = 16.0;
  static const double radius = 12.0;
  static const double iconSize = 24.0;
}

class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
}
