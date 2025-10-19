import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/block_style.dart';
import '../models/block.dart';
import '../models/drag_data.dart';
import '../providers/outliner_provider.dart';
import 'block_widget.dart';

/// A draggable wrapper around [BlockWidget] that enables drag-and-drop reordering.
///
/// Provides three drop zones: before, after, and as-child.
/// All [BlockWidget] customization parameters are passed through.
class DraggableBlockWidget extends ConsumerStatefulWidget {
  final Block block;
  final int depth;
  final bool keyboardShortcutsEnabled;
  final BlockStyle style;
  final Widget Function(BuildContext context, Block block)? blockBuilder;
  final Widget Function(
    BuildContext context,
    Block block,
    TextEditingController controller,
    FocusNode focusNode,
    VoidCallback onSubmitted,
  )?
  editingBlockBuilder;
  final Widget Function(
    BuildContext context,
    Block block,
    bool hasChildren,
    bool isCollapsed,
    VoidCallback? onToggle,
  )?
  bulletBuilder;
  final InputDecoration Function(BuildContext context)?
  textFieldDecorationBuilder;

  /// Custom builder for drag feedback widget.
  /// If null, a lightweight, platform-agnostic feedback widget is used.
  final Widget Function(BuildContext context, Block block)? dragFeedbackBuilder;

  /// Custom builder for drop zone indicators.
  /// Parameters: context, isHighlighted, indent.
  /// If null, uses a simple animated bar.
  final Widget Function(
    BuildContext context,
    bool isHighlighted,
    double indent,
  )?
  dropZoneBuilder;

  const DraggableBlockWidget({
    super.key,
    required this.block,
    this.depth = 0,
    this.keyboardShortcutsEnabled = true,
    this.style = const BlockStyle(),
    this.blockBuilder,
    this.editingBlockBuilder,
    this.bulletBuilder,
    this.textFieldDecorationBuilder,
    this.dragFeedbackBuilder,
    this.dropZoneBuilder,
  });

  @override
  ConsumerState<DraggableBlockWidget> createState() =>
      _DraggableBlockWidgetState();
}

const double _kDragHandleSize = 16.0;
const double _kDragHandleSpacing = 6.0;
const double _kChildDropZoneWidth = 96.0;
const Color _kDefaultDropZoneColor = Color(0xFF1B73E8);
const Color _kDefaultDropZoneHighlight = Color.fromARGB(120, 27, 115, 232);
const Color _kDefaultDragHandleColor = Color(0xFF8A8A8A);
const Color _kDefaultDragFeedbackBackground = Color(0xFFF5F5F5);
const Color _kDefaultDragFeedbackText = Color(0xFF303030);

