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
      indentOperation(blockIds),
      outdentOperation(blockIds),
    ];

    if (model is UIOutlinerModel) {
      generators.add(enterOperation(blockIds));
      generators.add(toggleCollapseOperation(model));
    }

    return Gen.oneOf(generators);
  }

  static Generator<Operation> dragOperation(
    OutlinerModel model,
    List<String> blockIds,
  ) {
    if (blockIds.length < 2) {
      return Gen.just(
        const DragOperation(
          sourceBlockId: '',
          targetBlockId: '',
          targetType: DragTargetType.before,
        ),
      );
    }

    return Gen.interval(0, blockIds.length - 1).flatMap((sourceIdx) {
      return Gen.interval(0, blockIds.length - 1).flatMap((targetIdx) {
        return Gen.interval(0, 2).map((typeIdx) {
          final targetTypes = [
            DragTargetType.before,
            DragTargetType.after,
            DragTargetType.asChild,
          ];

          return DragOperation(
            sourceBlockId: blockIds[sourceIdx],
            targetBlockId: blockIds[targetIdx],
            targetType: targetTypes[typeIdx],
          );
        });
      });
    });
  }

  static Generator<Operation> indentOperation(List<String> blockIds) {
    if (blockIds.isEmpty) {
      return Gen.just(const IndentOperation(''));
    }

    return Gen.interval(0, blockIds.length - 1).map((blockIdx) {
      return IndentOperation(blockIds[blockIdx]);
    });
  }

  static Generator<Operation> outdentOperation(List<String> blockIds) {
    if (blockIds.isEmpty) {
      return Gen.just(const OutdentOperation(''));
    }

    return Gen.interval(0, blockIds.length - 1).map((blockIdx) {
      return OutdentOperation(blockIds[blockIdx]);
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
}
