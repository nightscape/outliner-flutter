import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'package:outliner_view/repositories/in_memory_outliner_repository.dart';
import 'package:outliner_view/widgets/outliner_list_view.dart';
import 'package:outliner_view/widgets/block_widget.dart';

/// Test fixture setup utilities for outliner tests
class OutlinerTestFixture {
  final ProviderContainer container;
  final OutlinerNotifier notifier;
  final String rootId;

  OutlinerTestFixture._(this.container, this.notifier, this.rootId);

  /// Create and initialize a test fixture with optional initial blocks
  static Future<OutlinerTestFixture> create({
    List<Block> initialBlocks = const [],
    String Function()? idGenerator,
  }) async {
    final container = ProviderContainer(
      overrides: [
        outlinerProvider.overrideWith(
          (ref) => OutlinerNotifier(
            InMemoryOutlinerRepository(
              initializeSampleData: false,
              idGenerator: idGenerator,
            ),
          ),
        ),
      ],
    );

    final notifier = container.read(outlinerProvider.notifier);
    await notifier.loadBlocks();

    final rootId = notifier.state.whenOrNull(
      loaded: (rootBlock, _, __, ___) => rootBlock.id,
    );

    if (rootId != null) {
      for (final block in initialBlocks) {
        await notifier.addChildBlock(rootId, block);
      }
    }

    return OutlinerTestFixture._(container, notifier, rootId!);
  }

  void dispose() => container.dispose();
}

/// Widget test utilities for outliner UI tests
class OutlinerWidgetTestUtils {
  final WidgetTester tester;

  OutlinerWidgetTestUtils(this.tester);

  /// Pump the outliner widget with a given container
  Future<void> pumpOutliner(ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              width: 400,
              child: OutlinerListView(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Find a block widget by its ID (returns first match to avoid drag feedback duplicates)
  Finder findBlockById(String blockId) {
    return find.byWidgetPredicate(
      (widget) => widget is BlockWidget && widget.block.id == blockId,
      skipOffstage: false,
    ).first;
  }

  /// Perform a drag gesture from source to target with specified drop zone
  Future<void> performDrag({
    required String sourceBlockId,
    required String targetBlockId,
    required DropZoneType dropZone,
  }) async {
    final sourceFinder = findBlockById(sourceBlockId);
    final targetFinder = findBlockById(targetBlockId);

    await tester.ensureVisible(sourceFinder);
    await tester.pumpAndSettle();
    await tester.ensureVisible(targetFinder);
    await tester.pumpAndSettle();

    final sourceCenter = tester.getCenter(sourceFinder);
    final gesture = await tester.startGesture(sourceCenter);

    // Wait for long press to activate drag
    await tester.pump(const Duration(milliseconds: 600));

    // Calculate drop offset
    final targetRect = tester.getRect(targetFinder);
    final Offset dropOffset = _calculateDropOffset(targetRect, dropZone);

    // Move to drop zone
    await gesture.moveTo(dropOffset);
    await tester.pump(const Duration(milliseconds: 100));

    // Drop
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Offset _calculateDropOffset(Rect targetRect, DropZoneType dropZone) {
    switch (dropZone) {
      case DropZoneType.before:
        return Offset(targetRect.left + 16, targetRect.top + 4);
      case DropZoneType.after:
        return Offset(targetRect.left + 16, targetRect.bottom - 4);
      case DropZoneType.asChild:
        return Offset(targetRect.right - 48, targetRect.center.dy);
    }
  }
}

/// Drop zone types for drag-and-drop operations
enum DropZoneType { before, after, asChild }

/// State verification helpers
extension OutlinerStateAssertions on ProviderContainer {
  /// Assert that a block exists and has the expected structure
  void assertBlockExists(
    String blockId, {
    int? expectedChildCount,
  }) {
    final state = read(outlinerProvider);
    state.whenOrNull(
      loaded: (rootBlock, _, __, ___) {
        final block = rootBlock.findBlockById(blockId);
        expect(block, isNotNull, reason: 'Block $blockId should exist');

        if (expectedChildCount != null) {
          expect(
            block!.children.length,
            equals(expectedChildCount),
            reason: 'Block $blockId should have $expectedChildCount children',
          );
        }
      },
    );
  }

  /// Assert that a block's children match expected IDs in order
  void assertBlockChildren(String blockId, List<String> expectedChildIds) {
    final state = read(outlinerProvider);
    state.whenOrNull(
      loaded: (rootBlock, _, __, ___) {
        final block = rootBlock.findBlockById(blockId);
        expect(block, isNotNull, reason: 'Block $blockId should exist');
        expect(
          block!.children.map((c) => c.id).toList(),
          equals(expectedChildIds),
          reason: 'Block $blockId children should match expected order',
        );
      },
    );
  }

  /// Assert that a block has no children
  void assertBlockHasNoChildren(String blockId) {
    final state = read(outlinerProvider);
    state.whenOrNull(
      loaded: (rootBlock, _, __, ___) {
        final block = rootBlock.findBlockById(blockId);
        expect(block, isNotNull, reason: 'Block $blockId should exist');
        expect(
          block!.children.isEmpty,
          isTrue,
          reason: 'Block $blockId should have no children',
        );
      },
    );
  }
}
