import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/core/block_ops.dart';
import 'package:outliner_view/widgets/block_widget.dart';
import 'operations.dart';

const double _kChildDropZoneWidth = 96.0;

/// BlockOps implementation that performs operations through the UI layer
/// by simulating actual user interactions (key presses, taps, drags).
///
/// This is used for UI-level property testing to ensure that UI interactions
/// produce the same results as direct repository operations.
class UiBlockOps<T> implements BlockOps<T> {
  final WidgetTester tester;
  final BlockOps<T> _backingOps;
  final String Function()? idGenerator;

  UiBlockOps({
    required this.tester,
    required BlockOps<T> backingOps,
    this.idGenerator,
  }) : _backingOps = backingOps;

  // Read operations that access block object fields directly
  @override
  String getId(T block) => _backingOps.getId(block);

  @override
  DateTime getCreatedAt(T block) => _backingOps.getCreatedAt(block);

  @override
  DateTime getUpdatedAt(T block) => _backingOps.getUpdatedAt(block);

  // Read operations that should come from the UI
  @override
  String getContent(T block) {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);

    if (blockFinder.evaluate().isEmpty) {
      return _backingOps.getContent(block);
    }

    // Try to find TextField (when editing)
    final textFieldFinder = find.descendant(
      of: blockFinder,
      matching: find.byType(TextField),
    );

    if (textFieldFinder.evaluate().isNotEmpty) {
      final textField = tester.widget<TextField>(textFieldFinder.first);
      return textField.controller?.text ?? '';
    }

    // Try to find Text widget (when not editing)
    final textFinder = find.descendant(
      of: blockFinder,
      matching: find.byType(Text),
    );

    if (textFinder.evaluate().isNotEmpty) {
      final text = tester.widget<Text>(textFinder.first);
      final data = text.data ?? text.textSpan?.toPlainText() ?? '';
      // Filter out empty block placeholder text
      if (data == 'Empty block' || data.isEmpty) {
        return '';
      }
      return data;
    }

