import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/models/outliner_state.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'package:outliner_view/repositories/in_memory_outliner_repository.dart';

List<Block> _getBlocks(OutlinerState state) {
  return state.maybeWhen(
    loaded: (blocks, focusedBlockId) => blocks,
    orElse: () => [],
  );
}

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
    _buildModel(_getBlocks(notifier.state), null);
  }

  void _buildModel(List<Block> blocks, String? parentId) {
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
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

  OutlinerModel copy() {
    return OutlinerModel(
      parentMap: Map.from(parentMap),
      childrenMap: childrenMap.map((k, v) => MapEntry(k, List.from(v))),
      allBlockIds: Set.from(allBlockIds),
    );
  }

  void updateAfterMove(String blockId, String? newParentId, int newIndex) {
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

    if (newParentId != null) {
      final children = childrenMap.putIfAbsent(newParentId, () => []);
      final clampedIndex = newIndex.clamp(0, children.length);
      children.insert(clampedIndex, blockId);
    }
  }

  bool isDescendantOf(String potentialDescendant, String ancestor) {
    String? current = potentialDescendant;
    while (current != null) {
      if (current == ancestor) return true;
      current = parentMap[current];
    }
    return false;
  }
}

class OutlinerGenerators {
  static Generator<OutlinerNotifier> simpleOutliner() {
    return Gen.interval(1, 5).flatMap((numRoots) {
      return Gen.array(
        blockTree(maxDepth: 2, maxChildren: 3),
        minLength: numRoots,
        maxLength: numRoots,
      ).map((blocks) {
        final notifier = OutlinerNotifier(
          InMemoryOutlinerRepository(initializeSampleData: false),
        );
        for (var block in blocks) {
          notifier.addRootBlock(block);
        }
        return notifier;
      });
    });
  }

  static Generator<Block> blockTree({
    required int maxDepth,
    required int maxChildren,
  }) {
    return Gen.interval(0, maxDepth).flatMap((depth) {
      if (depth == 0) {
        return Gen.asciiString(minLength: 1, maxLength: 20).map((content) {
          return Block.create(content: content);
        });
      } else {
        return Gen.asciiString(minLength: 1, maxLength: 20).flatMap((content) {
          return Gen.interval(0, maxChildren).flatMap((numChildren) {
            if (numChildren == 0) {
              return Gen.just(Block.create(content: content));
            }
            return Gen.array(
              blockTree(maxDepth: depth - 1, maxChildren: maxChildren),
              minLength: numChildren,
              maxLength: numChildren,
            ).map((children) {
              return Block.create(content: content, children: children);
            });
          });
        });
      }
    });
  }
}

Generator<Action<OutlinerNotifier, OutlinerModel>> moveActionGen(
  OutlinerNotifier notifier,
  OutlinerModel model,
) {
  final allBlocks = model.allBlockIds.toList();

  if (allBlocks.isEmpty) {
    return Gen.just(
      Action<OutlinerNotifier, OutlinerModel>((notifier, model) {}, 'NoOp'),
    );
  }

  return Gen.elementOf(allBlocks).flatMap((blockId) {
    final possibleTargets = <({String? parentId, int index})>[];

    final blocks = _getBlocks(notifier.state);
    final rootCount = blocks.length;
    for (var i = 0; i <= rootCount; i++) {
      possibleTargets.add((parentId: null, index: i));
    }

    for (var targetBlockId in allBlocks) {
      if (targetBlockId == blockId) continue;
      if (model.isDescendantOf(targetBlockId, blockId)) continue;

      final targetBlock = _findBlock(blocks, targetBlockId);
      if (targetBlock != null) {
        final childCount = targetBlock.children.length;
        for (var i = 0; i <= childCount; i++) {
          possibleTargets.add((parentId: targetBlockId, index: i));
        }
      }
    }

    if (possibleTargets.isEmpty) {
      return Gen.just(
        Action<OutlinerNotifier, OutlinerModel>((notifier, model) {}, 'NoOp'),
      );
    }

    return Gen.elementOf(possibleTargets).map((target) {
      return Action<OutlinerNotifier, OutlinerModel>(
        (notifier, model) {
          notifier.moveBlock(blockId, target.parentId, target.index);
          model.updateAfterMove(blockId, target.parentId, target.index);
        },
        'MoveBlock(id: $blockId, toParent: ${target.parentId}, index: ${target.index})',
      );
    });
  });
}

Block? _findBlock(List<Block> blocks, String blockId) {
  for (var block in blocks) {
    if (block.id == blockId) return block;
    final found = _findBlock(block.children, blockId);
    if (found != null) return found;
  }
  return null;
}

void checkInvariants(OutlinerNotifier notifier, OutlinerModel model) {
  final actualModel = OutlinerModel.fromNotifier(notifier);

  expect(
    actualModel.allBlockIds,
    equals(model.allBlockIds),
    reason: 'Conservation: all blocks should still exist',
  );

  final allActualIds = <String>{};
  _collectAllIds(_getBlocks(notifier.state), allActualIds);
  expect(
    allActualIds.length,
    equals(model.allBlockIds.length),
    reason: 'No duplication: each block appears exactly once',
  );

  for (var blockId in model.allBlockIds) {
    final modelParent = model.parentMap[blockId];
    final actualParent = actualModel.parentMap[blockId];
    expect(
      actualParent,
      equals(modelParent),
      reason: 'Parent relationship for $blockId should match model',
    );
  }

  for (var parentId in model.childrenMap.keys) {
    final modelChildren = model.childrenMap[parentId] ?? [];
    final actualChildren = actualModel.childrenMap[parentId] ?? [];
    expect(
      actualChildren,
      equals(modelChildren),
      reason: 'Children order for $parentId should match model',
    );
  }

  for (var blockId in model.allBlockIds) {
    expect(
      _hasCycle(blockId, model.parentMap),
      isFalse,
      reason: 'No cycles: block $blockId should not be its own ancestor',
    );
  }
}

void _collectAllIds(List<Block> blocks, Set<String> ids) {
  for (var block in blocks) {
    expect(
      ids.contains(block.id),
      isFalse,
      reason: 'Block ${block.id} appears multiple times in tree',
    );
    ids.add(block.id);
    _collectAllIds(block.children, ids);
  }
}

bool _hasCycle(String blockId, Map<String, String?> parentMap) {
  final visited = <String>{};
  String? current = blockId;

  while (current != null) {
    if (visited.contains(current)) return true;
    visited.add(current);
    current = parentMap[current];
  }

  return false;
}

// Commented out to avoid unused element warning, but kept for debugging purposes
// String _debugPrintState(List<Block> blocks, [int depth = 0]) {
//   final buffer = StringBuffer();
//   for (var block in blocks) {
//     buffer.writeln('${'  ' * depth}${block.id}: ${block.content}');
//     if (block.hasChildren) {
//       buffer.write(_debugPrintState(block.children, depth + 1));
//     }
//   }
//   return buffer.toString();
// }

void main() {
  group('Drag&Drop Property-Based Tests', () {
    test('moveBlock preserves all invariants', () {
      final prop =
          statefulProperty<OutlinerNotifier, OutlinerModel>(
                OutlinerGenerators.simpleOutliner(),
                (notifier) => OutlinerModel.fromNotifier(notifier),
                moveActionGen,
              )
              .setNumRuns(200)
              .setMinActions(5)
              .setMaxActions(50)
              .setPostCheck(checkInvariants);

      prop.go();
    });
  });
}
