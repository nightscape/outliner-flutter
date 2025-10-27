import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/models/block.dart';

void main() {
  test('findBlockById correctly identifies descendants', () {
    // Create a hierarchy: Parent -> Child -> Grandchild
    final grandchild = Block.create(content: 'Grandchild', id: 'gc');
    final child = Block.create(content: 'Child', id: 'c', children: [grandchild]);
    final parent = Block.create(content: 'Parent', id: 'p', children: [child]);
    final sibling = Block.create(content: 'Sibling', id: 's');

    // Test: parent.findBlockById should find its descendants
    print('Testing parent.findBlockById(parent.id)');
    expect(parent.findBlockById('p'), isNotNull); // Should find itself
    expect(parent.findBlockById('p')!.id, equals('p'));

    print('Testing parent.findBlockById(child.id)');
    expect(parent.findBlockById('c'), isNotNull); // Should find child
    expect(parent.findBlockById('c')!.id, equals('c'));

    print('Testing parent.findBlockById(grandchild.id)');
    expect(parent.findBlockById('gc'), isNotNull); // Should find grandchild
    expect(parent.findBlockById('gc')!.id, equals('gc'));

    print('Testing parent.findBlockById(sibling.id)');
    expect(parent.findBlockById('s'), isNull); // Should NOT find sibling

    // Test: child.findBlockById should only find itself and its descendants
    print('Testing child.findBlockById(child.id)');
    expect(child.findBlockById('c'), isNotNull); // Should find itself

    print('Testing child.findBlockById(grandchild.id)');
    expect(child.findBlockById('gc'), isNotNull); // Should find grandchild

    print('Testing child.findBlockById(parent.id)');
    expect(child.findBlockById('p'), isNull); // Should NOT find parent

    // THIS IS THE KEY TEST FOR OUR BUG:
    // When dragging parent onto child, we check:
    // _isDescendantOfById(child.id, parent.id)
    // Which translates to: parent.findBlockById(child.id)
    // This SHOULD return non-null (child is a descendant of parent)
    print('\n=== KEY TEST ===');
    print('When dragging parent onto child:');
    print('  parent.findBlockById(child.id) should be non-null');
    final isChildDescendantOfParent = parent.findBlockById('c') != null;
    print('  Result: $isChildDescendantOfParent');
    expect(isChildDescendantOfParent, isTrue);
  });
}
