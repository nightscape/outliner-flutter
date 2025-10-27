import 'package:dartproptest/dartproptest.dart';
import 'package:outliner_view/models/block.dart';
import 'operations.dart';
import 'outliner_model.dart';

class BlockGenerators {
  static Generator<List<Block>> blockList() {
    return Gen.interval(2, 5).flatMap((numBlocks) {
      return Gen.array(
        blockWithChildren(),
        minLength: numBlocks,
        maxLength: numBlocks,
      );
    });
  }

  static Generator<Block> blockWithChildren() {
    return Gen.interval(0, 1000000).flatMap((id) {
      return Gen.interval(0, 2).map((numChildren) {
        final children = <Block>[];
        for (var i = 0; i < numChildren; i++) {
          children.add(
            Block.create(
              content: 'Block ${id * 100 + i + 1}',
              id: 'block-${id * 100 + i + 1}',
            ),
          );
        }
        return Block.create(
          content: 'Block $id',
          id: 'block-$id',
          children: children,
        );
      });
    });
  }

  static Generator<Block> simpleBlock() {
    return Gen.interval(0, 1000000).map((id) {
      return Block.create(content: 'Block $id', id: 'block-$id');
    });
  }
}

class OperationGenerators {
  static Generator<Operation> anyOperation(
    OutlinerModel model, {
    bool onlyVisible = false,
  }) {
    final blockIds = onlyVisible && model is UIOutlinerModel
        ? model.visibleBlockIds
        : model.allBlockIds.toList();

    if (blockIds.isEmpty) {
      return Gen.just(
        const DragOperation(
          sourceBlockId: '',
          targetBlockId: '',
          targetType: DragTargetType.before,
        ),
      );
    }

    final generators = <Generator<Operation>>[
      dragOperation(model, blockIds),
      indentOperation(model, blockIds),
      outdentOperation(model, blockIds),
    ];

    if (model is UIOutlinerModel) {
      generators.add(enterOperation(blockIds));
      generators.add(toggleCollapseOperation(model));
      generators.add(arrowUpOperation(blockIds));
      generators.add(arrowDownOperation(blockIds));
    }

    return Gen.oneOf(generators);
  }

  static Generator<Operation> dragOperation(
    OutlinerModel model,
    List<String> blockIds,
  ) {
    // Generate all valid drag operations upfront
    final validOperations = <DragOperation>[];

    for (final sourceId in blockIds) {
      for (final targetId in blockIds) {
        for (final targetType in [
          DragTargetType.before,
          DragTargetType.after,
          DragTargetType.asChild,
        ]) {
          if (_isValidDrag(model, sourceId, targetId, targetType)) {
            validOperations.add(
              DragOperation(
                sourceBlockId: sourceId,
                targetBlockId: targetId,
                targetType: targetType,
              ),
            );
          }
        }
      }
    }

    if (validOperations.isEmpty) {
      return Gen.just(
        const DragOperation(
          sourceBlockId: '',
          targetBlockId: '',
          targetType: DragTargetType.before,
        ),
      );
    }

    return Gen.interval(
      0,
      validOperations.length - 1,
    ).map((idx) => validOperations[idx]);
  }

