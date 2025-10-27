import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/models/block.dart';
import 'test_helpers.dart';

/// This test verifies that dragging a parent block onto any of its descendant's
/// drop zones is properly rejected and does not cause an error.
///
/// If the validation code in DraggableBlockWidget.onMove is commented out,
/// this test will FAIL because the repository's assertion will fire.
void main() {
  testWidgets(
    'Parent cannot be dropped onto child - all drop zones reject',
    (WidgetTester tester) async {
      // Create a simple hierarchy: Parent -> Child
      final child = Block.create(content: 'Child Block', id: 'test-child');
      final parent = Block.create(
        content: 'Parent Block',
        id: 'test-parent',
        children: [child],
      );

      final fixture = await OutlinerTestFixture.create(initialBlocks: [parent]);
      final utils = OutlinerWidgetTestUtils(tester);
      await utils.pumpOutliner(fixture.container);

      // Test 1: Try to drop parent "before" child
      // (This should be rejected and not cause an error)
      await utils.performDrag(
        sourceBlockId: 'test-parent',
        targetBlockId: 'test-child',
        dropZone: DropZoneType.before,
      );

      // Test 2: Try to drop parent "after" child
      await utils.performDrag(
        sourceBlockId: 'test-parent',
        targetBlockId: 'test-child',
        dropZone: DropZoneType.after,
      );

      // Test 3: Try to drop parent "as child" of child
      await utils.performDrag(
        sourceBlockId: 'test-parent',
        targetBlockId: 'test-child',
        dropZone: DropZoneType.asChild,
      );

      // Verify: The hierarchy should be unchanged
      // If validation worked, drops were rejected and structure is intact
      // If validation failed, repository assertion would have fired above
      fixture.container.assertBlockExists('test-parent', expectedChildCount: 1);
      fixture.container.assertBlockChildren('test-parent', ['test-child']);
      fixture.container.assertBlockHasNoChildren('test-child');

      fixture.dispose();
    },
  );

  testWidgets(
    'Parent cannot be dropped onto grandchild (nested descendant)',
    (WidgetTester tester) async {
      // Create a deeper hierarchy: Parent -> Child -> Grandchild
      final grandchild = Block.create(content: 'Grandchild', id: 'grandchild');
      final child = Block.create(
        content: 'Child',
        id: 'child',
        children: [grandchild],
      );
      final parent = Block.create(
        content: 'Parent',
        id: 'parent',
        children: [child],
      );

      final fixture = await OutlinerTestFixture.create(initialBlocks: [parent]);
      final utils = OutlinerWidgetTestUtils(tester);
      await utils.pumpOutliner(fixture.container);

      // Try to drop parent onto grandchild (a nested descendant)
      // This should also be rejected
      await utils.performDrag(
        sourceBlockId: 'parent',
        targetBlockId: 'grandchild',
        dropZone: DropZoneType.asChild,
      );

      // Verify structure unchanged
      fixture.container.assertBlockChildren('parent', ['child']);
      fixture.container.assertBlockChildren('child', ['grandchild']);

      fixture.dispose();
    },
  );
}