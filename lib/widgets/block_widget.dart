import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../config/block_style.dart';
import '../models/block.dart';
import '../models/outliner_state.dart';
import '../providers/outliner_provider.dart';

/// A widget that represents a single block in the outliner.
///
/// Supports inline editing, focus management, and customizable rendering
/// via builder callbacks.
///
/// Example with custom block rendering:
/// ```dart
/// BlockWidget(
///   block: myBlock,
///   blockBuilder: (context, block) {
///     return CustomRichTextWidget(content: block.content);
///   },
/// )
/// ```
class BlockWidget extends HookConsumerWidget {
  /// The block to display
  final Block block;

  /// Nesting depth (0 for root blocks)
  final int depth;

  /// Whether keyboard shortcuts (Tab/Shift+Tab, Enter) are enabled
  final bool keyboardShortcutsEnabled;

  /// Style configuration for the block
  final BlockStyle style;

  /// Custom builder for rendering block content when not editing.
  /// If null, displays plain text.
  final Widget Function(BuildContext context, Block block)? blockBuilder;

  /// Custom builder for rendering block content when editing.
  /// Parameters: context, block, controller, focusNode, onSubmitted callback.
  /// If null, uses default TextField with textFieldDecorationBuilder.
  ///
  /// Example:
  /// ```dart
  /// editingBlockBuilder: (context, block, controller, focusNode, onSubmitted) {
  ///   return MyCustomEditor(
  ///     controller: controller,
  ///     focusNode: focusNode,
  ///     onSubmitted: onSubmitted,
  ///   );
  /// }
  /// ```
  final Widget Function(
    BuildContext context,
    Block block,
    TextEditingController controller,
    FocusNode focusNode,
    VoidCallback onSubmitted,
  )?
  editingBlockBuilder;

  /// Custom builder for rendering the bullet/collapse indicator.
  /// Parameters: context, block, hasChildren, isCollapsed, onToggle callback.
  /// If null, uses default bullet rendering.
  final Widget Function(
    BuildContext context,
    Block block,
    bool hasChildren,
    bool isCollapsed,
    VoidCallback? onToggle,
  )?
  bulletBuilder;

  /// Custom builder for TextField decoration when editing.
  /// If null, uses minimal decoration.
  /// Ignored if editingBlockBuilder is provided.
  final InputDecoration Function(BuildContext context)?
  textFieldDecorationBuilder;

  /// Whether to apply automatic padding based on [depth].
  /// Set to false if the parent widget already adds indentation.
  final bool applyDepthPadding;

  /// Wrapper to make the bullet draggable.
  /// Parameters: context, child widget.
  /// If null, the bullet is not draggable.
  final Widget Function(BuildContext context, Widget child)? bulletDragWrapper;

