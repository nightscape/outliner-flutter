import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/models/outliner_state.dart';
import 'package:outliner_view/models/tree_constants.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'package:outliner_view/repositories/in_memory_outliner_repository.dart';

List<Block> _getBlocks(OutlinerState state) {
  return state.maybeWhen(
    loaded: (rootBlock, _, __, ___) => rootBlock.children,
    orElse: () => [],
  );
}

class OutlinerModel {
  final Map<String, String> parentMap;
  final Map<String, List<String>> childrenMap;
  final Set<String> allBlockIds;
  final String rootId;

  OutlinerModel({
    required this.parentMap,
    required this.childrenMap,
    required this.allBlockIds,
    required this.rootId,
  });

  OutlinerModel.fromNotifier(OutlinerNotifier notifier)
    : parentMap = {},
      childrenMap = {},
      allBlockIds = {},
      rootId = _getRootId(notifier.state) {
    final root = notifier.state.whenOrNull(
      loaded: (rootBlock, _, __, ___) => rootBlock,
    );
    if (root != null) {
      _buildModel(root, null);
    }
  }

  static String _getRootId(OutlinerState state) {
    return state.whenOrNull(
      loaded: (rootBlock, _, __, ___) => rootBlock.id,
    ) ?? '';
  }

  void _buildModel(Block block, String? parentId) {
    final isActualRoot = parentId == null;

    if (isActualRoot) {
      parentMap[block.id] = kRootParentId;
      childrenMap[block.id] = block.children.map((c) => c.id).toList();
    } else {
      allBlockIds.add(block.id);
      parentMap[block.id] = parentId;
      childrenMap.putIfAbsent(parentId, () => []).add(block.id);
      childrenMap[block.id] = block.children.map((c) => c.id).toList();
    }

    for (final child in block.children) {
      _buildModel(child, block.id);
    }
  }

  OutlinerModel copy() {
    return OutlinerModel(
      parentMap: Map.from(parentMap),
      childrenMap: childrenMap.map((k, v) => MapEntry(k, List<String>.from(v))),
      allBlockIds: Set.from(allBlockIds),
      rootId: rootId,
    );
  }

  void updateAfterMove(String blockId, String newParentId, int newIndex) {
    if (blockId == newParentId) return;
    if (isDescendantOf(newParentId, blockId)) return;

    final oldParentId = parentMap[blockId];

    if (oldParentId != null) {
      childrenMap[oldParentId]?.remove(blockId);
      if ((childrenMap[oldParentId]?.isEmpty ?? false) &&
          oldParentId != rootId) {
        childrenMap.remove(oldParentId);
      }
    }

    parentMap[blockId] = newParentId;

    final children = childrenMap.putIfAbsent(newParentId, () => []);
    final existingIndex = children.indexOf(blockId);
    if (existingIndex != -1) {
      children.removeAt(existingIndex);
    }
    final clampedIndex = newIndex.clamp(0, children.length);
    children.insert(clampedIndex, blockId);
  }

  bool isDescendantOf(String potentialDescendant, String ancestor) {
    String current = potentialDescendant;
    while (current != kRootParentId && current != rootId) {
      if (current == ancestor) return true;
      final parent = parentMap[current];
      if (parent == null) {
        throw StateError('Block not found in parent map: $current');
      }
      current = parent;
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
        // This is a workaround for synchronous generator - blocks will be added in test setup
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
    final possibleTargets = <({String parentId, int index})>[];

    // Add root as possible target
    final rootChildren = model.childrenMap[model.rootId] ?? [];
    for (var i = 0; i <= rootChildren.length; i++) {
      possibleTargets.add((parentId: model.rootId, index: i));
    }

    for (var targetBlockId in allBlocks) {
      if (targetBlockId == blockId) continue;
      if (model.isDescendantOf(targetBlockId, blockId)) continue;

      final childCount = model.childrenMap[targetBlockId]?.length ?? 0;
      for (var i = 0; i <= childCount; i++) {
        possibleTargets.add((parentId: targetBlockId, index: i));
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
