import 'block.dart';

enum DropPosition { before, after, asChild }

class DragData {
  final Block block;
  final String sourceParentId;
  final int sourceIndex;

  DragData({
    required this.block,
    required this.sourceParentId,
    required this.sourceIndex,
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
