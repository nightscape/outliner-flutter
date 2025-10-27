import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/models/tree_constants.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'test_context.dart';

class OutlinerModel {
  final Map<String, String> parentMap = {};
  final Map<String, List<String>> childrenMap = {};
  final Map<String, String> contentMap = {};
  final Map<String, bool> collapseStateMap = {};
  final Set<String> allBlockIds = {};
  late String rootId;

  OutlinerModel.fromNotifier(OutlinerNotifier notifier) {
    notifier.state.whenOrNull(
      loaded: (rootBlock, focusedBlockId, cursorPosition, viewRootId) {
        _buildTree(rootBlock, parentId: null);
      },
    );
  }

  OutlinerModel.fromContext(TestContext context) {
    final root = context.rootBlock;
    if (root != null) {
      _buildTree(root, parentId: null);
    }
  }

  void _buildTree(Block block, {String? parentId}) {
    final isActualRoot = parentId == null;

    if (isActualRoot) {
      rootId = block.id;
      parentMap[block.id] = kRootParentId;
    } else {
      parentMap[block.id] = parentId;
      allBlockIds.add(block.id);
    }

    contentMap[block.id] = block.content;
    collapseStateMap[block.id] = block.isCollapsed;

    final childIds = block.children.map((child) => child.id).toList();
    childrenMap[block.id] = childIds;

    for (final child in block.children) {
      _buildTree(child, parentId: block.id);
    }
  }

  /// Returns all block IDs that are not the root block.
  /// These are the blocks that can be manipulated (moved, indented, etc.)
  Set<String> getNonRootBlockIds() {
    return allBlockIds;
  }

  bool isDescendantOf(String potentialDescendant, String ancestor) {
    String current = potentialDescendant;
    while (current != kRootParentId && current != rootId) {
      if (current == ancestor) return true;
      final parent = parentMap[current];
      if (parent == null) break;
      current = parent;
    }
    return false;
  }

  void updateAfterMove(String blockId, String newParentId, int newIndex) {
    assert(blockId != newParentId, 'Cannot make block a child of itself');
    assert(
      !isDescendantOf(newParentId, blockId),
      'Cannot move block into its descendant',
    );

    final oldParentId = parentMap[blockId];
    if (oldParentId != null) {
      childrenMap[oldParentId]?.remove(blockId);
    }

    parentMap[blockId] = newParentId;
    final siblings = childrenMap.putIfAbsent(newParentId, () => <String>[]);
    final existingIndex = siblings.indexOf(blockId);
    if (existingIndex != -1) {
      siblings.removeAt(existingIndex);
    }
    final insertIndex = newIndex.clamp(0, siblings.length);
    siblings.insert(insertIndex, blockId);
  }

  void moveBlock(String blockId, String newParentId, int newIndex) {
    if (!allBlockIds.contains(blockId)) {
      throw StateError('moveBlock: blockId $blockId does not exist in model');
    }
    if (blockId == newParentId) {
      throw StateError(
        'moveBlock: cannot make block $blockId a child of itself',
      );
    }
    if (isDescendantOf(newParentId, blockId)) {
      throw StateError(
        'moveBlock: cannot move $blockId into its descendant $newParentId',
      );
    }

    updateAfterMove(blockId, newParentId, newIndex);
  }

  void indentBlock(String blockId) {
    if (!allBlockIds.contains(blockId)) return;

    final parentId = parentMap[blockId];
    if (parentId == null) {
      throw StateError('Block not found in parent map: $blockId');
    }

    final siblings = childrenMap[parentId] ?? <String>[];
    final blockIndex = siblings.indexOf(blockId);
    if (blockIndex <= 0) return;

    final newParentId = siblings[blockIndex - 1];
    final newParentChildren = childrenMap[newParentId] ?? <String>[];
    moveBlock(blockId, newParentId, newParentChildren.length);
  }

  void outdentBlock(String blockId) {
    if (!allBlockIds.contains(blockId)) return;

    final parentId = parentMap[blockId];
    if (parentId == null) {
      throw StateError('Block not found in parent map: $blockId');
    }
    if (parentId == rootId) {
      throw StateError('Cannot outdent direct child of root: $blockId');
    }

    final grandParentId = parentMap[parentId];
    if (grandParentId == null) {
      throw StateError('Parent block not found in parent map: $parentId');
    }

    final parentSiblings = childrenMap[grandParentId] ?? <String>[];
    final parentIndex = parentSiblings.indexOf(parentId);
    if (parentIndex == -1) return;

    moveBlock(blockId, grandParentId, parentIndex + 1);
  }

  void addBlock(
    String blockId,
    String parentId,
    int index, {
    String content = '',
  }) {
    if (allBlockIds.contains(blockId)) return;

    allBlockIds.add(blockId);
    parentMap[blockId] = parentId;
    contentMap[blockId] = content;

    final siblings = childrenMap.putIfAbsent(parentId, () => <String>[]);
    final insertIndex = index.clamp(0, siblings.length);
    siblings.insert(insertIndex, blockId);
  }

  void splitBlock(String blockId, String newBlockId, int cursorPosition) {
    if (!allBlockIds.contains(blockId)) return;

    final content = contentMap[blockId] ?? '';
    final safePosition = cursorPosition.clamp(0, content.length);
    final beforeCursor = content.substring(0, safePosition);
    final afterCursor = content.substring(safePosition);

    contentMap[blockId] = beforeCursor;

    final parentId = parentMap[blockId];
    if (parentId == null) {
      throw StateError('Block not found in parent map: $blockId');
    }
    final siblings = childrenMap[parentId] ?? <String>[];
    final blockIndex = siblings.indexOf(blockId);
    if (blockIndex == -1) return;

    addBlock(newBlockId, parentId, blockIndex + 1, content: afterCursor);
  }

  void toggleCollapse(String blockId) {
    collapseStateMap[blockId] = !(collapseStateMap[blockId] ?? false);
  }

  void clear() {
    parentMap.clear();
    childrenMap.clear();
    contentMap.clear();
    collapseStateMap.clear();
    allBlockIds.clear();
  }
}

class UIOutlinerModel extends OutlinerModel {
  // ignore: use_super_parameters
  UIOutlinerModel.fromContext(TestContext context) : super.fromContext(context);

  List<String> get visibleBlockIds {
    return allBlockIds.where(isBlockVisible).toList();
  }

  bool isBlockVisible(String blockId) {
    String current = blockId;
    while (true) {
      final parentId = parentMap[current];
      if (parentId == null) {
        throw StateError('Block not found in parent map: $current');
      }
      // Reached the root or the root's sentinel parent - block is visible
      if (parentId == kRootParentId || parentId == rootId) {
        return true;
      }
      final parentCollapsed = collapseStateMap[parentId] ?? false;
      if (parentCollapsed) return false;
      current = parentId;
    }
  }
}
