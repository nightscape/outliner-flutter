enum DropPosition { before, after, asChild }

/// Data carried during drag-and-drop operations.
/// Generic type [T] matches the block type being dragged.
class DragData<T> {
  /// The block being dragged
  final T block;

  /// The ID of the block being dragged (cached for quick comparisons)
  final String blockId;

  DragData({
    required this.block,
    required this.blockId,
  });
}

class DropTarget {
  final String? targetParentId;
  final int targetIndex;
  final DropPosition position;

  DropTarget({
    required this.targetParentId,
    required this.targetIndex,
    required this.position,
  });
}