class _DraggableBlockWidgetState extends ConsumerState<DraggableBlockWidget> {
  bool _isDraggingOverBefore = false;
  bool _isDraggingOverAfter = false;
  bool _isDraggingOverChild = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * widget.style.indentWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropZone(DropPosition.before, indent),
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: _buildRow(context),
        ),
        _buildDropZone(DropPosition.after, indent),
        if (!widget.block.isCollapsed)
          ...widget.block.children.map(
            (child) => DraggableBlockWidget(
              key: ValueKey(child.id),
              block: child,
              depth: widget.depth + 1,
              keyboardShortcutsEnabled: widget.keyboardShortcutsEnabled,
              style: widget.style,
              blockBuilder: widget.blockBuilder,
              editingBlockBuilder: widget.editingBlockBuilder,
              bulletBuilder: widget.bulletBuilder,
              textFieldDecorationBuilder: widget.textFieldDecorationBuilder,
              dragFeedbackBuilder: widget.dragFeedbackBuilder,
              dropZoneBuilder: widget.dropZoneBuilder,
            ),
          ),
      ],
    );
  }

  Widget _buildRow(BuildContext context) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(context),
            SizedBox(width: _kDragHandleSpacing),
            Expanded(child: _buildDraggableBlock(context)),
          ],
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _kChildDropZoneWidth,
          child: IgnorePointer(
            ignoring: false,
            child: _buildDropZoneOnBlock(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    final dragData = DragData(
      block: widget.block,
      sourceParentId: '',
      sourceIndex: 0,
    );

    return Draggable<DragData>(
      data: dragData,
      feedback: _buildDragFeedback(context),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _DragHandle(color: _resolveDragHandleColor()),
      ),
      child: _DragHandle(color: _resolveDragHandleColor()),
    );
  }

  Widget _buildDraggableBlock(BuildContext context) {
    final dragData = DragData(
      block: widget.block,
      sourceParentId: '',
      sourceIndex: 0,
    );

    return LongPressDraggable<DragData>(
      data: dragData,
      feedback: _buildDragFeedback(context),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildBlockWidget()),
      child: _buildBlockWidget(),
    );
  }

  Widget _buildBlockWidget() {
    return BlockWidget(
      key: ValueKey(widget.block.id),
      block: widget.block,
      depth: widget.depth,
      keyboardShortcutsEnabled: widget.keyboardShortcutsEnabled,
      style: widget.style,
      blockBuilder: widget.blockBuilder,
      editingBlockBuilder: widget.editingBlockBuilder,
      bulletBuilder: widget.bulletBuilder,
      textFieldDecorationBuilder: widget.textFieldDecorationBuilder,
      applyDepthPadding: false,
    );
  }

  Widget _buildDragFeedback(BuildContext context) {
    if (widget.dragFeedbackBuilder != null) {
      return widget.dragFeedbackBuilder!(context, widget.block);
    }

    final textStyle = widget.style.textStyle.merge(
      const TextStyle(color: _kDefaultDragFeedbackText),
    );

    final content = widget.block.content.isEmpty
        ? widget.style.emptyBlockText
        : widget.block.content;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kDefaultDragFeedbackBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _kDefaultDragHandleColor.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone(DropPosition position, double indent) {
    final isBefore = position == DropPosition.before;
    final isHighlighted = isBefore
        ? _isDraggingOverBefore
        : _isDraggingOverAfter;

    return DragTarget<DragData>(
      onWillAcceptWithDetails: (details) =>
          details.data.block.id != widget.block.id,
      onAcceptWithDetails: (details) {
        _handleDrop(details.data, position);
        setState(() {
          _isDraggingOverBefore = false;
          _isDraggingOverAfter = false;
        });
      },
      onMove: (details) {
        setState(() {
          if (isBefore) {
            _isDraggingOverBefore = true;
          } else {
            _isDraggingOverAfter = true;
          }
        });
      },
      onLeave: (data) {
        setState(() {
          if (isBefore) {
            _isDraggingOverBefore = false;
          } else {
            _isDraggingOverAfter = false;
          }
        });
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = isHighlighted && candidateData.isNotEmpty;
        final indicator =
            widget.dropZoneBuilder?.call(context, highlighted, indent) ??
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: highlighted ? 4 : 2,
              decoration: BoxDecoration(
                color: highlighted
                    ? _resolveDropZoneColor()
                    : const Color(0x00000000),
                borderRadius: BorderRadius.circular(2),
              ),
            );

        return Padding(
          padding: EdgeInsets.only(left: indent),
          child: indicator,
        );
      },
    );
  }

  Widget _buildDropZoneOnBlock(BuildContext context) {
    return DragTarget<DragData>(
      onWillAcceptWithDetails: (details) {
        return details.data.block.id != widget.block.id &&
            !_isDescendantOf(details.data.block, widget.block);
      },
      onAcceptWithDetails: (details) {
        _handleDrop(details.data, DropPosition.asChild);
        setState(() {
          _isDraggingOverChild = false;
        });
      },
      onMove: (details) {
        setState(() {
          _isDraggingOverChild = true;
        });
      },
      onLeave: (data) {
        setState(() {
          _isDraggingOverChild = false;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = _isDraggingOverChild && candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: highlighted
                ? _kDefaultDropZoneHighlight
                : const Color(0x00000000),
            border: highlighted
                ? Border.all(color: _resolveDropZoneColor(), width: 2)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }

  bool _isDescendantOf(Block potential, Block ancestor) {
    if (potential.id == ancestor.id) return true;
    for (var child in ancestor.children) {
      if (_isDescendantOf(potential, child)) return true;
    }
    return false;
  }

  Future<void> _handleDrop(DragData dragData, DropPosition position) async {
    final notifier = ref.read(outlinerProvider.notifier);
    final currentParentId = await notifier.findParentId(widget.block.id);
    final currentIndex = await notifier.findBlockIndex(widget.block.id);

    String? newParentId;
    int newIndex;

    switch (position) {
      case DropPosition.before:
        newParentId = currentParentId;
        newIndex = currentIndex;
        break;
      case DropPosition.after:
        newParentId = currentParentId;
        newIndex = currentIndex + 1;
        break;
      case DropPosition.asChild:
        newParentId = widget.block.id;
        newIndex = widget.block.children.length;
        break;
    }

    await notifier.moveBlock(dragData.block.id, newParentId, newIndex);
  }

  Color _resolveDropZoneColor() {
    return widget.style.bulletColor ?? _kDefaultDropZoneColor;
  }

  Color _resolveDragHandleColor() {
    return widget.style.bulletColor ?? _kDefaultDragHandleColor;
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kDragHandleSize + _kDragHandleSpacing,
      child: Center(
        child: CustomPaint(
          size: const Size(_kDragHandleSize, _kDragHandleSize),
          painter: _DragHandlePainter(color),
        ),
      ),
    );
  }
}

class _DragHandlePainter extends CustomPainter {
  _DragHandlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const lineHeight = 2.0;
    const lineSpacing = 4.0;

    for (var i = 0; i < 3; i++) {
      final dy = i * (lineHeight + lineSpacing);
      final rect = Rect.fromLTWH(0, dy, size.width, lineHeight);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(1.5));
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(_DragHandlePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
