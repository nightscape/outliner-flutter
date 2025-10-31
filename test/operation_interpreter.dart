import 'package:flutter_test/flutter_test.dart';
import 'operations.dart';
import 'test_context.dart';
import 'ui_block_ops.dart';

abstract class OperationInterpreter<T, C extends TestContext<T>> {
  Future<void> execute(C context, Operation<T> op);
}

class NotifierInterpreter<T> extends OperationInterpreter<T, NotifierContext<T>> {
  @override
  Future<void> execute(
    NotifierContext<T> ctx,
    Operation<T> op,
  ) async {
    // Get blocks from reference repo to apply operations
    final refOps = ctx.referenceRepo;
    final sutOps = ctx.notifier.ops;

    switch (op) {
      case DragOperation<T>(
        :final sourceBlock,
        :final targetBlock,
        :final targetType,
      ):
        // Find corresponding blocks in reference repo by ID
        final sourceId = sutOps.getId(sourceBlock);
        final targetId = sutOps.getId(targetBlock);

        final refSource = await refOps.findBlockById(sourceId);
        final refTarget = await refOps.findBlockById(targetId);

        if (refSource == null || refTarget == null) return;

        // Calculate new parent and index
        T? newParent;
        int newIndex;

        if (targetType == DragTargetType.asChild) {
          newParent = refTarget;
          newIndex = refOps.getChildren(refTarget).length;
        } else {
          newParent = await refOps.findParent(refTarget);
          final siblings = newParent != null
              ? refOps.getChildren(newParent)
              : await ctx.referenceBlocks;
          final targetIndex =
              siblings.indexWhere((b) => refOps.getId(b) == targetId);
          newIndex = targetType == DragTargetType.before
              ? targetIndex
              : targetIndex + 1;
        }

        // Apply to reference repo
        await refOps.moveBlock(refSource, newParent, newIndex);

        // Apply to SUT
        final sutNewParent = newParent != null
            ? await sutOps.findBlockById(refOps.getId(newParent))
            : null;
        await ctx.notifier.moveBlock(sourceBlock, sutNewParent, newIndex);

      case IndentOperation<T>(:final block):
        final blockId = sutOps.getId(block);
        final refBlock = await refOps.findBlockById(blockId);
        if (refBlock == null) return;

        // Apply to reference repo
        await refOps.indentBlock(refBlock);

        // Apply to SUT
        await ctx.notifier.indentBlock(block);

      case OutdentOperation<T>(:final block):
        final blockId = sutOps.getId(block);
        final refBlock = await refOps.findBlockById(blockId);
        if (refBlock == null) return;

        // Apply to reference repo
        await refOps.outdentBlock(refBlock);

        // Apply to SUT
        await ctx.notifier.outdentBlock(block);

      case EnterOperation():
        // Enter operation not supported in pure notifier tests
        break;

      case ToggleCollapseOperation<T>(:final block):
        final blockId = sutOps.getId(block);
        final refBlock = await refOps.findBlockById(blockId);
        if (refBlock == null) return;

        // Apply to reference repo
        await refOps.toggleCollapse(refBlock);

        // Apply to SUT
        await sutOps.toggleCollapse(block);

      case ArrowUpOperation():
        // Arrow navigation not supported in pure notifier tests
        break;

      case ArrowDownOperation():
        // Arrow navigation not supported in pure notifier tests
        break;
    }
  }
}

class UIInterpreter<T> extends OperationInterpreter<T, UIContext<T>> {
  @override
  Future<void> execute(
    UIContext<T> ctx,
    Operation<T> op,
  ) async {
    // Get blocks from reference repo to apply operations
    final refOps = ctx.referenceRepo;
    final sutOps = ctx.notifier.ops;

    // Create UI-based BlockOps for performing operations through the UI
    final uiOps = UiBlockOps<T>(
      tester: ctx.tester,
      backingOps: sutOps,
      idGenerator: ctx.idGenerator.next,
    );

    switch (op) {
      case DragOperation<T>(
        :final sourceBlock,
        :final targetBlock,
        :final targetType,
      ):
        // Find corresponding blocks in reference repo by ID
        final sourceId = sutOps.getId(sourceBlock);
        final targetId = sutOps.getId(targetBlock);

        final refSource = await refOps.findBlockById(sourceId);
        final refTarget = await refOps.findBlockById(targetId);

        if (refSource == null || refTarget == null) return;

        // Calculate new parent and index
        T? newParent;
        int newIndex;

        if (targetType == DragTargetType.asChild) {
          newParent = refTarget;
          newIndex = refOps.getChildren(refTarget).length;
        } else {
          newParent = await refOps.findParent(refTarget);
          final siblings = newParent != null
              ? refOps.getChildren(newParent)
              : await ctx.referenceBlocks;
          final targetIndex =
              siblings.indexWhere((b) => refOps.getId(b) == targetId);
          newIndex = targetType == DragTargetType.before
              ? targetIndex
              : targetIndex + 1;
        }

        // Apply to reference repo
        await refOps.moveBlock(refSource, newParent, newIndex);

        // Apply to SUT via UI
        await uiOps.performDrag(
          sourceBlock: sourceBlock,
          targetBlock: targetBlock,
          targetType: targetType,
        );

      case IndentOperation<T>(:final block):
        final blockId = sutOps.getId(block);
        final refBlock = await refOps.findBlockById(blockId);
        if (refBlock == null) return;

        // Apply to reference repo
        await refOps.indentBlock(refBlock);

        // Apply to SUT via UI
        await uiOps.indentBlock(block);

      case OutdentOperation<T>(:final block):
        final blockId = sutOps.getId(block);
        final refBlock = await refOps.findBlockById(blockId);
        if (refBlock == null) return;

        // Apply to reference repo
        await refOps.outdentBlock(refBlock);

        // Apply to SUT via UI
        await uiOps.outdentBlock(block);

      case EnterOperation<T>(:final block, :final cursorPosition):
        final blockId = sutOps.getId(block);
        final refBlock = await refOps.findBlockById(blockId);
        if (refBlock == null) return;

        // Apply to reference repo
        await refOps.splitBlock(refBlock, cursorPosition);

        // Apply to SUT via UI
        await uiOps.splitBlock(block, cursorPosition);

      case ToggleCollapseOperation<T>(:final block):
        final blockId = sutOps.getId(block);
        final refBlock = await refOps.findBlockById(blockId);
        if (refBlock == null) return;

        // Apply to reference repo
        await refOps.toggleCollapse(refBlock);

        // Apply to SUT via UI
        await uiOps.toggleCollapse(block);

      case ArrowUpOperation<T>(:final block):
        // Arrow navigation only affects focus, not structure
        await uiOps.performArrowUp(block);

      case ArrowDownOperation<T>(:final block):
        // Arrow navigation only affects focus, not structure
        await uiOps.performArrowDown(block);
    }
  }
}
