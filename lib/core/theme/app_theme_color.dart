import 'package:flutter/material.dart';

/// One of the 6 selectable brand-accent themes (Profile > App Theme),
/// added 2026-10-22. Independent of light/dark mode -- picking one of
/// these only changes [AppColors.accent] (buttons, selected states,
/// highlights, icons that use the brand color); card/field/background
/// colors stay exactly what the light/dark palette already defines.
/// `indigo` is the app's original color, kept as the default so
/// nothing changes for anyone who never opens the picker.
enum AppThemeColor {
  indigo('indigo', 'Indigo', Color(0xFF4F5AED)),
  teal('teal', 'Teal', Color(0xFF0D9488)),
  rose('rose', 'Rose', Color(0xFFE11D48)),
  amber('amber', 'Amber', Color(0xFFD97706)),
  violet('violet', 'Violet', Color(0xFF7C3AED)),
  emerald('emerald', 'Emerald', Color(0xFF059669));

  /// Stored in SharedPreferences -- stable even if display order/labels
  /// change later, unlike persisting the enum index.
  final String id;
  final String label;
  final Color color;

  const AppThemeColor(this.id, this.label, this.color);

  static AppThemeColor fromId(String? id) {
    return AppThemeColor.values.firstWhere(
      (t) => t.id == id,
      orElse: () => AppThemeColor.indigo,
    );
  }
}
