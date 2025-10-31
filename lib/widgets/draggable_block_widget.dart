import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../config/block_style.dart';
import '../core/block_ops.dart';
import '../models/drag_data.dart';
import '../models/outliner_state.dart';
import '../providers/outliner_provider.dart';
import 'block_widget.dart';

/// A draggable wrapper around [BlockWidget] that enables drag-and-drop reordering.
///
/// Provides three drop zones: before, after, and as-child.
/// All [BlockWidget] customization parameters are passed through.
/// Generic type [T] allows using any block type.
class DraggableBlockWidget<T> extends ConsumerStatefulWidget {
  final T block;
  final BlockOps<T> ops;
  final StateNotifierProvider<OutlinerNotifier<T>, OutlinerState<T>>? notifierProvider;
  final int depth;
  final bool keyboardShortcutsEnabled;
  final BlockStyle style;
  final bool isLastSibling;
  final Widget Function(BuildContext context, T block)? blockBuilder;
  final Widget Function(
    BuildContext context,
    T block,
    TextEditingController controller,
    FocusNode focusNode,
    VoidCallback onSubmitted,
  )?
  editingBlockBuilder;
  final Widget Function(
    BuildContext context,
    T block,
    bool hasChildren,
    bool isCollapsed,
    VoidCallback? onToggle,
  )?
  bulletBuilder;
  final InputDecoration Function(BuildContext context)?
  textFieldDecorationBuilder;

  /// Custom builder for drag feedback widget.
  /// If null, a lightweight, platform-agnostic feedback widget is used.
  final Widget Function(BuildContext context, T block)? dragFeedbackBuilder;

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
    required this.ops,
    this.notifierProvider,
    this.depth = 0,
    this.keyboardShortcutsEnabled = true,
    this.style = const BlockStyle(),
    this.isLastSibling = false,
    this.blockBuilder,
    this.editingBlockBuilder,
    this.bulletBuilder,
    this.textFieldDecorationBuilder,
    this.dragFeedbackBuilder,
    this.dropZoneBuilder,
  });

  @override
  ConsumerState<DraggableBlockWidget<T>> createState() =>
      _DraggableBlockWidgetState<T>();
}

const double _kChildDropZoneWidth = 96.0;
const Color _kDefaultDropZoneHighlight = Color.fromARGB(120, 27, 115, 232);
const double _kDropZoneHitHeight = 16.0;

