import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/widgets/block_widget.dart';
import 'operation_generators.dart';
import 'operation_interpreter.dart';
import 'outliner_model.dart';
import 'test_context.dart';

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

  expect(
    actualModel.allBlockIds,
    equals(model.allBlockIds),
    reason: '$testContext: Conservation - all blocks should exist',
  );

  final allActualIds = <String>{};
  _collectAllIds(context.blocks, allActualIds);
  expect(
    allActualIds.length,
    equals(model.allBlockIds.length),
    reason: '$testContext: No duplication - each block appears exactly once',
  );

  for (var blockId in model.allBlockIds) {
    final modelParent = model.parentMap[blockId];
    final actualParent = actualModel.parentMap[blockId];
    expect(
      actualParent,
      equals(modelParent),
      reason:
          '$testContext: Parent relationship for $blockId should match model',
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
  for (var blockId in model.allBlockIds) {
    Block? actualBlock;
    for (var rootBlock in blocks) {
      actualBlock = rootBlock.findBlockById(blockId);
      if (actualBlock != null) break;
    }

    if (actualBlock == null) continue;

    final modelCollapseState = model.collapseStateMap[blockId] ?? false;
    expect(
      actualBlock.isCollapsed,
      equals(modelCollapseState),
      reason: '$testContext: Collapse state for $blockId should match model',
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
            '$testContext: Block $blockId has children and is visible, should have collapse indicator',
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
              '$testContext: Block $blockId is collapsed, child $childId should not be visible',
        );
      }
    }
  }

  _checkNoUINodeDuplication(ctx.tester, model, testContext);
}

void _checkNoUINodeDuplication(
  WidgetTester tester,
  UIOutlinerModel model,
  String context,
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
    if (model.parentMap[blockId] == null) {
      expectedVisibleCount += countVisibleBlocks(blockId);
    }
  }

  final blockWidgets = find.byType(BlockWidget, skipOffstage: false);
  final widgetCount = blockWidgets.evaluate().length;

  expect(
    widgetCount,
    equals(expectedVisibleCount),
    reason:
        '$context: Found $widgetCount BlockWidgets but expected $expectedVisibleCount visible blocks',
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
