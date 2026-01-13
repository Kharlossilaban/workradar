import 'package:flutter/material.dart';

/// Accessibility utilities for WCAG 2.1 AA compliance
class AccessibilityUtils {
  // Minimum touch target size (48x48dp per WCAG guidelines)
  static const double minTouchTarget = 48.0;

  /// Wrap widget with minimum touch target size
  static Widget ensureMinTouchTarget(Widget child) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: minTouchTarget,
        minHeight: minTouchTarget,
      ),
      child: child,
    );
  }

  /// Create semantic label for task item
  static String taskSemanticLabel({
    required String title,
    required bool isCompleted,
    String? category,
    String? deadline,
    String? duration,
  }) {
    final parts = <String>[];
    parts.add(title);
    if (category != null) parts.add('Kategori: $category');
    if (deadline != null) parts.add('Tenggat: $deadline');
    if (duration != null) parts.add('Durasi: $duration');
    parts.add(isCompleted ? 'Sudah selesai' : 'Belum selesai');
    return parts.join('. ');
  }

  /// Create semantic label for button with action
  static String buttonSemanticLabel(String action, {String? context}) {
    if (context != null) {
      return '$action, $context';
    }
    return action;
  }

  /// Create semantic label for navigation item
  static String navItemSemanticLabel(String name, {bool isSelected = false}) {
    return isSelected ? '$name, dipilih' : name;
  }

  /// Create semantic label for chart
  static String chartSemanticLabel({
    required String chartType,
    required String title,
    String? description,
  }) {
    final parts = <String>['Grafik $chartType: $title'];
    if (description != null) parts.add(description);
    return parts.join('. ');
  }

  /// Check if color contrast meets WCAG AA requirements
  /// Requires 4.5:1 for normal text, 3:1 for large text
  static bool meetsContrastRequirement(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final contrast = _calculateContrastRatio(foreground, background);
    return isLargeText ? contrast >= 3.0 : contrast >= 4.5;
  }

  /// Calculate contrast ratio between two colors
  static double _calculateContrastRatio(Color color1, Color color2) {
    final l1 = _getRelativeLuminance(color1);
    final l2 = _getRelativeLuminance(color2);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Calculate relative luminance of a color
  static double _getRelativeLuminance(Color color) {
    final r = _linearize(color.r / 255);
    final g = _linearize(color.g / 255);
    final b = _linearize(color.b / 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize sRGB component
  static double _linearize(double value) {
    return value <= 0.03928
        ? value / 12.92
        : _power((value + 0.055) / 1.055, 2.4);
  }

  /// Helper for power calculation
  static double _power(double base, double exponent) {
    if (base <= 0) return 0;
    return base.toDouble() * base.toDouble() * (exponent > 2 ? base.toDouble() : 1);
  }
}

/// Accessible button with guaranteed minimum touch target
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;
  final String? hint;
  final bool excludeSemantics;

  const AccessibleButton({
    super.key,
    required this.child,
    this.onTap,
    required this.semanticLabel,
    this.hint,
    this.excludeSemantics = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      hint: hint,
      button: true,
      enabled: onTap != null,
      excludeSemantics: excludeSemantics,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AccessibilityUtils.minTouchTarget,
            minHeight: AccessibilityUtils.minTouchTarget,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Accessible icon button with minimum touch target
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color? color;
  final double size;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    required this.semanticLabel,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      child: IconButton(
        icon: Icon(icon, color: color, size: size),
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minWidth: AccessibilityUtils.minTouchTarget,
          minHeight: AccessibilityUtils.minTouchTarget,
        ),
      ),
    );
  }
}

/// Accessible checkbox with semantic labels
class AccessibleCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String label;
  final String? hint;

  const AccessibleCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    required this.label,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      checked: value,
      enabled: onChanged != null,
      child: SizedBox(
        width: AccessibilityUtils.minTouchTarget,
        height: AccessibilityUtils.minTouchTarget,
        child: Checkbox(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Wrapper widget for adding semantics to any widget
class SemanticWrapper extends StatelessWidget {
  final Widget child;
  final String label;
  final String? hint;
  final String? value;
  final bool? isButton;
  final bool? isHeader;
  final bool? isLink;
  final bool? isEnabled;
  final bool? isChecked;
  final bool? isSelected;
  final bool excludeSemantics;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SemanticWrapper({
    super.key,
    required this.child,
    required this.label,
    this.hint,
    this.value,
    this.isButton,
    this.isHeader,
    this.isLink,
    this.isEnabled,
    this.isChecked,
    this.isSelected,
    this.excludeSemantics = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton,
      header: isHeader,
      link: isLink,
      enabled: isEnabled,
      checked: isChecked,
      selected: isSelected,
      excludeSemantics: excludeSemantics,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}
