import 'package:flutter/widgets.dart';

/// Configuration for block visual styling.
///
/// This class allows customization of how blocks are rendered,
/// including text styles, spacing, colors, and bullet appearance.
///
/// Example:
/// ```dart
/// const customStyle = BlockStyle(
///   textStyle: TextStyle(fontSize: 18, color: Color(0xFF000000)),
///   indentWidth: 32.0,
///   bulletSize: 8.0,
/// );
/// ```
class BlockStyle {
  /// Text style for block content when not editing
  final TextStyle textStyle;

  /// Text style for empty blocks (placeholder text)
  final TextStyle emptyTextStyle;

  /// Text style for the TextField when editing
  final TextStyle editingTextStyle;

  /// Width of indentation per depth level
  final double indentWidth;

  /// Spacing between bullet and content
  final double bulletSpacing;

  /// Size of the bullet point (for blocks without children)
  final double bulletSize;

  /// Color of the bullet point
  final Color? bulletColor;

  /// Size of the collapse/expand icon (for blocks with children)
  final double collapseIconSize;

  /// Vertical padding for block content
  final EdgeInsets contentPadding;

  /// Placeholder text for empty blocks
  final String emptyBlockText;

  const BlockStyle({
    this.textStyle = const TextStyle(fontSize: 16),
    this.emptyTextStyle = const TextStyle(
      fontSize: 16,
      color: Color(0xFF9E9E9E),
    ),
    this.editingTextStyle = const TextStyle(fontSize: 16),
    this.indentWidth = 24.0,
    this.bulletSpacing = 8.0,
    this.bulletSize = 6.0,
    this.bulletColor,
    this.collapseIconSize = 20.0,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 2),
    this.emptyBlockText = 'Empty block',
  });

  /// Creates a copy of this BlockStyle with the given fields replaced
  BlockStyle copyWith({
    TextStyle? textStyle,
    TextStyle? emptyTextStyle,
    TextStyle? editingTextStyle,
    double? indentWidth,
    double? bulletSpacing,
    double? bulletSize,
    Color? bulletColor,
    double? collapseIconSize,
    EdgeInsets? contentPadding,
    String? emptyBlockText,
  }) {
    return BlockStyle(
      textStyle: textStyle ?? this.textStyle,
      emptyTextStyle: emptyTextStyle ?? this.emptyTextStyle,
      editingTextStyle: editingTextStyle ?? this.editingTextStyle,
      indentWidth: indentWidth ?? this.indentWidth,
      bulletSpacing: bulletSpacing ?? this.bulletSpacing,
      bulletSize: bulletSize ?? this.bulletSize,
      bulletColor: bulletColor ?? this.bulletColor,
      collapseIconSize: collapseIconSize ?? this.collapseIconSize,
      contentPadding: contentPadding ?? this.contentPadding,
      emptyBlockText: emptyBlockText ?? this.emptyBlockText,
    );
  }
}
