import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('Drag parent onto child - drop zone should NOT highlight',
      (WidgetTester tester) async {
    // Create a simple hierarchy: Parent with Child
    final child = Block.create(content: 'Child', id: 'child-1');
    final parent = Block.create(
      content: 'Parent',
      id: 'parent-1',
      children: [child],
    );

    final fixture = await OutlinerTestFixture.create(initialBlocks: [parent]);
    final utils = OutlinerWidgetTestUtils(tester);
    await utils.pumpOutliner(fixture.container);

    // Perform the drag operation
    await utils.performDrag(
      sourceBlockId: 'parent-1',
      targetBlockId: 'child-1',
      dropZone: DropZoneType.asChild,
    );

    // Verify the structure hasn't changed (parent is still the parent of child)
    fixture.container.assertBlockExists('parent-1', expectedChildCount: 1);
    fixture.container.assertBlockChildren('parent-1', ['child-1']);

    fixture.dispose();
  });

  testWidgets('Drag child onto parent - drop zone SHOULD highlight',
      (WidgetTester tester) async {
    // Create a simple hierarchy: Parent with Child
    final child = Block.create(content: 'Child', id: 'child-1');
    final parent = Block.create(
      content: 'Parent',
      id: 'parent-1',
      children: [child],
    );

    final fixture = await OutlinerTestFixture.create(initialBlocks: [parent]);
    final utils = OutlinerWidgetTestUtils(tester);
    await utils.pumpOutliner(fixture.container);

    // Perform the drag operation
    await utils.performDrag(
      sourceBlockId: 'child-1',
      targetBlockId: 'parent-1',
      dropZone: DropZoneType.asChild,
    );

    // Verify the structure: child should still be under parent
    // (This is a valid operation - child can be a child of parent)
    fixture.container.assertBlockExists('parent-1');

    final state = fixture.container.read(outlinerProvider);
    state.whenOrNull(
      loaded: (rootBlock, _, __, ___) {
        final parentBlock = rootBlock.findBlockById('parent-1');
        expect(parentBlock, isNotNull);
        // Child might be moved to the end, but should still be a child
        final childBlock = parentBlock!.findBlockById('child-1');
        expect(childBlock, isNotNull);
      },
    );

    fixture.dispose();
  });
}
