/// Spacing & radius tokens from DESIGN.md.
class AppRadius {
  AppRadius._();

  static const double sm      = 4;    // 0.25rem
  static const double base    = 8;    // 0.5rem
  static const double md      = 12;   // 0.75rem
  static const double lg      = 16;   // 1rem
  static const double xl      = 24;   // 1.5rem
  static const double pill    = 9999;

  // Semantic — from DESIGN.md component spec
  static const double card       = 32;
  static const double summary    = 28; // Dashboard bento summary card (DESIGN.md)
  static const double input      = 20;
  static const double button     = pill;
  static const double sheet      = 32;
  static const double bottomNav  = 28;
  static const double fab        = pill;
}

class AppSpacing {
  AppSpacing._();

  static const double base = 4;
  static const double xs   = 4;
  static const double sm   = 8;     // stack-sm
  static const double md   = 16;    // gutter
  static const double lg   = 20;    // container-padding
  static const double xl   = 24;    // stack-lg
}
