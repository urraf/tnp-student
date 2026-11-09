import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colours taken from the web portal (navy sidebar + coral→crimson CTA).
class AppColors {
  AppColors._();

  static const navy = Color(0xFF262B40);
  static const navyDeep = Color(0xFF161A2B);
  static const navyInk = Color(0xFF0E1120);
  static const coral = Color(0xFFFB7B4A);
  static const crimson = Color(0xFFEE3344);
  static const indigo = Color(0xFF5B5BD6);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);

  static const brandGradient = LinearGradient(
    colors: [coral, crimson],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF2B3050), navyDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Deterministic accent gradients for avatars / company initials.
  static const _avatarPairs = [
    [Color(0xFFFB7B4A), Color(0xFFEE3344)],
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFF0EA5E9), Color(0xFF2563EB)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFF59E0B), Color(0xFFEA580C)],
    [Color(0xFFEC4899), Color(0xFFDB2777)],
    [Color(0xFF14B8A6), Color(0xFF0D9488)],
    [Color(0xFF64748B), Color(0xFF334155)],
  ];

  static LinearGradient avatarGradient(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final pair = _avatarPairs[hash % _avatarPairs.length];
    return LinearGradient(colors: pair, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  /// Colour language for announcement tags & event types (from the web badges).
  static Color tagColor(String tag) {
    switch (tag.toLowerCase()) {
      case 'placement':
        return const Color(0xFF16A34A);
      case 'internship':
        return const Color(0xFF2563EB);
      case 'shortlist':
        return const Color(0xFFEA580C);
      case 'update':
        return const Color(0xFF7C3AED);
      case 'fte':
        return const Color(0xFF0369A1);
      case 'internship+fte':
        return const Color(0xFF0D9488);
      case 'internship+ppo':
        return const Color(0xFF6D28D9);
      case 'event':
      case 'companyevent':
        return const Color(0xFF0EA5E9);
      case 'general':
        return const Color(0xFFE44E72);
      default:
        return const Color(0xFF64748B);
    }
  }

  static IconData tagIcon(String tag) {
    switch (tag.toLowerCase()) {
      case 'placement':
        return Icons.work_rounded;
      case 'internship':
        return Icons.badge_rounded;
      case 'shortlist':
        return Icons.checklist_rounded;
      case 'update':
        return Icons.sync_rounded;
      case 'fte':
        return Icons.handshake_rounded;
      case 'internship+fte':
        return Icons.groups_rounded;
      case 'internship+ppo':
        return Icons.star_rounded;
      case 'event':
      case 'companyevent':
        return Icons.event_rounded;
      case 'general':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

/// Extra semantic colours that Material's ColorScheme doesn't cover.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.card,
    required this.border,
    required this.muted,
    required this.subtle,
    required this.shadow,
    required this.field,
  });

  final Color background;
  final Color card;
  final Color border;
  final Color muted;
  final Color subtle;
  final Color shadow;
  final Color field;

  static const light = AppPalette(
    background: Color(0xFFF5F6FA),
    card: Colors.white,
    border: Color(0xFFE6E8F0),
    muted: Color(0xFF6B7280),
    subtle: Color(0xFFF0F1F6),
    shadow: Color(0x14161A2B),
    field: Color(0xFFF3F4F8),
  );

  static const dark = AppPalette(
    background: Color(0xFF0D101C),
    card: Color(0xFF161A2A),
    border: Color(0xFF262B3F),
    muted: Color(0xFF9AA0B4),
    subtle: Color(0xFF1C2134),
    shadow: Color(0x66000000),
    field: Color(0xFF1C2134),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? card,
    Color? border,
    Color? muted,
    Color? subtle,
    Color? shadow,
    Color? field,
  }) => AppPalette(
    background: background ?? this.background,
    card: card ?? this.card,
    border: border ?? this.border,
    muted: muted ?? this.muted,
    subtle: subtle ?? this.subtle,
    shadow: shadow ?? this.shadow,
    field: field ?? this.field,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      field: Color.lerp(field, other.field, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;

    final scheme = ColorScheme.fromSeed(seedColor: AppColors.crimson, brightness: brightness).copyWith(
      primary: AppColors.crimson,
      onPrimary: Colors.white,
      secondary: AppColors.coral,
      onSecondary: Colors.white,
      tertiary: AppColors.indigo,
      surface: palette.card,
      onSurface: isDark ? const Color(0xFFECEEF5) : const Color(0xFF151827),
      error: AppColors.danger,
      outline: palette.border,
      outlineVariant: palette.border,
    );

    final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        disabledBorder: border(Colors.transparent),
        focusedBorder: border(AppColors.crimson, 1.6),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.6),
        labelStyle: TextStyle(color: palette.muted, fontWeight: FontWeight.w500),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          final color = states.contains(WidgetState.error)
              ? AppColors.danger
              : states.contains(WidgetState.focused)
              ? AppColors.crimson
              : palette.muted;
          return TextStyle(color: color, fontWeight: FontWeight.w600);
        }),
        hintStyle: TextStyle(color: palette.muted.withValues(alpha: 0.8)),
        prefixIconColor: palette.muted,
        suffixIconColor: palette.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: palette.border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.crimson,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: AppColors.crimson.withValues(alpha: isDark ? 0.25 : 0.1),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF252A40) : AppColors.navyDeep,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.crimson : null),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.crimson : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.crimson),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: palette.muted,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(12)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // iOS keeps its native Cupertino transition (the framework default).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}
