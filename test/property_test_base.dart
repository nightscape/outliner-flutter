import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/widgets/block_widget.dart';
import 'operation_generators.dart';
import 'operation_interpreter.dart';
import 'outliner_model.dart';
import 'test_context.dart';

/// Represents a node in a tree structure for comparison
class TreeNode {
  final String id;
  final bool isCollapsed;
  final List<TreeNode> children;

  TreeNode(this.id, this.isCollapsed, this.children);
}

/// Interface for iterating over tree structures
abstract class TreeIterator {
  Iterable<TreeNode> get roots;
}

/// Iterates over the reference model
class ModelTreeIterator implements TreeIterator {
  final OutlinerModel model;

  ModelTreeIterator(this.model);

  @override
  Iterable<TreeNode> get roots {
    final rootChildren = model.childrenMap[model.rootId] ?? const [];
    return rootChildren.map((id) => _buildNode(id));
  }

  TreeNode _buildNode(String blockId) {
    final collapsed = model.collapseStateMap[blockId] ?? false;
    final childIds = model.childrenMap[blockId] ?? [];
    final children = childIds.map((id) => _buildNode(id)).toList();
    return TreeNode(blockId, collapsed, children);
  }
}

/// Iterates over actual Block tree
class BlockTreeIterator implements TreeIterator {
  final List<Block> blocks;

  BlockTreeIterator(this.blocks);

  @override
  Iterable<TreeNode> get roots {
    return blocks.map((block) => _buildNode(block));
  }

  TreeNode _buildNode(Block block) {
    final children = block.children.map((child) => _buildNode(child)).toList();
    return TreeNode(block.id, block.isCollapsed, children);
  }
}

/// Iterates over rendered widgets (flat list, no hierarchy)
class WidgetTreeIterator implements TreeIterator {
  final WidgetTester tester;

  WidgetTreeIterator(this.tester);

  @override
  Iterable<TreeNode> get roots {
    final blockWidgets = find.byType(BlockWidget, skipOffstage: false);
    final widgets = blockWidgets.evaluate().toList();
    return widgets.map((element) {
      final widget = element.widget as BlockWidget;
      // Widgets are flat - no children in this representation
      return TreeNode(widget.block.id, widget.block.isCollapsed, []);
    });
  }
}

String _buildTreeRepresentation(TreeIterator iterator, String label) {
  final buffer = StringBuffer();
  buffer.writeln('$label:');

  void writeNode(TreeNode node, int depth) {
    final indent = '  ' * depth;
    final collapseMarker = node.isCollapsed ? '[collapsed]' : '';
    buffer.writeln('$indent- ${node.id} $collapseMarker');

    for (var child in node.children) {
      writeNode(child, depth + 1);
    }
  }

  final roots = iterator.roots.toList();
  if (roots.isEmpty) {
    buffer.writeln('  (empty)');
  } else {
    for (var node in roots) {
      writeNode(node, 0);
    }
  }

  return buffer.toString();
}

const int kPropertyTestRuns = int.fromEnvironment(
  'PROPERTY_TEST_RUNS',
  defaultValue: 50,
);
const int kPropertyTestMinOps = int.fromEnvironment(
  'PROPERTY_TEST_MIN_OPS',
  defaultValue: 3,
);
const int kPropertyTestMaxOps = int.fromEnvironment(
  'PROPERTY_TEST_MAX_OPS',
  defaultValue: 10,
);

Future<void> runPropertyTest<C extends TestContext, M extends OutlinerModel>({
  required Generator<List<Block>> blockGenerator,
  required Future<C> Function(List<Block>) createContext,
  required M Function(C) createModel,
  required OperationInterpreter<C, M> interpreter,
  required void Function(C, M, String) checkInvariants,
  required Future<void> Function(C)? tearDown,
  bool onlyVisibleBlocks = false,
}) async {
  int runCount = 0;

  await forAllAsync(
    (List<Block> initialBlocks) async {
      runCount++;
      if (runCount % 10 == 0) {
        debugPrint('Property Test: Run $runCount/$kPropertyTestRuns');
      }

      final ctx = await createContext(initialBlocks);
      final model = createModel(ctx);

      checkInvariants(ctx, model, 'Run $runCount - Initial');

      try {
        final rand = Random();
        final numActions = Gen.interval(
          kPropertyTestMinOps,
          kPropertyTestMaxOps,
        ).generate(rand).value;

        for (var i = 0; i < numActions; i++) {
          final opGen = OperationGenerators.anyOperation(
            model,
            onlyVisible: onlyVisibleBlocks,
          );
          final op = opGen.generate(rand).value;

          await interpreter.execute(ctx, model, op);

          checkInvariants(
            ctx,
            model,
            'Run $runCount - After action ${i + 1} ($op)',
          );
        }
      } catch (e) {
        debugPrint('\nProperty Test Failure in run $runCount');
        rethrow;
      } finally {
        if (tearDown != null) {
          await tearDown(ctx);
        }
      }

      return true;
    },
    [blockGenerator],
    numRuns: kPropertyTestRuns,
  );
}

