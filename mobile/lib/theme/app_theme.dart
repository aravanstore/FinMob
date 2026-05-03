import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Палитра взята из оригинальных исходников VS Code Default Light+
// https://github.com/microsoft/vscode/tree/main/extensions/theme-defaults/themes
//
// Ключевые цвета VS Code Light:
//   editor.background      #FFFFFF
//   editor.foreground      #000000
//   variable               #001080   (тёмно-синий)
//   keyword / storage      #0000FF   (синий)
//   activityBarBadge       #007ACC   (VS Blue — главный акцент)
//   string                 #A31515   (бордовый)
//   comment                #008000   (зелёный)
//   constant.numeric       #098658   (изумрудный)
//   list.hoverBackground   #E8E8E8
//   border / divider       #D4D4D4
//   input placeholder      #767676
//   sideBarTitle           #6F6F6F
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  // ── Светлая тема ────────────────────────────────────────────────────────────
  static ThemeData light() {
    // Главный акцент — «VS Blue» (#007ACC), тот самый цвет бейджа Activity Bar
    const vsBlue = Color(0xFF007ACC);

    const cs = ColorScheme(
      brightness: Brightness.light,
      // ── Primary ───────────────────────────────────────────────────────────
      primary:          vsBlue,
      onPrimary:        Colors.white,
      primaryContainer: Color(0xFFD6EEFF), // ADD6FF80 → непрозрачный
      onPrimaryContainer: Color(0xFF001E36),
      // ── Secondary ─────────────────────────────────────────────────────────
      secondary:        Color(0xFF0070C1), // constants & enums
      onSecondary:      Colors.white,
      secondaryContainer: Color(0xFFD6EEFF),
      onSecondaryContainer: Color(0xFF001E36),
      // ── Tertiary ──────────────────────────────────────────────────────────
      tertiary:         Color(0xFF098658), // числа / суммы
      onTertiary:       Colors.white,
      tertiaryContainer: Color(0xFFD4EDDF),
      onTertiaryContainer: Color(0xFF00291A),
      // ── Error ─────────────────────────────────────────────────────────────
      error:            Color(0xFFCD3131),
      onError:          Colors.white,
      errorContainer:   Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      // ── Surface ───────────────────────────────────────────────────────────
      surface:          Color(0xFFFFFFFF), // editor.background
      onSurface:        Color(0xFF000000), // editor.foreground
      surfaceContainerHighest: Color(0xFFF3F3F3), // suggestWidget bg
      surfaceContainerHigh:    Color(0xFFF3F3F3),
      surfaceContainer:        Color(0xFFF8F8F8), // unchangedRegion
      surfaceContainerLow:     Color(0xFFFFFFFF),
      surfaceContainerLowest:  Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFF6F6F6F), // sideBarTitle
      // ── Outline ───────────────────────────────────────────────────────────
      outline:          Color(0xFFD4D4D4), // widget.border / menu.border
      outlineVariant:   Color(0xFFCECECE), // input border
      // ── Misc ──────────────────────────────────────────────────────────────
      shadow:           Color(0xFF000000),
      scrim:            Color(0xFF000000),
      inverseSurface:   Color(0xFF313131),
      onInverseSurface: Color(0xFFF5F5F5),
      inversePrimary:   Color(0xFF90C2F9), // focusAndSelectionOutline
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      // ── Фон приложения ────────────────────────────────────────────────────
      scaffoldBackgroundColor: const Color(0xFFF3F3F3), // editorSuggestWidget bg
      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor:  Color(0xFFFFFFFF),
        foregroundColor:  Color(0xFF000000),
        shadowColor:      Color(0xFFD4D4D4),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFF000000),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Color(0xFF007ACC)),
      ),
      // ── Карточки ──────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color:       const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x28000000),
        elevation:   2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
      ),
      // ── Кнопки ────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vsBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCCCCCC),
          elevation: 1,
          shadowColor: const Color(0x40007ACC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: vsBlue,
          side: const BorderSide(color: Color(0xFF007ACC), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: vsBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      // ── Поля ввода ────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(color: Color(0xFF6F6F6F), fontSize: 13),
        hintStyle:  const TextStyle(color: Color(0xFF767676), fontSize: 13),
        helperStyle: const TextStyle(color: Color(0xFF6F6F6F), fontSize: 12),
        errorStyle:  const TextStyle(color: Color(0xFFCD3131), fontSize: 12),
        prefixIconColor: const Color(0xFF6F6F6F),
        suffixIconColor: const Color(0xFF6F6F6F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCECECE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCECECE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF007ACC), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCD3131)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCD3131), width: 2),
        ),
      ),
      // ── Диалоги ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor:  const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shadowColor:      const Color(0x40000000),
        elevation:        8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFD4D4D4)),
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFF000000),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF3C3C3C),
          fontSize: 14,
        ),
      ),
      // ── BottomSheet ───────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:  Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        elevation: 8,
      ),
      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor:     const Color(0xFFE8E8E8), // list.hoverBackground
        selectedColor:       const Color(0xFFD6EEFF),
        disabledColor:       const Color(0xFFEEEEEE),
        labelStyle:          const TextStyle(color: Color(0xFF3C3C3C), fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Color(0xFF007ACC), fontSize: 13),
        side:                const BorderSide(color: Color(0xFFD4D4D4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E5E5),
        thickness: 1,
        space: 1,
      ),
      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        tileColor:        Colors.transparent,
        selectedTileColor: Color(0xFFD6EEFF),
        iconColor:        Color(0xFF6F6F6F),
        textColor:        Color(0xFF000000),
        titleTextStyle: TextStyle(
          color: Color(0xFF000000),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: Color(0xFF6F6F6F),
          fontSize: 12,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
      // ── PopupMenu ─────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color:            const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shadowColor:      const Color(0x40000000),
        elevation:        4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFD4D4D4)),
        ),
        textStyle: const TextStyle(color: Color(0xFF3C3C3C), fontSize: 14),
      ),
      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF313131),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: const Color(0xFF90C2F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        behavior: SnackBarBehavior.floating,
      ),
      // ── NavigationBar ─────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:        const Color(0xFFFFFFFF),
        surfaceTintColor:       Colors.transparent,
        shadowColor:            const Color(0xFFD4D4D4),
        indicatorColor:         const Color(0xFFD6EEFF),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF007ACC), size: 24);
          }
          return const IconThemeData(color: Color(0xFF6F6F6F), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Color(0xFF007ACC),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: Color(0xFF6F6F6F), fontSize: 12);
        }),
      ),
      // ── TabBar ────────────────────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        labelColor:          Color(0xFF007ACC),
        unselectedLabelColor: Color(0xFF6F6F6F),
        indicatorColor:      Color(0xFF007ACC),
        indicatorSize:       TabBarIndicatorSize.label,
        dividerColor:        Color(0xFFE5E5E5),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      ),
      // ── FloatingActionButton ──────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF007ACC),
        foregroundColor: Colors.white,
        elevation:       4,
        focusElevation:  6,
        hoverElevation:  6,
        shape: CircleBorder(),
      ),
      // ── Switch / Checkbox / Radio ─────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const Color(0xFF007ACC);
          return const Color(0xFF919191);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const Color(0xFFD6EEFF);
          return const Color(0xFFE8E8E8);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const Color(0xFF007ACC);
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: Color(0xFF919191), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const Color(0xFF007ACC);
          return const Color(0xFF919191);
        }),
      ),
      // ── Текст ─────────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge:  TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w300),
        displayMedium: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w300),
        displaySmall:  TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w400),
        headlineLarge:  TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w600),
        headlineSmall:  TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w600),
        titleLarge:  TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w500, fontSize: 16),
        titleSmall:  TextStyle(color: Color(0xFF3C3C3C), fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge:   TextStyle(color: Color(0xFF000000), fontSize: 16),
        bodyMedium:  TextStyle(color: Color(0xFF3C3C3C), fontSize: 14),
        bodySmall:   TextStyle(color: Color(0xFF6F6F6F), fontSize: 12),
        labelLarge:  TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium: TextStyle(color: Color(0xFF3C3C3C), fontSize: 12),
        labelSmall:  TextStyle(color: Color(0xFF6F6F6F), fontSize: 11),
      ),
      // ── Icon ──────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: Color(0xFF6F6F6F), size: 22),
      primaryIconTheme: const IconThemeData(color: Color(0xFF007ACC), size: 22),
      // ── Прочее ────────────────────────────────────────────────────────────
      splashColor:    const Color(0x28007ACC),
      highlightColor: const Color(0x14007ACC),
      hoverColor:     const Color(0x0F007ACC),
      focusColor:     const Color(0x1F007ACC),
      disabledColor:  const Color(0xFFAAAAAA),
    );
  }

  // ── Тёмная тема (без изменений) ─────────────────────────────────────────────
  static ThemeData dark() {
    const seed = Color(0xFF1A56DB);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppPalette — удобный доступ к цветам из любого виджета через AppPalette.of(ctx)
// ─────────────────────────────────────────────────────────────────────────────
class AppPalette {
  final Color bg;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPri;
  final Color textSec;
  final Color textHint;
  final Color accent;
  final Color accentLt;
  final Color positive; // суммы, проценты, прибыль
  final Color negative; // долг, просрочка, ошибка

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPri,
    required this.textSec,
    required this.textHint,
    required this.accent,
    required this.accentLt,
    required this.positive,
    required this.negative,
  });

  static AppPalette of(BuildContext context) {
    final b = Theme.of(context).brightness;
    return b == Brightness.light ? light : dark;
  }

  // ── Светлая (VS Code Light+) ──────────────────────────────────────────────
  static const light = AppPalette(
    bg:       Color(0xFFF3F3F3), // editorSuggestWidget.background
    surface:  Color(0xFFFFFFFF), // editor.background
    card:     Color(0xFFFFFFFF),
    border:   Color(0xFFD4D4D4), // widget.border
    textPri:  Color(0xFF000000), // editor.foreground
    textSec:  Color(0xFF3C3C3C),
    textHint: Color(0xFF767676), // input.placeholderForeground
    accent:   Color(0xFF007ACC), // activityBarBadge.background ← VS Blue
    accentLt: Color(0xFF2196F3),
    positive: Color(0xFF098658), // constant.numeric — зелёный VS Code
    negative: Color(0xFFCD3131), // invalid foreground
  );

  // ── Тёмная ────────────────────────────────────────────────────────────────
  static const dark = AppPalette(
    bg:       Color(0xFF0F172A),
    surface:  Color(0xFF0F1829),
    card:     Color(0xFF1E293B),
    border:   Color(0xFF1E2D47),
    textPri:  Color(0xFFEFF6FF),
    textSec:  Color(0xFF94A3B8),
    textHint: Color(0xFF334155),
    accent:   Color(0xFF1A56DB),
    accentLt: Color(0xFF3B82F6),
    positive: Color(0xFF22C55E),
    negative: Color(0xFFEF4444),
  );
}
