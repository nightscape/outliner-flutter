import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../config/block_style.dart';
import '../models/block.dart';
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final isEditing = useState(false);

    useEffect(() {
      if (!isEditing.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.text != block.content) {
            controller.text = block.content;
            controller.selection = TextSelection.collapsed(
              offset: block.content.length,
            );
          }
        });
      }
      return null;
    }, [block.id, block.content]);

    useEffect(() {
      void onFocusChange() {
        if (focusNode.hasFocus) {
          ref.read(outlinerProvider.notifier).setFocusedBlock(block.id);
        }
        if (!focusNode.hasFocus && isEditing.value) {
          _saveContent(ref, controller, isEditing);
        }
      }

      focusNode.addListener(onFocusChange);
      return () => focusNode.removeListener(onFocusChange);
    }, [focusNode]);

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

  void _handleKeyEvent(
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
        notifier.splitBlock(block.id, cursorPosition);
        isEditing.value = false;
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        final notifier = ref.read(outlinerProvider.notifier);
        if (HardwareKeyboard.instance.isShiftPressed) {
          notifier.outdentBlock(block.id);
        } else {
          notifier.indentBlock(block.id);
        }
      }
    }
  }

  Widget _buildBullet(BuildContext context, WidgetRef ref) {
    final onToggle = block.hasChildren
        ? () {
            ref.read(outlinerProvider.notifier).toggleBlockCollapse(block.id);
          }
        : null;

    // Use custom builder if provided
    if (bulletBuilder != null) {
      return bulletBuilder!(
        context,
        block,
        block.hasChildren,
        block.isCollapsed,
        onToggle,
      );
    }

    // Default bullet implementation
    return GestureDetector(
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
          color: style.bulletColor ?? const Color(0xFF2196F3),
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
        return KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) =>
              _handleKeyEvent(event, ref, controller, isEditing),
          child: customWidget,
        );
      }

      return customWidget;
    }

    // Default TextField implementation
    final textField = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      maxLines: null,
      decoration:
          textFieldDecorationBuilder?.call(context) ??
          InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: style.contentPadding,
          ),
      style: style.editingTextStyle,
      onSubmitted: (_) => onSubmitted(),
    );

    if (keyboardShortcutsEnabled) {
      return KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) =>
            _handleKeyEvent(event, ref, controller, isEditing),
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