void checkStructuralInvariants(
  TestContext context,
  OutlinerModel model,
  String testContext,
) {
  final actualModel = OutlinerModel.fromContext(context);

  // Build tree representations for debugging
  final modelTree = _buildTreeRepresentation(
    ModelTreeIterator(model),
    'Model Tree',
  );
  final actualTree = _buildTreeRepresentation(
    BlockTreeIterator(context.blocks),
    'Actual Tree',
  );

  expect(
    actualModel.allBlockIds,
    equals(model.allBlockIds),
    reason:
        '$testContext: Conservation - all blocks should exist\n\n$modelTree\n$actualTree',
  );

  final allActualIds = <String>{};
  _collectAllIds(context.blocks, allActualIds);
  expect(
    allActualIds.length,
    equals(model.allBlockIds.length),
    reason:
        '$testContext: No duplication - each block appears exactly once\n\n$modelTree\n$actualTree',
  );

  for (var blockId in model.allBlockIds) {
    final modelParent = model.parentMap[blockId];
    final actualParent = actualModel.parentMap[blockId];
    expect(
      actualParent,
      equals(modelParent),
      reason:
          '$testContext: Parent relationship for $blockId should match model\n\n$modelTree\n$actualTree',
    );
  }
}

void checkUIInvariants(
  UIContext ctx,
  UIOutlinerModel model,
  String testContext,
) {
  checkStructuralInvariants(ctx, model, testContext);

  final blocks = ctx.blocks;

  // Build tree representations for debugging
  final modelTree = _buildTreeRepresentation(
    ModelTreeIterator(model),
    'Model Tree',
  );
  final actualTree = _buildTreeRepresentation(
    BlockTreeIterator(blocks),
    'Actual Tree',
  );
  final widgetTree = _buildTreeRepresentation(
    WidgetTreeIterator(ctx.tester),
    'Widget Tree',
  );

  for (var blockId in model.allBlockIds) {
    Block? actualBlock;
    for (var rootBlock in blocks) {
      actualBlock = rootBlock.findBlockById(blockId);
      if (actualBlock != null) break;
    }

    if (actualBlock == null) continue;

    // Check content matches
    final modelContent = model.contentMap[blockId] ?? '';
    expect(
      actualBlock.content,
      equals(modelContent),
      reason:
          '$testContext: Content for block $blockId should match model. '
          'Expected "$modelContent", got "${actualBlock.content}"\n\n$modelTree\n$actualTree\n$widgetTree',
    );

    final modelCollapseState = model.collapseStateMap[blockId] ?? false;
    expect(
      actualBlock.isCollapsed,
      equals(modelCollapseState),
      reason:
          '$testContext: Collapse state for $blockId should match model\n\n$modelTree\n$actualTree\n$widgetTree',
    );

    final isVisible = model.isBlockVisible(blockId);
    final hasChildren =
        model.childrenMap.containsKey(blockId) &&
        model.childrenMap[blockId]!.isNotEmpty;

    if (isVisible && hasChildren) {
      final collapseIndicatorFinder = find.byKey(
        ValueKey('collapse-indicator-$blockId'),
        skipOffstage: false,
      );
      expect(
        collapseIndicatorFinder,
        findsOneWidget,
        reason:
            '$testContext: Block $blockId has children and is visible, should have collapse indicator\n\n$modelTree\n$actualTree\n$widgetTree',
      );
    }

    if (actualBlock.isCollapsed && hasChildren) {
      final childIds = model.childrenMap[blockId] ?? [];
      for (var childId in childIds) {
        final childWidgetFinder = find.byWidgetPredicate(
          (widget) => widget is BlockWidget && widget.block.id == childId,
        );
        expect(
          childWidgetFinder,
          findsNothing,
          reason:
              '$testContext: Block $blockId is collapsed, child $childId should not be visible\n\n$modelTree\n$actualTree\n$widgetTree',
        );
      }
    }
  }

  _checkNoUINodeDuplication(
    ctx.tester,
    model,
    testContext,
    modelTree,
    actualTree,
    widgetTree,
  );
}

void _checkNoUINodeDuplication(
  WidgetTester tester,
  UIOutlinerModel model,
  String context,
  String modelTree,
  String actualTree,
  String widgetTree,
) {
  int countVisibleBlocks(String blockId) {
    int count = 1;
    final isCollapsed = model.collapseStateMap[blockId] ?? false;

    if (isCollapsed) return count;

    final children = model.childrenMap[blockId] ?? [];
    for (var childId in children) {
      count += countVisibleBlocks(childId);
    }
    return count;
  }

  int expectedVisibleCount = 0;
  for (var blockId in model.allBlockIds) {
    final parentId = model.parentMap[blockId];
    if (parentId == model.rootId) {
      expectedVisibleCount += countVisibleBlocks(blockId);
    }
  }

  final blockWidgets = find.byType(BlockWidget, skipOffstage: false);
  final widgetCount = blockWidgets.evaluate().length;

  expect(
    widgetCount,
    equals(expectedVisibleCount),
    reason:
        '$context: Found $widgetCount BlockWidgets but expected $expectedVisibleCount visible blocks\n\n'
        '$modelTree\n$actualTree\n$widgetTree',
  );
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