    return _backingOps.getContent(block);
  }

  @override
  List<T> getChildren(T block) {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);

    if (blockFinder.evaluate().isEmpty) {
      return _backingOps.getChildren(block);
    }

    // Find all child BlockWidget instances
    // They should be descendants of this block widget
    final allBlockWidgets = find.byWidgetPredicate(
      (widget) => widget is BlockWidget,
      skipOffstage: false,
    );

    final children = <T>[];
    for (final element in allBlockWidgets.evaluate()) {
      final childWidget = element.widget as BlockWidget;
      final childBlock = childWidget.block as T;
      final childId = getId(childBlock);

      // Check if this is a direct child by checking if its parent is our block
      // This is a heuristic: a child BlockWidget will be nested inside our BlockWidget
      // but not inside another BlockWidget between us and it
      try {
        final childFinder = find.byWidget(childWidget);
        final ancestors = element.visitAncestorElements((ancestor) {
          if (ancestor.widget is BlockWidget) {
            final ancestorBlock = (ancestor.widget as BlockWidget).block as T;
            final ancestorId = getId(ancestorBlock);
            if (ancestorId == blockId) {
              // Found our block as ancestor, this is a child
              children.add(childBlock);
              return false; // Stop iteration
            } else {
              // Found another block between us and the child, not a direct child
              return false;
            }
          }
          return true; // Continue searching ancestors
        });
      } catch (e) {
        // Skip this block if we can't determine ancestry
      }
    }

    return children;
  }

  @override
  bool getIsCollapsed(T block) {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);

    if (blockFinder.evaluate().isEmpty) {
      return _backingOps.getIsCollapsed(block);
    }

    // Check if the collapse indicator shows collapsed state
    // The collapse indicator CustomPaint should show right-pointing arrow if collapsed
    final collapseIndicatorFinder = find.byKey(
      ValueKey('collapse-indicator-$blockId'),
      skipOffstage: false,
    );

    if (collapseIndicatorFinder.evaluate().isEmpty) {
      // No collapse indicator means no children or it's collapsed
      return _backingOps.getIsCollapsed(block);
    }

    // Check if children are visible by checking if any child widgets exist
    final childrenFromUi = getChildren(block);
    final childrenFromBackingOps = _backingOps.getChildren(block);

    // If backing ops says there are children but UI shows none, it's collapsed
    if (childrenFromBackingOps.isNotEmpty && childrenFromUi.isEmpty) {
      return true;
    }

    return _backingOps.getIsCollapsed(block);
  }

  @override
  List<T> getTopLevelBlocks() {
    // Find all BlockWidgets that are direct children of the outliner root
    final allBlockWidgets = find.byWidgetPredicate(
      (widget) => widget is BlockWidget,
      skipOffstage: false,
    );

    final topLevel = <T>[];

    for (final element in allBlockWidgets.evaluate()) {
      final widget = element.widget as BlockWidget;
      final block = widget.block as T;

      // Check if this block has no BlockWidget parent
      var hasBlockWidgetParent = false;
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is BlockWidget && ancestor.widget != widget) {
          hasBlockWidgetParent = true;
          return false; // Stop iteration
        }
        return true; // Continue searching
      });

      if (!hasBlockWidgetParent) {
        topLevel.add(block);
      }
    }

    return topLevel;
  }

  @override
  bool isDescendantOf(T potentialAncestor, T block) {
    // This is a logical operation, delegate to backing ops
    return _backingOps.isDescendantOf(potentialAncestor, block);
  }

  @override
  Future<T?> findNextVisibleBlock(T block) async {
    // Could potentially traverse widget tree, but complex
    // For now, delegate to backing ops
    return _backingOps.findNextVisibleBlock(block);
  }

  @override
  Future<T?> findPreviousVisibleBlock(T block) async {
    // Could potentially traverse widget tree, but complex
    // For now, delegate to backing ops
    return _backingOps.findPreviousVisibleBlock(block);
  }

  @override
  Future<T?> findParent(T block) async {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);

    if (blockFinder.evaluate().isEmpty) {
      return _backingOps.findParent(block);
    }

    // Find the first ancestor BlockWidget
    final element = blockFinder.evaluate().first;
    T? parent;

    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is BlockWidget) {
        parent = (ancestor.widget as BlockWidget).block as T;
        return false; // Stop iteration
      }
      return true; // Continue searching
    });

    return parent;
  }

  @override
  Future<T?> findBlockById(String blockId) async {
    final blockFinder = _findBlockWidget(blockId);

    if (blockFinder.evaluate().isEmpty) {
      return _backingOps.findBlockById(blockId);
    }

    final widget = tester.widget<BlockWidget>(blockFinder.first);
    return widget.block as T;
  }

  @override
  Future<T> getRootBlock() => _backingOps.getRootBlock();

  @override
  T copyWith(T block, {String? content, List<T>? children, bool? isCollapsed}) =>
      _backingOps.copyWith(
        block,
        content: content,
        children: children,
        isCollapsed: isCollapsed,
      );

  @override
  T create({
    String? id,
    required String content,
    List<T>? children,
    bool? isCollapsed,
  }) =>
      _backingOps.create(
        id: id,
        content: content,
        children: children,
        isCollapsed: isCollapsed,
      );

  @override
  Stream<T> get changeStream => _backingOps.changeStream;

  // UI-based mutation operations

  @override
  Future<void> updateBlock(T block, String content) async {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);
    if (blockFinder.evaluate().isEmpty) return;

    await tester.ensureVisible(blockFinder);
    await tester.pumpAndSettle();
    await tester.tap(blockFinder);
    await tester.pumpAndSettle();

    final textFieldFinder = find.descendant(
      of: blockFinder,
      matching: find.byType(TextField),
    );

    if (textFieldFinder.evaluate().isNotEmpty) {
      await tester.enterText(textFieldFinder, content);
      await tester.pumpAndSettle();
    }
  }

  @override
  Future<void> deleteBlock(T block) async {
    // Delete not implemented in UI yet
    throw UnimplementedError('Delete not implemented in UI');
  }

  @override
  Future<void> moveBlock(T block, T? newParent, int newIndex) async {
    // For UI tests, moveBlock is performed via drag & drop
    // This method is not directly callable from UI interactions
    throw UnimplementedError(
      'moveBlock should be performed via drag & drop in UI tests',
    );
  }

  @override
  Future<void> toggleCollapse(T block) async {
    final blockId = getId(block);
    final collapseIndicatorFinder = find.byKey(
      ValueKey('collapse-indicator-$blockId'),
      skipOffstage: false,
    );

    if (collapseIndicatorFinder.evaluate().isEmpty) return;

    await tester.ensureVisible(collapseIndicatorFinder);
    await tester.pumpAndSettle();
    await tester.tap(collapseIndicatorFinder);
    await tester.pumpAndSettle();
  }

  @override
  Future<void> addChildBlock(T parent, T child) async {
    // Not implemented as direct UI operation
    throw UnimplementedError('addChildBlock not implemented in UI');
  }

  @override
  Future<void> addTopLevelBlock(T block) async {
    // Not implemented as direct UI operation
    throw UnimplementedError('addTopLevelBlock not implemented in UI');
  }

  @override
  Future<String> splitBlock(T block, int cursorPosition) async {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);

    // Predict the new block ID using the deterministic ID generator
    final newBlockId = idGenerator?.call() ?? 'generated-id';

    // Skip if block is not visible (e.g., child of collapsed block)
    if (blockFinder.evaluate().isEmpty) {
      return newBlockId;
    }

    await tester.ensureVisible(blockFinder);
    await tester.pumpAndSettle();
    await tester.tap(blockFinder);
    await tester.pumpAndSettle();

    final textFieldFinder = find.descendant(
      of: blockFinder,
      matching: find.byType(TextField),
    );

    if (textFieldFinder.evaluate().isEmpty) {
      return newBlockId;
    }

    final textField = tester.widget<TextField>(textFieldFinder);
    if (textField.controller == null) {
      return newBlockId;
    }

    // Set cursor position
    textField.controller!.selection = TextSelection.collapsed(
      offset: cursorPosition,
    );
    await tester.pumpAndSettle();

    // Perform the UI operation
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    return newBlockId;
  }

  @override
  Future<void> indentBlock(T block) async {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);
    if (blockFinder.evaluate().isEmpty) return;

    await tester.ensureVisible(blockFinder);
    await tester.pumpAndSettle();
    await tester.tap(blockFinder);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }

  @override
  Future<void> outdentBlock(T block) async {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);
    if (blockFinder.evaluate().isEmpty) return;

    await tester.ensureVisible(blockFinder);
    await tester.pumpAndSettle();
    await tester.tap(blockFinder);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
  }

  Finder _findBlockWidget(String blockId) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is BlockWidget && getId((widget as BlockWidget).block as T) == blockId,
      skipOffstage: false,
    );
  }

  /// Perform a drag operation in the UI
  Future<void> performDrag({
    required T sourceBlock,
    required T targetBlock,
    required DragTargetType targetType,
  }) async {
    final sourceId = getId(sourceBlock);
    final targetId = getId(targetBlock);

    final sourceFinder = _findBlockWidget(sourceId);
    final targetFinder = _findBlockWidget(targetId);

    // Skip if blocks are not visible (e.g., collapsed)
    if (sourceFinder.evaluate().isEmpty) {
      return;
    }
    if (targetFinder.evaluate().isEmpty) {
      return;
    }

    await tester.ensureVisible(sourceFinder);
    await tester.pumpAndSettle();
    await tester.ensureVisible(targetFinder);
    await tester.pumpAndSettle();

    final sourceLocation = tester.getCenter(sourceFinder);
    final targetRect = tester.getRect(targetFinder);

    Offset dropOffset;

    switch (targetType) {
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

    final gesture = await tester.startGesture(sourceLocation);
    await tester.pump(const Duration(milliseconds: 600));

    final opacityFinder = find.ancestor(
      of: sourceFinder,
      matching: find.byType(Opacity),
    );
    if (opacityFinder.evaluate().isNotEmpty) {
      final opacityWidget = tester.widget<Opacity>(opacityFinder.first);
      expect(
        opacityWidget.opacity,
        equals(0.3),
        reason: 'Dragged block should have opacity 0.3',
      );
    }

    await gesture.moveTo(dropOffset);
    await tester.pump(const Duration(milliseconds: 100));

    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Perform arrow up navigation
  Future<void> performArrowUp(T block) async {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);
    if (blockFinder.evaluate().isEmpty) return;

    await tester.ensureVisible(blockFinder);
    await tester.pumpAndSettle();
    await tester.tap(blockFinder);
    await tester.pumpAndSettle();

    final textFieldFinder = find.descendant(
      of: blockFinder,
      matching: find.byType(TextField),
    );

    if (textFieldFinder.evaluate().isEmpty) return;

    final textField = tester.widget<TextField>(textFieldFinder);
    if (textField.controller == null) return;

    textField.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
  }

  /// Perform arrow down navigation
  Future<void> performArrowDown(T block) async {
    final blockId = getId(block);
    final blockFinder = _findBlockWidget(blockId);
    if (blockFinder.evaluate().isEmpty) return;

    await tester.ensureVisible(blockFinder);
    await tester.pumpAndSettle();
    await tester.tap(blockFinder);
    await tester.pumpAndSettle();

    final textFieldFinder = find.descendant(
      of: blockFinder,
      matching: find.byType(TextField),
    );

    if (textFieldFinder.evaluate().isEmpty) return;

    final textField = tester.widget<TextField>(textFieldFinder);
    if (textField.controller == null) return;

    textField.controller!.selection = TextSelection.collapsed(
      offset: textField.controller!.text.length,
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
  }
}
