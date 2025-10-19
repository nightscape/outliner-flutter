import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'test_context.dart';

class OutlinerModel {
  final Map<String, String?> parentMap;
  final Map<String, List<String>> childrenMap;
  final Set<String> allBlockIds;

  OutlinerModel({
    required this.parentMap,
    required this.childrenMap,
    required this.allBlockIds,
  });

  OutlinerModel.fromNotifier(OutlinerNotifier notifier)
    : parentMap = {},
      childrenMap = {},
      allBlockIds = {} {
    notifier.state.whenOrNull(
      loaded: (blocks, focusedBlockId) => _buildModel(blocks, null),
    );
  }

  OutlinerModel.fromContext(TestContext context)
    : parentMap = {},
      childrenMap = {},
      allBlockIds = {} {
    _buildModel(context.blocks, null);
  }

  void _buildModel(List<Block> blocks, String? parentId) {
    for (var block in blocks) {
      allBlockIds.add(block.id);
      parentMap[block.id] = parentId;

      if (parentId != null) {
        childrenMap.putIfAbsent(parentId, () => []).add(block.id);
      }

      if (block.hasChildren) {
        _buildModel(block.children, block.id);
      }
    }
  }

  void updateAfterMove(String blockId, String? newParentId) {
    if (newParentId != null) {
      if (blockId == newParentId) return;
      if (isDescendantOf(newParentId, blockId)) return;
    }

    final oldParentId = parentMap[blockId];

    if (oldParentId != null) {
      childrenMap[oldParentId]?.remove(blockId);
      if (childrenMap[oldParentId]?.isEmpty ?? false) {
        childrenMap.remove(oldParentId);
      }
    }

    parentMap[blockId] = newParentId;
  }

  bool isDescendantOf(String potentialDescendant, String ancestor) {
    String? current = potentialDescendant;
    while (current != null) {
      if (current == ancestor) return true;
      current = parentMap[current];
    }
    return false;
  }

  void clear() {
    parentMap.clear();
    childrenMap.clear();
    allBlockIds.clear();
  }

  void copyFrom(OutlinerModel other) {
    parentMap.clear();
    childrenMap.clear();
    allBlockIds.clear();
    parentMap.addAll(other.parentMap);
    childrenMap.addAll(other.childrenMap);
    allBlockIds.addAll(other.allBlockIds);
  }
}

class UIOutlinerModel extends OutlinerModel {
  final Map<String, bool> collapseStateMap;

  UIOutlinerModel({
    required super.parentMap,
    required super.childrenMap,
    required super.allBlockIds,
    required this.collapseStateMap,
  });

  UIOutlinerModel.fromNotifier(OutlinerNotifier notifier)
    : collapseStateMap = {},
      super(parentMap: {}, childrenMap: {}, allBlockIds: {}) {
    notifier.state.whenOrNull(
      loaded: (blocks, focusedBlockId) => _buildModelWithCollapse(blocks, null),
    );
  }

  UIOutlinerModel.fromContext(TestContext context)
    : collapseStateMap = {},
      super(parentMap: {}, childrenMap: {}, allBlockIds: {}) {
    _buildModelWithCollapse(context.blocks, null);
  }

  void _buildModelWithCollapse(List<Block> blocks, String? parentId) {
    for (var block in blocks) {
      allBlockIds.add(block.id);
      parentMap[block.id] = parentId;
      collapseStateMap[block.id] = block.isCollapsed;

      if (parentId != null) {
        childrenMap.putIfAbsent(parentId, () => []).add(block.id);
      }

      if (block.hasChildren) {
        _buildModelWithCollapse(block.children, block.id);
      }
    }
  }

  bool isBlockVisible(String blockId) {
    String? current = blockId;
    while (current != null) {
      final parentId = parentMap[current];
      if (parentId != null) {
        final parentCollapsed = collapseStateMap[parentId] ?? false;
        if (parentCollapsed) return false;
      }
      current = parentId;
    }
    return true;
  }

  List<String> get visibleBlockIds {
    return allBlockIds.where(isBlockVisible).toList();
  }

  @override
  void clear() {
    super.clear();
    collapseStateMap.clear();
  }

  @override
  void copyFrom(covariant UIOutlinerModel other) {
    super.copyFrom(other);
    collapseStateMap.clear();
    collapseStateMap.addAll(other.collapseStateMap);
  }
}
