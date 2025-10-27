import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/widgets/block_widget.dart';
import 'operations.dart';
import 'outliner_model.dart';
import 'test_context.dart';

const double _kChildDropZoneWidth = 96.0;

abstract class OperationInterpreter<
  C extends TestContext,
  M extends OutlinerModel
> {
  Future<void> execute(C context, M model, Operation op);
}

class NotifierInterpreter
    extends OperationInterpreter<NotifierContext, OutlinerModel> {
  @override
  Future<void> execute(
    NotifierContext ctx,
    OutlinerModel model,
    Operation op,
  ) async {
    switch (op) {
      case DragOperation(
        :final sourceBlockId,
        :final targetBlockId,
        :final targetType,
      ):
        if (sourceBlockId.isEmpty || targetBlockId.isEmpty) return;

        // Skip drag operations that are essentially noops
        if (sourceBlockId == targetBlockId) return;

        String newParentId;

        if (targetType == DragTargetType.asChild) {
          if (model.isDescendantOf(targetBlockId, sourceBlockId)) return;
          newParentId = targetBlockId;
        } else {
          final parentFromModel = model.parentMap[targetBlockId];
          newParentId = parentFromModel ?? model.rootId;

          // Skip if already in the same parent
          final currentParentId = model.parentMap[sourceBlockId];
          if (currentParentId == newParentId) return;
        }

        // Prevent making a block a child of itself
        if (sourceBlockId == newParentId) return;

        // Prevent creating cycles
        if (model.isDescendantOf(newParentId, sourceBlockId)) {
          return;
        }

        final newIndex = () {
          if (targetType == DragTargetType.asChild) {
            final children = List<String>.from(
              model.childrenMap[targetBlockId] ?? const [],
            );
            return children.length;
          }

          final siblings = List<String>.from(
            model.childrenMap[newParentId] ?? const [],
          );

          final targetIndex = siblings.indexOf(targetBlockId);
          if (targetIndex == -1) {
            return siblings.length;
          }

          return targetType == DragTargetType.before
              ? targetIndex
              : targetIndex + 1;
        }();

        await ctx.notifier.moveBlock(sourceBlockId, newParentId, newIndex);
        model.moveBlock(sourceBlockId, newParentId, newIndex);

      case IndentOperation(:final blockId):
        if (blockId.isEmpty) return;

        // Check if there's a valid sibling to indent under
        final parentId = model.parentMap[blockId];
        final siblings = model.childrenMap[parentId] ?? [];
        final blockIndex = siblings.indexOf(blockId);

        // Can only indent if there's a previous sibling
        if (blockIndex <= 0) return;

        await ctx.notifier.indentBlock(blockId);
        model.indentBlock(blockId);

      case OutdentOperation(:final blockId):
        if (blockId.isEmpty) return;

        // Can only outdent if block has a parent
        if (model.parentMap[blockId] == null) return;

        await ctx.notifier.outdentBlock(blockId);
        model.outdentBlock(blockId);

      case EnterOperation():
        // Enter operation not supported in pure notifier tests
        break;

      case ToggleCollapseOperation():
        // Toggle collapse not supported in pure notifier tests
        break;

      case ArrowUpOperation():
        // Arrow navigation not supported in pure notifier tests (requires cursor position)
        break;

      case ArrowDownOperation():
        // Arrow navigation not supported in pure notifier tests (requires cursor position)
        break;
    }
  }
}

class UIInterpreter extends OperationInterpreter<UIContext, UIOutlinerModel> {
  @override
  Future<void> execute(
    UIContext ctx,
    UIOutlinerModel model,
    Operation op,
  ) async {
    switch (op) {
      case DragOperation op:
        await _performDragOperation(ctx, model, op);

      case IndentOperation(:final blockId):
        await _performIndentOperation(ctx, model, blockId);

      case OutdentOperation(:final blockId):
        await _performOutdentOperation(ctx, model, blockId);

      case EnterOperation(:final blockId, :final cursorPosition):
        await _performEnterOperation(ctx, model, blockId, cursorPosition);

      case ToggleCollapseOperation(:final blockId):
        await _performToggleCollapseOperation(ctx, model, blockId);

      case ArrowUpOperation(:final blockId):
        await _performArrowUpOperation(ctx, model, blockId);

      case ArrowDownOperation(:final blockId):
        await _performArrowDownOperation(ctx, model, blockId);
    }
  }

