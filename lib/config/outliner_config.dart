import 'package:flutter/widgets.dart';
import 'block_style.dart';

/// Configuration for the outliner view behavior and appearance.
///
/// This class controls global outliner settings including keyboard shortcuts,
/// drag-and-drop behavior, and default styling.
///
/// Example:
/// ```dart
/// const config = OutlinerConfig(
///   keyboardShortcutsEnabled: false,
///   blockStyle: BlockStyle(indentWidth: 32.0),
/// );
/// ```
class OutlinerConfig {
  /// Whether keyboard shortcuts (Tab/Shift+Tab for indent/outdent) are enabled
  final bool keyboardShortcutsEnabled;

  /// Default styling for blocks
  final BlockStyle blockStyle;

  /// Padding around the outliner list
  final EdgeInsets padding;

  const OutlinerConfig({
    this.keyboardShortcutsEnabled = true,
    this.blockStyle = const BlockStyle(),
    this.padding = const EdgeInsets.all(16),
  });

  /// Creates a copy of this OutlinerConfig with the given fields replaced
  OutlinerConfig copyWith({
    bool? keyboardShortcutsEnabled,
    BlockStyle? blockStyle,
    EdgeInsets? padding,
  }) {
    return OutlinerConfig(
      keyboardShortcutsEnabled:
          keyboardShortcutsEnabled ?? this.keyboardShortcutsEnabled,
      blockStyle: blockStyle ?? this.blockStyle,
      padding: padding ?? this.padding,
    );
  }
}
