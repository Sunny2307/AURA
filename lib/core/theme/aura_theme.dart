import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aura_colors.dart';
import 'aura_motion.dart';
import 'aura_spacing.dart';
import 'aura_typography.dart';

/// The single [ThemeData] for the app.
///
/// Cream canvas, violet actions and readable dark text on pastel surfaces.
///
/// Note there is no `cardTheme` here. Card styling lives in the `AuraCard`
/// widget instead — Material's card theming class has been renamed across
/// Flutter versions, and a widget we own is both more stable and more explicit
/// about the border + radius the spec asks for.
abstract final class AuraTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AuraColors.action,
      onPrimary: AuraColors.onAction,
      primaryContainer: AuraColors.lilac,
      onPrimaryContainer: AuraColors.textPrimary,
      secondary: AuraColors.action,
      onSecondary: AuraColors.onAction,
      secondaryContainer: AuraColors.lilac,
      onSecondaryContainer: AuraColors.textPrimary,
      error: AuraColors.negative,
      onError: Colors.white,
      errorContainer: AuraColors.peach,
      onErrorContainer: AuraColors.negative,
      surface: AuraColors.surface,
      onSurface: AuraColors.textPrimary,
      onSurfaceVariant: AuraColors.textMuted,
      outline: AuraColors.controlBorder,
      outlineVariant: AuraColors.surfaceBorder,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
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
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Spec 6.6: buttons are fully rounded pills.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AuraColors.action,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: AuraColors.surfaceRaised,
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
          foregroundColor: AuraColors.action,
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
          borderSide: BorderSide(color: AuraColors.action, width: 1.5),
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
        selectedColor: AuraColors.action,
        checkmarkColor: AuraColors.onAction,
        labelStyle: AuraType.bodyStrong,
        secondaryLabelStyle: AuraType.bodyStrong.copyWith(
          color: scheme.onPrimary,
        ),
        side: const BorderSide(color: AuraColors.controlBorder),
        shape: const RoundedRectangleBorder(borderRadius: AuraRadius.inputAll),
        padding: const EdgeInsets.all(8),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AuraColors.textPrimary),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AuraColors.lilac
                : AuraColors.surface,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AuraColors.controlBorder),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AuraColors.action,
        foregroundColor: AuraColors.onAction,
        elevation: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AuraColors.action,
        linearTrackColor: AuraColors.surface,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AuraColors.action,
        inactiveTrackColor: AuraColors.controlBorder,
        thumbColor: AuraColors.action,
        overlayColor: Color(0x225842B5),
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