  Future<void> _performDragOperation(
    UIContext ctx,
    UIOutlinerModel model,
    DragOperation op,
  ) async {
    if (op.sourceBlockId.isEmpty || op.targetBlockId.isEmpty) return;

    final sourceFinder = find.byWidgetPredicate(
      (widget) => widget is BlockWidget && widget.block.id == op.sourceBlockId,
      skipOffstage: false,
    );
    final targetFinder = find.byWidgetPredicate(
      (widget) => widget is BlockWidget && widget.block.id == op.targetBlockId,
      skipOffstage: false,
    );

    assert(
      sourceFinder.evaluate().isNotEmpty,
      'Source block widget not found: ${op.sourceBlockId}. '
      'Generator should only produce operations on visible blocks.',
    );
    assert(
      targetFinder.evaluate().isNotEmpty,
      'Target block widget not found: ${op.targetBlockId}. '
      'Generator should only produce operations on visible blocks.',
    );

    await ctx.tester.ensureVisible(sourceFinder);
    await ctx.tester.pumpAndSettle();
    await ctx.tester.ensureVisible(targetFinder);
    await ctx.tester.pumpAndSettle();

    final sourceLocation = ctx.tester.getCenter(sourceFinder);
    final targetLocation = ctx.tester.getCenter(targetFinder);
    final targetRect = ctx.tester.getRect(targetFinder);

    Offset dropOffset;

    switch (op.targetType) {
      case DragTargetType.before:
        dropOffset = Offset(
          targetRect.left + 16,
          targetRect.top + 4,
        );
        break;
      case DragTargetType.after:
        dropOffset = Offset(
          targetRect.left + 16,
          targetRect.bottom - 4,
        );
        break;
      case DragTargetType.asChild:
        final rightEdge = targetRect.right;
        dropOffset = Offset(
          rightEdge - (_kChildDropZoneWidth / 2),
          targetRect.center.dy,
        );
        break;
    }

    final gesture = await ctx.tester.startGesture(sourceLocation);
    await ctx.tester.pump(const Duration(milliseconds: 600));

    final opacityFinder = find.ancestor(
      of: sourceFinder,
      matching: find.byType(Opacity),
    );
    if (opacityFinder.evaluate().isNotEmpty) {
      final opacityWidget = ctx.tester.widget<Opacity>(opacityFinder.first);
      expect(
        opacityWidget.opacity,
        equals(0.3),
        reason: 'Dragged block should have opacity 0.3',
      );
    }

    await gesture.moveTo(dropOffset);
    await ctx.tester.pump(const Duration(milliseconds: 100));

    await gesture.up();
    await ctx.tester.pumpAndSettle();

    // Validate the drop would be accepted by the UI
    // UI validation: For "asChild", reject if target is a descendant of source
    // For "before/after", UI only checks if blocks are different (repository handles complex validation)

    // Skip drag if target is the source
    if (op.sourceBlockId == op.targetBlockId) return;

    // For asChild: check if target is a descendant of source (UI validation)
    if (op.targetType == DragTargetType.asChild) {
      if (model.isDescendantOf(op.targetBlockId, op.sourceBlockId)) {
        debugPrint(
          'Drag: ${op.sourceBlockId} -> ${op.targetType} ${op.targetBlockId} REJECTED (target is descendant)',
        );
        return;
      }
    }

    // Calculate the new parent and index
    String newParentId;
    int newIndex;

    if (op.targetType == DragTargetType.asChild) {
      newParentId = op.targetBlockId;
      final children = model.childrenMap[newParentId] ?? [];
      newIndex = children.length;
    } else {
      final parentFromModel = model.parentMap[op.targetBlockId];
      newParentId = parentFromModel ?? model.rootId;
      final siblings = model.childrenMap[newParentId] ?? [];
      final targetIndex = siblings.indexOf(op.targetBlockId);
      newIndex = op.targetType == DragTargetType.before
          ? targetIndex
          : targetIndex + 1;
    }

    debugPrint(
      'Drag: ${op.sourceBlockId} -> ${op.targetType} ${op.targetBlockId}',
    );
    debugPrint(
      '  Target ${op.targetBlockId} has parent: ${model.parentMap[op.targetBlockId]}',
    );
    debugPrint(
      '  Source ${op.sourceBlockId} has parent: ${model.parentMap[op.sourceBlockId]}',
    );
    debugPrint('  Calculated newParent=$newParentId, newIndex=$newIndex');

    model.moveBlock(op.sourceBlockId, newParentId, newIndex);

    debugPrint('  Model after: parent=${model.parentMap[op.sourceBlockId]}');
  }

  Future<void> _performBlockOperation(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
    Future<void> Function(WidgetTester) performAction,
    void Function() updateModel,
  ) async {
    if (blockId.isEmpty) return;

    final blockFinder = find.byWidgetPredicate(
      (widget) => widget is BlockWidget && widget.block.id == blockId,
      skipOffstage: false,
    );

    if (blockFinder.evaluate().isEmpty) return;

    await ctx.tester.ensureVisible(blockFinder);
    await ctx.tester.pumpAndSettle();
    await ctx.tester.tap(blockFinder);
    await ctx.tester.pumpAndSettle();

    await performAction(ctx.tester);
    await ctx.tester.pumpAndSettle();

    updateModel();
  }