  static bool _isValidDrag(
    OutlinerModel model,
    String sourceId,
    String targetId,
    DragTargetType type,
  ) {
    if (sourceId.isEmpty || targetId.isEmpty) return false;
    if (sourceId == targetId) return false;
    if (!model.allBlockIds.contains(sourceId)) return false;
    if (!model.allBlockIds.contains(targetId)) return false;

    String? newParentId;

    if (type == DragTargetType.asChild) {
      // asChild only allowed for leaf nodes (no children)
      final targetChildren = model.childrenMap[targetId] ?? [];
      if (targetChildren.isNotEmpty) return false;

      // Can't drop into descendants
      if (model.isDescendantOf(targetId, sourceId)) return false;
      newParentId = targetId;
    } else if (type == DragTargetType.after) {
      // "after" only allowed for last siblings
      final targetParentId = model.parentMap[targetId];
      final siblings = model.childrenMap[targetParentId] ?? [];
      final targetIndex = siblings.indexOf(targetId);
      final isLastSibling = targetIndex == siblings.length - 1;

      if (!isLastSibling) return false;

      newParentId = targetParentId;

      // Skip if already in the same parent
      final currentParentId = model.parentMap[sourceId];
      if (currentParentId == newParentId) return false;
    } else {
      // DragTargetType.before - always allowed
      newParentId = model.parentMap[targetId];

      // Skip if already in the same parent
      final currentParentId = model.parentMap[sourceId];
      if (currentParentId == newParentId) return false;
    }

    // Can't make a block a child of itself
    if (sourceId == newParentId) return false;

    // Prevent cycles
    if (newParentId != null && model.isDescendantOf(newParentId, sourceId)) {
      return false;
    }

    return true;
  }

  static Generator<Operation> indentOperation(
    OutlinerModel model,
    List<String> blockIds,
  ) {
    // Filter to blocks that can actually be indented
    final validBlocks = blockIds.where((blockId) {
      final parentId = model.parentMap[blockId];
      final siblings = model.childrenMap[parentId] ?? [];
      final blockIndex = siblings.indexOf(blockId);

      // Can only indent if there's a previous sibling
      return blockIndex > 0;
    }).toList();

    if (validBlocks.isEmpty) {
      return Gen.just(const IndentOperation(''));
    }

    return Gen.interval(0, validBlocks.length - 1).map((blockIdx) {
      return IndentOperation(validBlocks[blockIdx]);
    });
  }

  static Generator<Operation> outdentOperation(
    OutlinerModel model,
    List<String> blockIds,
  ) {
    // Filter to blocks that can actually be outdented (not direct children of root)
    final validBlocks = blockIds.where((blockId) {
      final parentId = model.parentMap[blockId];
      return parentId != null && parentId != model.rootId;
    }).toList();

    if (validBlocks.isEmpty) {
      return Gen.just(const OutdentOperation(''));
    }

    return Gen.interval(0, validBlocks.length - 1).map((blockIdx) {
      return OutdentOperation(validBlocks[blockIdx]);
    });
  }

  static Generator<Operation> enterOperation(List<String> blockIds) {
    if (blockIds.isEmpty) {
      return Gen.just(const EnterOperation('', 0));
    }

    return Gen.interval(0, blockIds.length - 1).flatMap((blockIdx) {
      return Gen.interval(0, 2).map((positionType) {
        return EnterOperation(blockIds[blockIdx], positionType);
      });
    });
  }

  static Generator<Operation> toggleCollapseOperation(UIOutlinerModel model) {
    final blocksWithChildren = model.allBlockIds.where((id) {
      return model.isBlockVisible(id) &&
          model.childrenMap.containsKey(id) &&
          model.childrenMap[id]!.isNotEmpty;
    }).toList();

    if (blocksWithChildren.isEmpty) {
      return Gen.just(const ToggleCollapseOperation(''));
    }

    return Gen.interval(0, blocksWithChildren.length - 1).map((blockIdx) {
      return ToggleCollapseOperation(blocksWithChildren[blockIdx]);
    });
  }

  static Generator<Operation> arrowUpOperation(List<String> blockIds) {
    if (blockIds.isEmpty) {
      return Gen.just(const ArrowUpOperation(''));
    }

    return Gen.interval(0, blockIds.length - 1).map((blockIdx) {
      return ArrowUpOperation(blockIds[blockIdx]);
    });
  }

  static Generator<Operation> arrowDownOperation(List<String> blockIds) {
    if (blockIds.isEmpty) {
      return Gen.just(const ArrowDownOperation(''));
    }

    return Gen.interval(0, blockIds.length - 1).map((blockIdx) {
      return ArrowDownOperation(blockIds[blockIdx]);
    });
  }
}