class _DraggableBlockWidgetState<T> extends ConsumerState<DraggableBlockWidget<T>> {
  bool _isDraggingOverBefore = false;
  bool _isDraggingOverAfter = false;
  bool _isDraggingOverChild = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * widget.style.indentWidth;
    final children = widget.ops.getChildren(widget.block);
    final hasChildren = children.isNotEmpty;
    final isCollapsed = widget.ops.getIsCollapsed(widget.block);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropZone(DropPosition.before, indent),
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: _buildRow(context, showAsChildZone: !hasChildren),
        ),
        if (!isCollapsed)
          ...children.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final child = entry.value;
              final isLastChild = index == children.length - 1;

              return DraggableBlockWidget<T>(
                key: ValueKey(widget.ops.getId(child)),
                block: child,
                ops: widget.ops,
                notifierProvider: widget.notifierProvider,
                depth: widget.depth + 1,
                keyboardShortcutsEnabled: widget.keyboardShortcutsEnabled,
                style: widget.style,
                isLastSibling: isLastChild,
                blockBuilder: widget.blockBuilder,
                editingBlockBuilder: widget.editingBlockBuilder,
                bulletBuilder: widget.bulletBuilder,
                textFieldDecorationBuilder: widget.textFieldDecorationBuilder,
                dragFeedbackBuilder: widget.dragFeedbackBuilder,
                dropZoneBuilder: widget.dropZoneBuilder,
              );
            },
          ),
        if (widget.isLastSibling)
          _buildDropZone(DropPosition.after, indent),
      ],
    );
  }

  Widget _buildRow(BuildContext context, {required bool showAsChildZone}) {
    return Stack(
      children: [
        _buildDraggableBlock(context),
        if (showAsChildZone)
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

  Widget _buildDraggableBlock(BuildContext context) {
    final dragData = DragData<T>(
      block: widget.block,
      blockId: widget.ops.getId(widget.block),
    );

    return LongPressDraggable<DragData<T>>(
      data: dragData,
      feedback: _buildDragFeedback(context),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildBlockWidget()),
      child: _buildBlockWidget(),
    );
  }

  Widget _buildBlockWidget() {
    return BlockWidget<T>(
      key: ValueKey(widget.ops.getId(widget.block)),
      block: widget.block,
      ops: widget.ops,
      notifierProvider: widget.notifierProvider,
      depth: widget.depth,
      keyboardShortcutsEnabled: widget.keyboardShortcutsEnabled,
      style: widget.style,
      blockBuilder: widget.blockBuilder,
      editingBlockBuilder: widget.editingBlockBuilder,
      bulletBuilder: widget.bulletBuilder,
      textFieldDecorationBuilder: widget.textFieldDecorationBuilder,
      applyDepthPadding: false,
      bulletDragWrapper: _buildBulletDragWrapper,
    );
  }

  Widget _buildBulletDragWrapper(BuildContext context, Widget child) {
    final dragData = DragData<T>(
      block: widget.block,
      blockId: widget.ops.getId(widget.block),
    );

    return Draggable<DragData<T>>(
      data: dragData,
      feedback: _buildDragFeedback(context),
      childWhenDragging: Opacity(opacity: 0.3, child: child),
      child: child,
    );
  }

  Widget _buildDragFeedback(BuildContext context) {
    if (widget.dragFeedbackBuilder != null) {
      return widget.dragFeedbackBuilder!(context, widget.block);
    }

    final children = widget.ops.getChildren(widget.block).take(5).toList();

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: 0.7,
                child: BlockWidget<T>(
                  block: widget.block,
                  ops: widget.ops,
                  notifierProvider: widget.notifierProvider,
                  depth: widget.depth,
                  keyboardShortcutsEnabled: false,
                  style: widget.style,
                  blockBuilder: widget.blockBuilder,
                  editingBlockBuilder: widget.editingBlockBuilder,
                  bulletBuilder: widget.bulletBuilder,
                  textFieldDecorationBuilder: widget.textFieldDecorationBuilder,
                  applyDepthPadding: true,
                ),
              ),
              ...children.asMap().entries.map((entry) {
                final index = entry.key;
                final child = entry.value;
                final scale = 0.8;
                final opacity = (0.7 - (index + 1) * 0.1).clamp(0.0, 1.0);

                return Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: Opacity(
                    opacity: opacity,
                    child: BlockWidget<T>(
                      block: child,
                      ops: widget.ops,
                      notifierProvider: widget.notifierProvider,
                      depth: widget.depth + 1,
                      keyboardShortcutsEnabled: false,
                      style: widget.style,
                      blockBuilder: widget.blockBuilder,
                      editingBlockBuilder: widget.editingBlockBuilder,
                      bulletBuilder: widget.bulletBuilder,
                      textFieldDecorationBuilder:
                          widget.textFieldDecorationBuilder,
                      applyDepthPadding: true,
                    ),
                  ),
                );
              }),
            ],
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

    return DragTarget<DragData<T>>(
      onWillAcceptWithDetails: (details) {
        // Check if source and target are different
        return details.data.blockId != widget.ops.getId(widget.block);
      },
      onAcceptWithDetails: (details) {
        _handleDrop(details.data, position);
        setState(() {
          _isDraggingOverBefore = false;
          _isDraggingOverAfter = false;
        });
      },
      onMove: (details) {
        // Only highlight if this would be a valid drop
        if (details.data.blockId == widget.ops.getId(widget.block)) return;

        // Check for circular reference: prevent making a block its own ancestor
        if (widget.ops.isDescendantOf(widget.block, details.data.block)) return;

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
              width: double.infinity,
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
          child: SizedBox(
            height: _kDropZoneHitHeight,
            child: Align(
              alignment:
                  isBefore ? Alignment.topLeft : Alignment.bottomLeft,
              child: indicator,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropZoneOnBlock(BuildContext context) {
    return DragTarget<DragData<T>>(
      onWillAcceptWithDetails: (details) {
        if (details.data.blockId == widget.ops.getId(widget.block)) return false;
        return !widget.ops.isDescendantOf(widget.block, details.data.block);
      },
      onAcceptWithDetails: (details) {
        _handleDrop(details.data, DropPosition.asChild);
        setState(() {
          _isDraggingOverChild = false;
        });
      },
      onMove: (details) {
        // Only highlight if this would be a valid drop
        if (details.data.blockId == widget.ops.getId(widget.block)) return;
        if (widget.ops.isDescendantOf(widget.block, details.data.block)) return;

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

  Future<void> _handleDrop(DragData<T> dragData, DropPosition position) async {
    final targetBlock = widget.block;
    final targetId = widget.ops.getId(targetBlock);
    final children = widget.ops.getChildren(targetBlock);

    T? newParent;
    int newIndex;

    switch (position) {
      case DropPosition.before:
        final parentAndIndex = _findParentAndIndex(targetId);
        if (parentAndIndex == null) return;
        newParent = parentAndIndex.$1;
        newIndex = parentAndIndex.$2;
        break;
      case DropPosition.after:
        final parentAndIndex = _findParentAndIndex(targetId);
        if (parentAndIndex == null) return;
        newParent = parentAndIndex.$1;
        newIndex = parentAndIndex.$2 + 1;
        break;
      case DropPosition.asChild:
        newParent = targetBlock;
        newIndex = children.length;
        break;
    }

    final provider = widget.notifierProvider ?? outlinerProvider;
    final notifier = ref.read(provider.notifier);
    await notifier.moveBlock(dragData.block, newParent, newIndex);
  }

  /// Find the parent block and index of a block with the given ID
  /// Returns (parent, index) or null if not found
  (T?, int)? _findParentAndIndex(String blockId) {
    // Search from top-level blocks
    final topLevel = widget.ops.getTopLevelBlocks();
    for (int i = 0; i < topLevel.length; i++) {
      if (widget.ops.getId(topLevel[i]) == blockId) {
        return (null, i); // Parent is root (null), index is i
      }
    }

    // Search recursively in the tree
    for (var topBlock in topLevel) {
      final result = _findParentAndIndexInSubtree(topBlock, blockId);
      if (result != null) return result;
    }

    return null;
  }

  /// Recursively search for a block in a subtree
  (T, int)? _findParentAndIndexInSubtree(T parent, String blockId) {
    final children = widget.ops.getChildren(parent);
    for (int i = 0; i < children.length; i++) {
      if (widget.ops.getId(children[i]) == blockId) {
        return (parent, i);
      }
      final result = _findParentAndIndexInSubtree(children[i], blockId);
      if (result != null) return result;
    }
    return null;
  }

  Color _resolveDropZoneColor() {
    return widget.style.bulletColor ?? const Color.fromARGB(255, 225, 192, 24);
  }
}
