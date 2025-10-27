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
  final bool isLastSibling;
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
    this.isLastSibling = false,
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

const double _kChildDropZoneWidth = 96.0;
const Color _kDefaultDropZoneHighlight = Color.fromARGB(120, 27, 115, 232);
const double _kDropZoneHitHeight = 16.0;

class _DraggableBlockWidgetState extends ConsumerState<DraggableBlockWidget> {
  bool _isDraggingOverBefore = false;
  bool _isDraggingOverAfter = false;
  bool _isDraggingOverChild = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * widget.style.indentWidth;
    final hasChildren = widget.block.hasChildren;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropZone(DropPosition.before, indent),
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: _buildRow(context, showAsChildZone: !hasChildren),
        ),
        if (!widget.block.isCollapsed)
          ...widget.block.children.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final child = entry.value;
              final isLastChild = index == widget.block.children.length - 1;

              return DraggableBlockWidget(
                key: ValueKey(child.id),
                block: child,
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
      bulletDragWrapper: _buildBulletDragWrapper,
    );
  }

  Widget _buildBulletDragWrapper(BuildContext context, Widget child) {
    final dragData = DragData(
      block: widget.block,
      sourceParentId: '',
      sourceIndex: 0,
    );

    return Draggable<DragData>(
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

    final children = widget.block.children.take(5).toList();

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
                child: BlockWidget(
                  block: widget.block,
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
                    child: BlockWidget(
                      block: child,
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

    return DragTarget<DragData>(
      onWillAcceptWithDetails: (details) {
        // For before/after, just check if source and target are different
        // The repository layer will handle complex validation
        return details.data.block.id != widget.block.id;
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
        if (details.data.block.id == widget.block.id) return;

        // For before/after, check if the target's parent is a descendant of source
        // (which would make source become a child of its own descendant)
        final targetParentId = _findParentIdSync(widget.block.id);
        if (targetParentId != null) {
          if (_isDescendantOfById(targetParentId, details.data.block.id)) {
            return;
          }
        }

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
    return DragTarget<DragData>(
      onWillAcceptWithDetails: (details) {
        if (details.data.block.id == widget.block.id) return false;
        return !_isDescendantOfById(widget.block.id, details.data.block.id);
      },
      onAcceptWithDetails: (details) {
        _handleDrop(details.data, DropPosition.asChild);
        setState(() {
          _isDraggingOverChild = false;
        });
      },
      onMove: (details) {
        // Only highlight if this would be a valid drop
        if (details.data.block.id == widget.block.id) return;
        if (_isDescendantOfById(widget.block.id, details.data.block.id)) return;

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

  /// Finds the parent ID of a block synchronously using the current state.
  String? _findParentIdSync(String blockId) {
    final state = ref.read(outlinerProvider);
    return state.maybeWhen(
      loaded: (rootBlock, _, __, ___) {
        return _findParentIdInBlock(rootBlock, blockId);
      },
      orElse: () => null,
    );
  }

  /// Recursively finds the parent ID of a block in the tree.
  String? _findParentIdInBlock(Block parent, String blockId) {
    for (var child in parent.children) {
      if (child.id == blockId) return parent.id;
      final found = _findParentIdInBlock(child, blockId);
      if (found != null) return found;
    }
    return null;
  }

  /// Checks if [potentialDescendantId] is a descendant of [ancestorId] using
  /// the current state from the provider (not stale Block objects).
  bool _isDescendantOfById(String potentialDescendantId, String ancestorId) {
    final state = ref.read(outlinerProvider);
    return state.maybeWhen(
      loaded: (rootBlock, _, __, ___) {
        final ancestor = rootBlock.findBlockById(ancestorId);
        if (ancestor == null) return false;

        // Check if the potentialDescendant is found in the ancestor's subtree
        return ancestor.findBlockById(potentialDescendantId) != null;
      },
      orElse: () => false,
    );
  }

  Future<void> _handleDrop(DragData dragData, DropPosition position) async {
    final notifier = ref.read(outlinerProvider.notifier);
    final state = ref.read(outlinerProvider);

    final rootId = state.whenOrNull(
      loaded: (rootBlock, _, __, ___) => rootBlock.id,
    );

    if (rootId == null) return;

    final currentParentId = await notifier.findParentId(widget.block.id);
    final currentIndex = await notifier.findBlockIndex(widget.block.id);

    String newParentId;
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

    debugPrint(
      '[Drop] source=${dragData.block.id} target=${widget.block.id} '
      'position=$position newParent=$newParentId newIndex=$newIndex',
    );

    await notifier.moveBlock(dragData.block.id, newParentId, newIndex);
  }

  Color _resolveDropZoneColor() {
    return widget.style.bulletColor ?? const Color.fromARGB(255, 225, 192, 24);
  }
}
