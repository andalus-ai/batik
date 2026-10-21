import 'package:flutter/material.dart';

class BatikColors {
  BatikColors._();

  /// Dark earthy brown - leather look
  static const Color leather = Color(0xFF3E2723);
  
  /// Rich burnt orange/brown
  static const Color sienna = Color(0xFFA0522D);
  
  /// Golden ochre
  static const Color ochre = Color(0xFFCC7722);
  
  /// Light parchment/skin-like tone for backgrounds
  static const Color parchment = Color(0xFFF4EBD0);
  
  /// Puppet skin tone
  static const Color skin = Color(0xFFFFCCBC);
  
  /// Elegant gold for highlights
  static const Color gold = Color(0xFFD4AF37);

  /// Shadow black
  static const Color shadow = Color(0xFF1B1B1B);

  /// Accent brown
  static const Color wood = Color(0xFF5D4037);

  // Material3 colors for theming support
  static const Color primary = Color(0xFFA0522D);
  static const Color surface = Color(0xFFF4EBD0);
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color error = Color(0xFFB3261E);

  /// Gradients for a premium look
  static const Gradient wayangGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [leather, wood, sienna],
  );

  static const Gradient skinGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skin, parchment],
  );
}
