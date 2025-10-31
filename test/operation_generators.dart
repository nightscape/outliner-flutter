import 'package:dartproptest/dartproptest.dart';
import 'package:outliner_view/core/block_ops.dart';
import 'package:outliner_view/models/block.dart';
import 'operations.dart';
import 'test_context.dart';

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

class OperationGenerators<T> {
  final TestContext<T> context;
  final bool includeUIOperations;

  OperationGenerators(this.context, {this.includeUIOperations = false});

  /// Collects all blocks in the tree (for generating operations)
  List<T> _collectAllBlocks() {
    final ops = context.ops;
    final allBlocks = <T>[];

    void collectFromBlock(T block) {
      allBlocks.add(block);
      for (final child in ops.getChildren(block)) {
        collectFromBlock(child);
      }
    }

    for (final block in context.blocks) {
      collectFromBlock(block);
    }

    return allBlocks;
  }

  Generator<Operation<T>> anyOperation() {
    final blocks = _collectAllBlocks();

    if (blocks.isEmpty) {
      // Return a dummy operation - should never be executed
      final dummyBlock = context.blocks.isNotEmpty
          ? context.blocks.first
          : context.rootBlock;
      return Gen.just(
        DragOperation<T>(
          sourceBlock: dummyBlock,
          targetBlock: dummyBlock,
          targetType: DragTargetType.before,
        ),
      );
    }

    final generators = <Generator<Operation<T>>>[
      dragOperation(blocks),
      indentOperation(blocks),
      outdentOperation(blocks),
    ];

    if (includeUIOperations) {
      generators.add(enterOperation(blocks));
      generators.add(toggleCollapseOperation(blocks));
      generators.add(arrowUpOperation(blocks));
      generators.add(arrowDownOperation(blocks));
    }

    return Gen.oneOf(generators);
  }

  Generator<Operation<T>> dragOperation(List<T> blocks) {
    final ops = context.ops;
    // Generate all valid drag operations upfront
    final validOperations = <DragOperation<T>>[];

    for (final sourceBlock in blocks) {
      for (final targetBlock in blocks) {
        for (final targetType in [
          DragTargetType.before,
          DragTargetType.after,
          DragTargetType.asChild,
        ]) {
          if (_isValidDrag(sourceBlock, targetBlock, targetType)) {
            validOperations.add(
              DragOperation<T>(
                sourceBlock: sourceBlock,
                targetBlock: targetBlock,
                targetType: targetType,
              ),
            );
          }
        }
      }
    }

    if (validOperations.isEmpty) {
      final dummyBlock = context.blocks.isNotEmpty
          ? context.blocks.first
          : context.rootBlock;
      return Gen.just(
        DragOperation<T>(
          sourceBlock: dummyBlock,
          targetBlock: dummyBlock,
          targetType: DragTargetType.before,
        ),
      );
    }

    return Gen.interval(
      0,
      validOperations.length - 1,
    ).map((idx) => validOperations[idx]);
  }

  T? _findParentInTree(T potentialParent, T target) {
    final ops = context.ops;
    final children = ops.getChildren(potentialParent);

    for (final child in children) {
      if (ops.getId(child) == ops.getId(target)) {
        return potentialParent;
      }
      final found = _findParentInTree(child, target);
      if (found != null) return found;
    }

    return null;
  }

  T? _findParent(T block) {
    final ops = context.ops;
    for (final rootBlock in context.blocks) {
      if (ops.getId(rootBlock) == ops.getId(block)) {
        return null; // Block is at root level
      }
      final parent = _findParentInTree(rootBlock, block);
      if (parent != null) return parent;
    }
    return null;
  }

  bool _isValidDrag(T sourceBlock, T targetBlock, DragTargetType type) {
    final ops = context.ops;
    final sourceId = ops.getId(sourceBlock);
    final targetId = ops.getId(targetBlock);

    if (sourceId == targetId) return false;

    // Can't drop into descendants
    if (ops.isDescendantOf(targetBlock, sourceBlock)) return false;

    if (type == DragTargetType.asChild) {
      // asChild only allowed for leaf nodes (no children)
      if (ops.hasChildren(targetBlock)) return false;
    }

    // For now, allow all other combinations
    // More sophisticated validation can be added later
    return true;
  }

