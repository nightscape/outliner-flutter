import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../config/block_style.dart';
import '../core/block_ops.dart';
import '../models/outliner_state.dart';
import '../providers/outliner_provider.dart';

/// A widget that represents a single block in the outliner.
///
/// Supports inline editing, focus management, and customizable rendering
/// via builder callbacks. Generic type [T] allows using any block type.
///
/// Example with custom block rendering:
/// ```dart
/// BlockWidget<rust.Block>(
///   block: myBlock,
///   ops: rustBlockOps,
///   notifierProvider: myNotifierProvider,
///   blockBuilder: (context, block) {
///     return CustomRichTextWidget(content: ops.getContent(block));
///   },
/// )
/// ```
class BlockWidget<T> extends HookConsumerWidget {
  /// The block to display
  final T block;

  /// Operations for accessing block fields
  final BlockOps<T> ops;

  /// Provider for the outliner notifier (used for state-changing operations)
  final StateNotifierProvider<OutlinerNotifier<T>, OutlinerState<T>>? notifierProvider;

  /// Nesting depth (0 for root blocks)
  final int depth;

  /// Whether keyboard shortcuts (Tab/Shift+Tab, Enter) are enabled
  final bool keyboardShortcutsEnabled;

  /// Style configuration for the block
  final BlockStyle style;

  /// Custom builder for rendering block content when not editing.
  /// If null, displays plain text.
  final Widget Function(BuildContext context, T block)? blockBuilder;

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
    T block,
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
    T block,
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
    required this.ops,
    this.notifierProvider,
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
    final provider = notifierProvider ?? outlinerProvider;
    final state = ref.watch(provider);

    // Track desired cursor position
    final desiredCursorPosition = useRef<CursorPosition?>(null);
    final shouldApplyCursorOverride = useRef(false);

    final blockId = ops.getId(block);
    final blockContent = ops.getContent(block);

    useEffect(() {
      if (!isEditing.value && !focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.text != blockContent) {
            final selection = _selectionForCursor(
              blockContent.length,
              shouldApplyCursorOverride.value
                  ? desiredCursorPosition.value
                  : null,
              fallbackSelection: controller.selection,
            );

            controller.value = controller.value.copyWith(
              text: blockContent,
              selection: selection,
            );
          }
        });
      }
      return null;
    }, [blockId, blockContent]);

    // Update desired cursor position from state
    useEffect(() {
      final cursorPosition = state.cursorPosition;
      desiredCursorPosition.value = cursorPosition;
      return null;
    }, [state]);

    useEffect(() {
      void onFocusChange() {
        if (focusNode.hasFocus) {
          final provider = notifierProvider ?? outlinerProvider;
          ref.read(provider.notifier).setFocusedBlock(blockId);

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
      final focusedBlockId = state.focusedBlockId;

      if (focusedBlockId == blockId && !focusNode.hasFocus) {
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
    final blockContent = ops.getContent(block);
    if (controller.text != blockContent) {
      ops.updateBlock(block, controller.text);
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
        final blockContent = ops.getContent(block);
        final provider = notifierProvider ?? outlinerProvider;
        final notifier = ref.read(provider.notifier);

        if (controller.text != blockContent) {
          notifier.updateBlock(block, controller.text).then((_) {
            notifier.splitBlock(block, cursorPosition);
          });
        } else {
          notifier.splitBlock(block, cursorPosition);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        final provider = notifierProvider ?? outlinerProvider;
        final notifier = ref.read(provider.notifier);
        if (HardwareKeyboard.instance.isShiftPressed) {
          notifier.outdentBlock(block);
        } else {
          notifier.indentBlock(block);
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
      final blockId = ops.getId(block);
      final provider = notifierProvider ?? outlinerProvider;
      final notifier = ref.read(provider.notifier);
      notifier.focusPreviousBlock(blockId);
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
      final blockId = ops.getId(block);
      final provider = notifierProvider ?? outlinerProvider;
      final notifier = ref.read(provider.notifier);
      notifier.focusNextBlock(blockId);
      return true;
    }
    return false;
  }

  Widget _buildBullet(BuildContext context, WidgetRef ref) {
    final hasChildren = ops.getChildren(block).isNotEmpty;
    final onToggle = hasChildren
        ? () {
            final provider = notifierProvider ?? outlinerProvider;
            final notifier = ref.read(provider.notifier);
            notifier.toggleBlockCollapse(block);
          }
        : null;

    Widget bullet;

    final isCollapsed = ops.getIsCollapsed(block);

    // Use custom builder if provided
    if (bulletBuilder != null) {
      bullet = bulletBuilder!(
        context,
        block,
        hasChildren,
        isCollapsed,
        onToggle,
      );
    } else {
      // Default bullet implementation
      bullet = GestureDetector(
        key: ValueKey('collapse-indicator-${ops.getId(block)}'),
        onTap: onToggle,
        child: Container(
          width: style.collapseIconSize,
          height: style.collapseIconSize,
          margin: const EdgeInsets.only(top: 2),
          child: hasChildren
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
    final isCollapsed = ops.getIsCollapsed(block);
    // Simple platform-agnostic collapse indicator using CustomPaint
    return CustomPaint(
      painter: _ArrowPainter(
        isCollapsed: isCollapsed,
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
      child: Actions(
        actions: {
          // Disable focus traversal for Tab key
          NextFocusIntent: DoNothingAction(consumesKey: false),
          PreviousFocusIntent: DoNothingAction(consumesKey: false),
        },
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
    final content = ops.getContent(block);

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
        content.isEmpty ? style.emptyBlockText : content,
        style: content.isEmpty ? style.emptyTextStyle : style.textStyle,
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
