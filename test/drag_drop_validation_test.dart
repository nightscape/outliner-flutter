import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/models/block.dart';

/// Tests the descendant checking logic used in drag & drop validation.
///
/// The logic is: a block B is a descendant of block A if:
/// - B is the same as A, OR
/// - B is found anywhere in A's children tree
bool isDescendantOf(Block potential, Block ancestor) {
  if (potential.id == ancestor.id) return true;
  for (var child in ancestor.children) {
    if (isDescendantOf(potential, child)) return true;
  }
  return false;
}

void main() {
  group('Drag & Drop Validation - isDescendantOf', () {
    test('returns true when blocks are the same', () {
      final block = Block.create(content: 'A');
      expect(isDescendantOf(block, block), isTrue);
    });

    test('returns true when potential is a direct child', () {
      final child = Block.create(content: 'B');
      final parent = Block.create(content: 'A', children: [child]);

      expect(isDescendantOf(child, parent), isTrue);
    });

    test('returns true when potential is a nested descendant', () {
      final grandchild = Block.create(content: 'C');
      final child = Block.create(content: 'B', children: [grandchild]);
      final parent = Block.create(content: 'A', children: [child]);

      expect(isDescendantOf(grandchild, parent), isTrue);
      expect(isDescendantOf(child, parent), isTrue);
    });

    test('returns false when blocks are unrelated', () {
      final blockA = Block.create(content: 'A');
      final blockB = Block.create(content: 'B');

      expect(isDescendantOf(blockA, blockB), isFalse);
      expect(isDescendantOf(blockB, blockA), isFalse);
    });

    test('returns false when potential is an ancestor (opposite direction)', () {
      final child = Block.create(content: 'B');
      final parent = Block.create(content: 'A', children: [child]);

      expect(isDescendantOf(parent, child), isFalse);
    });

    test('returns false for siblings', () {
      final child1 = Block.create(content: 'B');
      final child2 = Block.create(content: 'C');
      final parent = Block.create(content: 'A', children: [child1, child2]);

      expect(isDescendantOf(child1, child2), isFalse);
      expect(isDescendantOf(child2, child1), isFalse);
    });

    test('returns true for complex nested structure', () {
      //     A
      //    / \
      //   B   C
      //  /   / \
      // D   E   F

      final d = Block.create(content: 'D');
      final b = Block.create(content: 'B', children: [d]);
      final e = Block.create(content: 'E');
      final f = Block.create(content: 'F');
      final c = Block.create(content: 'C', children: [e, f]);
      final a = Block.create(content: 'A', children: [b, c]);

      // All descendants of A
      expect(isDescendantOf(b, a), isTrue);
      expect(isDescendantOf(c, a), isTrue);
      expect(isDescendantOf(d, a), isTrue);
      expect(isDescendantOf(e, a), isTrue);
      expect(isDescendantOf(f, a), isTrue);

      // Descendants of B
      expect(isDescendantOf(d, b), isTrue);
      expect(isDescendantOf(c, b), isFalse);

      // Descendants of C
      expect(isDescendantOf(e, c), isTrue);
      expect(isDescendantOf(f, c), isTrue);
      expect(isDescendantOf(d, c), isFalse);
    });
  });

  group('Drag & Drop Validation - Scenarios', () {
    test('should reject: dragging parent onto child', () {
      final child = Block.create(content: 'Child');
      final parent = Block.create(content: 'Parent', children: [child]);

      // When dragging parent onto child, we check:
      // is child a descendant of parent? Yes! -> reject
      final shouldReject = isDescendantOf(child, parent);
      expect(shouldReject, isTrue);
    });

    test('should accept: dragging child onto parent', () {
      final child = Block.create(content: 'Child');
      final parent = Block.create(content: 'Parent', children: [child]);

      // When dragging child onto parent, we check:
      // is parent a descendant of child? No! -> accept
      final shouldReject = isDescendantOf(parent, child);
      expect(shouldReject, isFalse);
    });

    test('should reject: dragging parent onto grandchild', () {
      final grandchild = Block.create(content: 'Grandchild');
      final child = Block.create(content: 'Child', children: [grandchild]);
      final parent = Block.create(content: 'Parent', children: [child]);

      // When dragging parent onto grandchild, we check:
      // is grandchild a descendant of parent? Yes! -> reject
      final shouldReject = isDescendantOf(grandchild, parent);
      expect(shouldReject, isTrue);
    });

    test('should accept: dragging between siblings', () {
      final sibling1 = Block.create(content: 'Sibling1');
      final sibling2 = Block.create(content: 'Sibling2');
      final parent = Block.create(content: 'Parent', children: [sibling1, sibling2]);

      // When dragging sibling1 onto sibling2, we check:
      // is sibling2 a descendant of sibling1? No! -> accept
      final shouldReject = isDescendantOf(sibling2, sibling1);
      expect(shouldReject, isFalse);
    });

    test('should reject: dragging block onto itself', () {
      final block = Block.create(content: 'Block');

      // When dragging block onto itself, we check:
      // is block a descendant of block? Yes (same block)! -> reject
      final shouldReject = isDescendantOf(block, block);
      expect(shouldReject, isTrue);
    });
  });
}