  Generator<Operation<T>> indentOperation(List<T> blocks) {
    final ops = context.ops;
    // Filter to blocks that can actually be indented
    final validBlocks = blocks.where((block) {
      final parent = _findParent(block);
      if (parent == null) return false;

      final siblings = ops.getChildren(parent);
      final blockIndex = siblings.indexWhere((s) => ops.getId(s) == ops.getId(block));

      // Can only indent if there's a previous sibling
      return blockIndex > 0;
    }).toList();

    if (validBlocks.isEmpty) {
      final dummyBlock = context.blocks.isNotEmpty
          ? context.blocks.first
          : context.rootBlock;
      return Gen.just(IndentOperation<T>(dummyBlock));
    }

    return Gen.interval(0, validBlocks.length - 1).map((blockIdx) {
      return IndentOperation<T>(validBlocks[blockIdx]);
    });
  }

  Generator<Operation<T>> outdentOperation(List<T> blocks) {
    final ops = context.ops;
    final rootId = ops.getId(context.rootBlock);

    // Filter to blocks that can actually be outdented (not direct children of root)
    final validBlocks = blocks.where((block) {
      final parent = _findParent(block);
      if (parent == null) return false;

      // Can't outdent if parent is root
      return ops.getId(parent) != rootId;
    }).toList();

    if (validBlocks.isEmpty) {
      final dummyBlock = context.blocks.isNotEmpty
          ? context.blocks.first
          : context.rootBlock;
      return Gen.just(OutdentOperation<T>(dummyBlock));
    }

    return Gen.interval(0, validBlocks.length - 1).map((blockIdx) {
      return OutdentOperation<T>(validBlocks[blockIdx]);
    });
  }

  Generator<Operation<T>> enterOperation(List<T> blocks) {
    if (blocks.isEmpty) {
      final dummyBlock = context.blocks.isNotEmpty
          ? context.blocks.first
          : context.rootBlock;
      return Gen.just(EnterOperation<T>(dummyBlock, 0));
    }

    return Gen.interval(0, blocks.length - 1).flatMap((blockIdx) {
      return Gen.interval(0, 2).map((positionType) {
        return EnterOperation<T>(blocks[blockIdx], positionType);
      });
    });
  }

  Generator<Operation<T>> toggleCollapseOperation(List<T> blocks) {
    final ops = context.ops;
    final blocksWithChildren = blocks.where((block) {
      return ops.hasChildren(block);
    }).toList();

    if (blocksWithChildren.isEmpty) {
      final dummyBlock = context.blocks.isNotEmpty
          ? context.blocks.first
          : context.rootBlock;
      return Gen.just(ToggleCollapseOperation<T>(dummyBlock));
    }

    return Gen.interval(0, blocksWithChildren.length - 1).map((blockIdx) {
      return ToggleCollapseOperation<T>(blocksWithChildren[blockIdx]);
    });
  }

  Generator<Operation<T>> arrowUpOperation(List<T> blocks) {
    if (blocks.isEmpty) {
      final dummyBlock = context.blocks.isNotEmpty
          ? context.blocks.first
          : context.rootBlock;
      return Gen.just(ArrowUpOperation<T>(dummyBlock));
    }

    return Gen.interval(0, blocks.length - 1).map((blockIdx) {
      return ArrowUpOperation<T>(blocks[blockIdx]);
    });
  }

  Generator<Operation<T>> arrowDownOperation(List<T> blocks) {
    if (blocks.isEmpty) {
      final dummyBlock = context.blocks.isNotEmpty
          ? context.blocks.first
          : context.rootBlock;
      return Gen.just(ArrowDownOperation<T>(dummyBlock));
    }

    return Gen.interval(0, blocks.length - 1).map((blockIdx) {
      return ArrowDownOperation<T>(blocks[blockIdx]);
    });
  }
}