  const BlockWidget({
    super.key,
    required this.block,
    this.depth = 0,
    this.keyboardShortcutsEnabled = true,
    this.style = const BlockStyle(),
    this.blockBuilder,
    this.editingBlockBuilder,
    this.bulletBuilder,
    this.textFieldDecorationBuilder,
    this.applyDepthPadding = true,
    this.bulletDragWrapper,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final isEditing = useState(false);
    final state = ref.watch(outlinerProvider);

    // Track desired cursor position
    final desiredCursorPosition = useRef<CursorPosition?>(null);
    final shouldApplyCursorOverride = useRef(false);

    useEffect(() {
      if (!isEditing.value && !focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.text != block.content) {
            final selection = _selectionForCursor(
              block.content.length,
              shouldApplyCursorOverride.value
                  ? desiredCursorPosition.value
                  : null,
              fallbackSelection: controller.selection,
            );

            controller.value = controller.value.copyWith(
              text: block.content,
              selection: selection,
            );
          }
        });
      }
      return null;
    }, [block.id, block.content]);

    // Update desired cursor position from state
    useEffect(() {
      final cursorPosition = state.whenOrNull(
        loaded: (_, __, cursorPosition, ___) => cursorPosition,
      );
      desiredCursorPosition.value = cursorPosition;
      return null;
    }, [state]);

    useEffect(() {
      void onFocusChange() {
        if (focusNode.hasFocus) {
          ref.read(outlinerProvider.notifier).setFocusedBlock(block.id);

          if (shouldApplyCursorOverride.value) {
            _applyCursorPosition(controller, desiredCursorPosition.value);
            shouldApplyCursorOverride.value = false;
          }
        } else if (!focusNode.hasFocus && isEditing.value) {
          _saveContent(ref, controller, isEditing);
        }
      }

      focusNode.addListener(onFocusChange);
      return () => focusNode.removeListener(onFocusChange);
    }, [focusNode]);

    useEffect(() {
      final focusedBlockId = state.whenOrNull(
        loaded: (_, focusedBlockId, __, ___) => focusedBlockId,
      );

      if (focusedBlockId == block.id && !focusNode.hasFocus) {
        isEditing.value = true;
        shouldApplyCursorOverride.value = true;

        _applyCursorPosition(controller, desiredCursorPosition.value);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusNode.requestFocus();
        });
      }
      return null;
    }, [state]);

    final indentWidth = applyDepthPadding ? depth * style.indentWidth : 0.0;

    return Padding(
      padding: EdgeInsets.only(left: indentWidth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBullet(context, ref),
          SizedBox(width: style.bulletSpacing),
          Expanded(
            child: _buildContent(
              context,
              ref,
              controller,
              focusNode,
              isEditing,
            ),
          ),
        ],
      ),
    );
  }

  void _applyCursorPosition(
    TextEditingController controller,
    CursorPosition? cursorPosition,
  ) {
    final selection = _selectionForCursor(
      controller.text.length,
      cursorPosition,
      fallbackSelection: controller.selection,
    );

    controller.value = controller.value.copyWith(selection: selection);
  }

  TextSelection _selectionForCursor(
    int textLength,
    CursorPosition? cursorPosition, {
    TextSelection? fallbackSelection,
  }) {
    if (cursorPosition != null) {
      final offset = cursorPosition == CursorPosition.start ? 0 : textLength;
      return TextSelection.collapsed(offset: offset);
    }

    final selection =
        fallbackSelection ?? const TextSelection.collapsed(offset: 0);
    final baseOffset = _clampOffset(selection.baseOffset, textLength);
    final extentOffset = _clampOffset(selection.extentOffset, textLength);

    return TextSelection(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  int _clampOffset(int offset, int maxLength) {
    if (offset.isNegative) {
      return 0;
    }
    if (offset > maxLength) {
      return maxLength;
    }
    return offset;
  }

  void _saveContent(
    WidgetRef ref,
    TextEditingController controller,
    ValueNotifier<bool> isEditing,
  ) {
    if (controller.text != block.content) {
      ref
          .read(outlinerProvider.notifier)
          .updateBlock(block.id, controller.text);
    }
    isEditing.value = false;
  }

  KeyEventResult _handleKeyEventWithPrevention(
    KeyEvent event,
    WidgetRef ref,
    TextEditingController controller,
    ValueNotifier<bool> isEditing,
  ) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        final cursorPosition = controller.selection.baseOffset;
        final notifier = ref.read(outlinerProvider.notifier);

        // Save current content before splitting
        if (controller.text != block.content) {
          notifier.updateBlock(block.id, controller.text).then((_) {
            notifier.splitBlock(block.id, cursorPosition);
          });
        } else {
          notifier.splitBlock(block.id, cursorPosition);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        final notifier = ref.read(outlinerProvider.notifier);
        if (HardwareKeyboard.instance.isShiftPressed) {
          notifier.outdentBlock(block.id);
        } else {
          notifier.indentBlock(block.id);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final shouldHandle = _handleArrowUpKey(ref, controller);
        return shouldHandle ? KeyEventResult.handled : KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final shouldHandle = _handleArrowDownKey(ref, controller);
        return shouldHandle ? KeyEventResult.handled : KeyEventResult.ignored;
      }
    }
    return KeyEventResult.ignored;
  }

  bool _handleArrowUpKey(WidgetRef ref, TextEditingController controller) {
    final cursorOffset = controller.selection.baseOffset;
    final text = controller.text;

    final isAtFirstLine =
        cursorOffset == 0 || !text.substring(0, cursorOffset).contains('\n');

    if (isAtFirstLine) {
      final notifier = ref.read(outlinerProvider.notifier);
      notifier.focusPreviousBlock(block.id);
      return true;
    }
    return false;
  }

  bool _handleArrowDownKey(WidgetRef ref, TextEditingController controller) {
    final cursorOffset = controller.selection.baseOffset;
    final text = controller.text;

    final isAtLastLine =
        cursorOffset == text.length ||
        !text.substring(cursorOffset).contains('\n');

    if (isAtLastLine) {
      final notifier = ref.read(outlinerProvider.notifier);
      notifier.focusNextBlock(block.id);
      return true;
    }
    return false;
  }

  Widget _buildBullet(BuildContext context, WidgetRef ref) {
    final onToggle = block.hasChildren
        ? () {
            ref.read(outlinerProvider.notifier).toggleBlockCollapse(block.id);
          }
        : null;

    Widget bullet;

    // Use custom builder if provided
    if (bulletBuilder != null) {
      bullet = bulletBuilder!(
        context,
        block,
        block.hasChildren,
        block.isCollapsed,
        onToggle,
      );
    } else {
      // Default bullet implementation
      bullet = GestureDetector(
        key: ValueKey('collapse-indicator-${block.id}'),
        onTap: onToggle,
        child: Container(
          width: style.collapseIconSize,
          height: style.collapseIconSize,
          margin: const EdgeInsets.only(top: 2),
          child: block.hasChildren
              ? _buildCollapseIcon()
              : _buildSimpleBullet(context),
        ),
      );
    }

    // Wrap with drag wrapper if provided
    if (bulletDragWrapper != null) {
      return bulletDragWrapper!(context, bullet);
    }

    return bullet;
  }

  Widget _buildCollapseIcon() {
    // Simple platform-agnostic collapse indicator using CustomPaint
    return CustomPaint(
      painter: _ArrowPainter(
        isCollapsed: block.isCollapsed,
        color: style.bulletColor ?? const Color(0xFF000000),
      ),
    );
  }

  Widget _buildSimpleBullet(BuildContext context) {
    return Center(
      child: Container(
        width: style.bulletSize,
        height: style.bulletSize,
        decoration: BoxDecoration(
          color: style.bulletColor ?? const Color.fromARGB(255, 115, 133, 149),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
    FocusNode focusNode,
    ValueNotifier<bool> isEditing,
  ) {
    return GestureDetector(
      onTap: () {
        isEditing.value = true;
        focusNode.requestFocus();
      },
      child: isEditing.value
          ? _buildEditingField(context, ref, controller, focusNode, isEditing)
          : _buildDisplayContent(context),
    );
  }

  Widget _buildEditingField(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
    FocusNode focusNode,
    ValueNotifier<bool> isEditing,
  ) {
    void onSubmitted() => _saveContent(ref, controller, isEditing);

    // Use custom editing builder if provided
    if (editingBlockBuilder != null) {
      final customWidget = editingBlockBuilder!(
        context,
        block,
        controller,
        focusNode,
        onSubmitted,
      );

      if (keyboardShortcutsEnabled) {
        return Focus(
          onKeyEvent: (node, event) =>
              _handleKeyEventWithPrevention(event, ref, controller, isEditing),
          child: customWidget,
        );
      }

      return customWidget;
    }

    // Default TextField implementation
    final textField = Padding(
      padding: style.contentPadding,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: false,
        maxLines: null,
        decoration:
            textFieldDecorationBuilder?.call(context) ??
            InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
        style: style.editingTextStyle,
        onSubmitted: (_) => onSubmitted(),
      ),
    );

    if (keyboardShortcutsEnabled) {
      return Focus(
        onKeyEvent: (node, event) =>
            _handleKeyEventWithPrevention(event, ref, controller, isEditing),
        child: textField,
      );
    }

    return textField;
  }

  Widget _buildDisplayContent(BuildContext context) {
    // Use custom builder if provided
    if (blockBuilder != null) {
      return Padding(
        padding: style.contentPadding,
        child: blockBuilder!(context, block),
      );
    }

    // Default text display
    return Padding(
      padding: style.contentPadding,
      child: Text(
        block.content.isEmpty ? style.emptyBlockText : block.content,
        style: block.content.isEmpty ? style.emptyTextStyle : style.textStyle,
      ),
    );
  }
}

/// Custom painter for drawing collapse/expand arrows without Material icons
class _ArrowPainter extends CustomPainter {
  final bool isCollapsed;
  final Color color;

  _ArrowPainter({required this.isCollapsed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);

    if (isCollapsed) {
      // Right-pointing arrow
      path.moveTo(center.dx - 3, center.dy - 4);
      path.lineTo(center.dx + 3, center.dy);
      path.lineTo(center.dx - 3, center.dy + 4);
    } else {
      // Down-pointing arrow
      path.moveTo(center.dx - 4, center.dy - 2);
      path.lineTo(center.dx + 4, center.dy - 2);
      path.lineTo(center.dx, center.dy + 3);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return oldDelegate.isCollapsed != isCollapsed || oldDelegate.color != color;
  }
}