  Future<void> _performIndentOperation(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
  ) async {
    await _performBlockOperation(
      ctx,
      model,
      blockId,
      (tester) => tester.sendKeyEvent(LogicalKeyboardKey.tab),
      () => model.indentBlock(blockId),
    );
  }

  Future<void> _performOutdentOperation(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
  ) async {
    await _performBlockOperation(ctx, model, blockId, (tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    }, () => model.outdentBlock(blockId));
  }

  Future<void> _performEnterOperation(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
    int positionType,
  ) async {
    if (blockId.isEmpty) return;

    final blockFinder = find.byWidgetPredicate(
      (widget) => widget is BlockWidget && widget.block.id == blockId,
      skipOffstage: false,
    );

    if (blockFinder.evaluate().isEmpty) return;

    await ctx.tester.ensureVisible(blockFinder);
    await ctx.tester.pumpAndSettle();
    await ctx.tester.tap(blockFinder);
    await ctx.tester.pumpAndSettle();

    final textFieldFinder = find.descendant(
      of: blockFinder,
      matching: find.byType(TextField),
    );

    if (textFieldFinder.evaluate().isEmpty) return;

    final textField = ctx.tester.widget<TextField>(textFieldFinder);
    if (textField.controller == null) return;

    final text = textField.controller!.text;
    int cursorPosition;

    switch (positionType) {
      case 0: // Start
        cursorPosition = 0;
        break;
      case 1: // Middle
        cursorPosition = text.length ~/ 2;
        break;
      case 2: // End
        cursorPosition = text.length;
        break;
      default:
        cursorPosition = 0;
    }

    textField.controller!.selection = TextSelection.collapsed(
      offset: cursorPosition,
    );
    await ctx.tester.pumpAndSettle();

    // Predict the new block ID using the deterministic ID generator
    final newBlockId = ctx.idGenerator.next();

    debugPrint('Enter: splitting $blockId at position $cursorPosition');
    debugPrint('  Content before split: ${model.contentMap[blockId]}');
    debugPrint('  New block ID: $newBlockId');

    // Perform the UI operation
    await ctx.tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await ctx.tester.pumpAndSettle();

    // Update model to match
    model.splitBlock(blockId, newBlockId, cursorPosition);

    debugPrint(
      '  After split - original content: ${model.contentMap[blockId]}',
    );
    debugPrint(
      '  After split - new block content: ${model.contentMap[newBlockId]}',
    );
  }

  Future<void> _performToggleCollapseOperation(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
  ) async {
    if (blockId.isEmpty) return;

    final collapseIndicatorFinder = find.byKey(
      ValueKey('collapse-indicator-$blockId'),
      skipOffstage: false,
    );

    if (collapseIndicatorFinder.evaluate().isEmpty) return;

    await ctx.tester.ensureVisible(collapseIndicatorFinder);
    await ctx.tester.pumpAndSettle();
    await ctx.tester.tap(collapseIndicatorFinder);
    await ctx.tester.pumpAndSettle();

    model.toggleCollapse(blockId);
  }

  Future<void> _performKeyboardOperationOnBlock(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
    void Function(TextEditingController) setCursorPosition,
    LogicalKeyboardKey key,
  ) async {
    if (blockId.isEmpty) return;

    final blockFinder = find.byWidgetPredicate(
      (widget) => widget is BlockWidget && widget.block.id == blockId,
      skipOffstage: false,
    );

    if (blockFinder.evaluate().isEmpty) return;

    await ctx.tester.ensureVisible(blockFinder);
    await ctx.tester.pumpAndSettle();
    await ctx.tester.tap(blockFinder);
    await ctx.tester.pumpAndSettle();

    final textFieldFinder = find.descendant(
      of: blockFinder,
      matching: find.byType(TextField),
    );

    if (textFieldFinder.evaluate().isEmpty) return;

    final textField = ctx.tester.widget<TextField>(textFieldFinder);
    if (textField.controller == null) return;

    setCursorPosition(textField.controller!);
    await ctx.tester.pumpAndSettle();

    await ctx.tester.sendKeyEvent(key);
    await ctx.tester.pumpAndSettle();

    // Arrow keys don't change structure, only focus
  }

  Future<void> _performArrowUpOperation(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
  ) async {
    await _performKeyboardOperationOnBlock(
      ctx,
      model,
      blockId,
      (controller) =>
          controller.selection = const TextSelection.collapsed(offset: 0),
      LogicalKeyboardKey.arrowUp,
    );
  }

  Future<void> _performArrowDownOperation(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
  ) async {
    await _performKeyboardOperationOnBlock(
      ctx,
      model,
      blockId,
      (controller) => controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      ),
      LogicalKeyboardKey.arrowDown,
    );
  }
}
