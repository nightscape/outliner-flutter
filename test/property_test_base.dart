import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:outliner_view/core/block_ops.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/widgets/block_widget.dart';
import 'operation_generators.dart';
import 'operation_interpreter.dart';
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

/// Helper to create tree iterator from BlockOps
class _BlockOpsTreeIterator<T> {
  final BlockOps<T> ops;
  final List<T> blocks;

  _BlockOpsTreeIterator(this.ops, this.blocks);

  Future<TreeIterator> getIterator() async {
    final nodes = await Future.wait(blocks.map((block) => _buildNode(block)));
    return _SyncTreeIterator(nodes);
  }

  Future<TreeNode> _buildNode(T block) async {
    final children = await Future.wait(
      ops.getChildren(block).map((child) => _buildNode(child)),
    );
    return TreeNode(ops.getId(block), ops.getIsCollapsed(block), children);
  }
}

/// Synchronous tree iterator
class _SyncTreeIterator implements TreeIterator {
  final List<TreeNode> _roots;

  _SyncTreeIterator(this._roots);

  @override
  Iterable<TreeNode> get roots => _roots;
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

Future<void> runPropertyTest<T, C extends TestContext<T>>({
  required Generator<List<Block>> blockGenerator,
  required Future<C> Function(List<Block>) createContext,
  required OperationInterpreter<T, C> interpreter,
  required void Function(C, String) checkInvariants,
  required Future<void> Function(C)? tearDown,
  bool includeUIOperations = false,
}) async {
  int runCount = 0;

  await forAllAsync(
    (List<Block> initialBlocks) async {
      runCount++;
      if (runCount % 10 == 0) {
        debugPrint('Property Test: Run $runCount/$kPropertyTestRuns');
      }

      final ctx = await createContext(initialBlocks);

      checkInvariants(ctx, 'Run $runCount - Initial');

      try {
        final rand = Random();
        final numActions = Gen.interval(
          kPropertyTestMinOps,
          kPropertyTestMaxOps,
        ).generate(rand).value;

        for (var i = 0; i < numActions; i++) {
          final opGen = OperationGenerators<T>(
            ctx,
            includeUIOperations: includeUIOperations,
          ).anyOperation();
          final op = opGen.generate(rand).value;

          await interpreter.execute(ctx, op);

          checkInvariants(
            ctx,
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

Future<void> checkStructuralInvariants<T>(
  TestContext<T> context,
  String testContext,
) async {
  final refOps = context.referenceRepo;
  final sutOps = context.ops;

  // Get blocks from both sides
  final refBlocks = await context.referenceBlocks;
  final sutBlocks = context.blocks;

  // Build tree representations for debugging
  final refTree = _buildTreeRepresentation(
    await _BlockOpsTreeIterator(refOps, refBlocks).getIterator(),
    'Reference Tree',
  );
  final sutTree = _buildTreeRepresentation(
    await _BlockOpsTreeIterator(sutOps, sutBlocks).getIterator(),
    'SUT Tree',
  );

  // Collect all IDs from both sides
  final refIds = <String>{};
  await _collectAllIdsFromOps(refBlocks, refOps, refIds);

  final sutIds = <String>{};
  await _collectAllIdsFromOps(sutBlocks, sutOps, sutIds);

  expect(
    sutIds,
    equals(refIds),
    reason:
        '$testContext: All blocks should exist in both trees\n\n$refTree\n$sutTree',
  );

  // Check parent relationships match
  for (var blockId in sutIds) {
    final refBlock = await refOps.findBlockById(blockId);
    final sutBlock = await sutOps.findBlockById(blockId);

    if (refBlock == null || sutBlock == null) continue;

    final refParent = await refOps.findParent(refBlock);
    final sutParent = await sutOps.findParent(sutBlock);

    final refParentId = refParent != null ? refOps.getId(refParent) : null;
    final sutParentId = sutParent != null ? sutOps.getId(sutParent) : null;

    if (sutParentId != refParentId) {
      print('DEBUG: Block $blockId has mismatched parents:');
      print('  SUT parent ID: $sutParentId');
      print('  Ref parent ID: $refParentId');
      print('  SUT root ID: ${sutOps.getId(await sutOps.getRootBlock())}');
      print('  Ref root ID: ${refOps.getId(await refOps.getRootBlock())}');
    }

    expect(
      sutParentId,
      equals(refParentId),
      reason:
          '$testContext: Parent relationship for $blockId should match\n\n$refTree\n$sutTree',
    );
  }
}

// For UI tests, we use the same structural invariants check
// The UI is driven by the notifier, so if the notifier's state matches
// the reference, the UI should reflect that.

Future<void> _collectAllIdsFromOps<T>(
  List<T> blocks,
  BlockOps<T> ops,
  Set<String> ids,
) async {
  for (var block in blocks) {
    final id = ops.getId(block);
    expect(
      ids.contains(id),
      isFalse,
      reason: 'Block $id appears multiple times in tree',
    );
    ids.add(id);
    await _collectAllIdsFromOps(ops.getChildren(block), ops, ids);
  }
}
