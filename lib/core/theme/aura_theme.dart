import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aura_colors.dart';
import 'aura_motion.dart';
import 'aura_spacing.dart';
import 'aura_typography.dart';

/// The single [ThemeData] for the app.
///
/// Aura is **dark only**. There is no light theme and there should not be one:
/// the entire visual identity in spec section 6.1 is a glowing orb on near-black,
/// and that effect does not exist on a white background. `themeMode` is pinned to
/// dark in `AuraApp` so the OS setting cannot override it.
///
/// Note there is no `cardTheme` here. Card styling lives in the `AuraCard`
/// widget instead — Material's card theming class has been renamed across
/// Flutter versions, and a widget we own is both more stable and more explicit
/// about the border + radius the spec asks for.
abstract final class AuraTheme {
  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AuraColors.positive,
      onPrimary: Color(0xFF00150E),
      secondary: AuraColors.gold,
      onSecondary: Color(0xFF221A00),
      error: AuraColors.negative,
      onError: Color(0xFF2B0A05),
      surface: AuraColors.surface,
      onSurface: AuraColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AuraColors.background,
      canvasColor: AuraColors.background,
      fontFamily: AuraType.family,
      textTheme: AuraType.textTheme,

      // Visible touch feedback also preserves keyboard focus on Material controls.
      splashFactory: InkRipple.splashFactory,
      highlightColor: AuraColors.positive.withValues(alpha: 0.06),

      appBarTheme: AppBarTheme(
        backgroundColor: AuraColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AuraType.headingMedium,
        iconTheme: const IconThemeData(color: AuraColors.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Spec 6.6: buttons are fully rounded pills.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AuraColors.positive,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: AuraColors.neutral,
          disabledForegroundColor: AuraColors.textMuted,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AuraRadius.pillAll),
          textStyle: AuraType.label,
          animationDuration: AuraMotion.press,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AuraColors.textPrimary,
          minimumSize: const Size(0, AuraTouch.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xl),
          side: const BorderSide(color: AuraColors.controlBorder),
          shape: const RoundedRectangleBorder(borderRadius: AuraRadius.pillAll),
          textStyle: AuraType.label,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AuraColors.positive,
          minimumSize: const Size(0, AuraTouch.minTarget),
          textStyle: AuraType.label,
        ),
      ),

      // Spec 6.6: inputs 12–14px radius, subtle inner shadow, teal focus ring.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuraColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AuraSpacing.lg,
          vertical: AuraSpacing.lg,
        ),
        hintStyle: AuraType.body.copyWith(color: AuraColors.textMuted),
        border: const OutlineInputBorder(
          borderRadius: AuraRadius.inputAll,
          borderSide: BorderSide(color: AuraColors.controlBorder),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AuraRadius.inputAll,
          borderSide: BorderSide(color: AuraColors.controlBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AuraRadius.inputAll,
          borderSide: BorderSide(color: AuraColors.positive, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AuraRadius.inputAll,
          borderSide: BorderSide(color: AuraColors.negative),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AuraRadius.inputAll,
          borderSide: BorderSide(color: AuraColors.negative, width: 1.5),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AuraColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AuraColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AuraRadius.sheetTop),
        showDragHandle: true,
        dragHandleColor: AuraColors.neutral,
      ),

      dividerTheme: const DividerThemeData(
        color: AuraColors.surfaceBorder,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AuraColors.surface,
        contentTextStyle: AuraType.body,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AuraRadius.cardAll),
      ),

      iconTheme: const IconThemeData(color: AuraColors.textPrimary, size: 22),
      listTileTheme: const ListTileThemeData(
        iconColor: AuraColors.textMuted,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AuraColors.surface,
        selectedColor: AuraColors.positive,
        labelStyle: AuraType.bodyStrong,
        secondaryLabelStyle: AuraType.bodyStrong.copyWith(
          color: scheme.onPrimary,
        ),
        side: const BorderSide(color: AuraColors.controlBorder),
        shape: const RoundedRectangleBorder(borderRadius: AuraRadius.inputAll),
        padding: const EdgeInsets.all(8),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AuraColors.positive,
        foregroundColor: Color(0xFF00150E),
        elevation: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AuraColors.positive,
        linearTrackColor: AuraColors.surface,
      ),

      // Keep each platform's back gesture and transition behavior.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
