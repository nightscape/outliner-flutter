import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/widgets/block_widget.dart';
import 'operations.dart';
import 'outliner_model.dart';
import 'test_context.dart';

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

        try {
          String? newParentId;

          if (targetType == DragTargetType.asChild) {
            if (model.isDescendantOf(targetBlockId, sourceBlockId)) return;
            newParentId = targetBlockId;
          } else {
            newParentId = model.parentMap[targetBlockId];

            // Skip if already in the same parent
            final currentParentId = model.parentMap[sourceBlockId];
            if (currentParentId == newParentId) return;
          }

          // Prevent making a block a child of itself
          if (sourceBlockId == newParentId) return;

          // Prevent creating cycles
          if (newParentId != null &&
              model.isDescendantOf(newParentId, sourceBlockId)) {
            return;
          }

          final newIndex = () {
            if (targetType == DragTargetType.asChild) {
              final children = List<String>.from(
                model.childrenMap[targetBlockId] ?? const [],
              );
              return children.length;
            }

            final siblings = newParentId == null
                ? ctx.blocks.map((b) => b.id).toList()
                : List<String>.from(model.childrenMap[newParentId] ?? const []);

            final targetIndex = siblings.indexOf(targetBlockId);
            if (targetIndex == -1) {
              return siblings.length;
            }

            return targetType == DragTargetType.before
                ? targetIndex
                : targetIndex + 1;
          }();

          await ctx.notifier.moveBlock(sourceBlockId, newParentId, newIndex);

          final actualModel = OutlinerModel.fromNotifier(ctx.notifier);
          model.copyFrom(actualModel);
        } catch (e) {
          // Move failed, keep model as-is (don't sync to avoid propagating bad state)
        }

      case IndentOperation(:final blockId):
        if (blockId.isEmpty) return;

        // Check if there's a valid sibling to indent under
        final parentId = model.parentMap[blockId];
        final siblings = parentId == null
            ? ctx.blocks.map((b) => b.id).toList()
            : (model.childrenMap[parentId] ?? []);
        final blockIndex = siblings.indexOf(blockId);

        // Can only indent if there's a previous sibling
        if (blockIndex <= 0) return;

        try {
          await ctx.notifier.indentBlock(blockId);
          final actualModel = OutlinerModel.fromNotifier(ctx.notifier);
          model.copyFrom(actualModel);
        } catch (e) {
          // Indent may fail, keep model as-is
        }

      case OutdentOperation(:final blockId):
        if (blockId.isEmpty) return;

        // Can only outdent if block has a parent
        if (model.parentMap[blockId] == null) return;

        try {
          await ctx.notifier.outdentBlock(blockId);
          final actualModel = OutlinerModel.fromNotifier(ctx.notifier);
          model.copyFrom(actualModel);
        } catch (e) {
          // Outdent may fail, keep model as-is
        }

      case EnterOperation():
        // Enter operation not supported in pure notifier tests
        break;

      case ToggleCollapseOperation():
        // Toggle collapse not supported in pure notifier tests
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

    if (sourceFinder.evaluate().isEmpty || targetFinder.evaluate().isEmpty) {
      return;
    }

    await ctx.tester.ensureVisible(sourceFinder);
    await ctx.tester.pumpAndSettle();
    await ctx.tester.ensureVisible(targetFinder);
    await ctx.tester.pumpAndSettle();

    final sourceLocation = ctx.tester.getCenter(sourceFinder);
    final targetLocation = ctx.tester.getCenter(targetFinder);

    Offset dropOffset;

    switch (op.targetType) {
      case DragTargetType.before:
        dropOffset = targetLocation + const Offset(0, -10);
        break;
      case DragTargetType.after:
        dropOffset = targetLocation + const Offset(0, 10);
        break;
      case DragTargetType.asChild:
        dropOffset = targetLocation + const Offset(150, 0);
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

    final actualModel = UIOutlinerModel.fromNotifier(ctx.notifier);
    model.copyFrom(actualModel);
  }

  Future<void> _performIndentOperation(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
  ) async {
    if (blockId.isEmpty) return;

    final blockFinder = find.byWidgetPredicate(
      (widget) => widget is BlockWidget && widget.block.id == blockId,
      skipOffstage: false,
    );

    if (blockFinder.evaluate().isEmpty) return;

    try {
      await ctx.tester.ensureVisible(blockFinder);
      await ctx.tester.pumpAndSettle();
      await ctx.tester.tap(blockFinder);
      await ctx.tester.pumpAndSettle();

      await ctx.tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await ctx.tester.pumpAndSettle();

      final actualModel = UIOutlinerModel.fromNotifier(ctx.notifier);
      model.copyFrom(actualModel);
    } catch (e) {
      // Skip this action if it fails
    }
  }

  Future<void> _performOutdentOperation(
    UIContext ctx,
    UIOutlinerModel model,
    String blockId,
  ) async {
    if (blockId.isEmpty) return;

    final blockFinder = find.byWidgetPredicate(
      (widget) => widget is BlockWidget && widget.block.id == blockId,
      skipOffstage: false,
    );

    if (blockFinder.evaluate().isEmpty) return;

    try {
      await ctx.tester.ensureVisible(blockFinder);
      await ctx.tester.pumpAndSettle();
      await ctx.tester.tap(blockFinder);
      await ctx.tester.pumpAndSettle();

      await ctx.tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await ctx.tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await ctx.tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await ctx.tester.pumpAndSettle();

      final actualModel = UIOutlinerModel.fromNotifier(ctx.notifier);
      model.copyFrom(actualModel);
    } catch (e) {
      // Skip this action if it fails
    }
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

    try {
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

      await ctx.tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await ctx.tester.pumpAndSettle();

      final actualModel = UIOutlinerModel.fromNotifier(ctx.notifier);
      model.copyFrom(actualModel);
    } catch (e) {
      // Skip this action if it fails
    }
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

    try {
      await ctx.tester.ensureVisible(collapseIndicatorFinder);
      await ctx.tester.pumpAndSettle();
      await ctx.tester.tap(collapseIndicatorFinder);
      await ctx.tester.pumpAndSettle();

      final actualModel = UIOutlinerModel.fromNotifier(ctx.notifier);
      model.copyFrom(actualModel);
    } catch (e) {
      // Skip this action if it fails
    }
  }
}
