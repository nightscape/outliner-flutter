import 'dart:async';

import '../core/block_ops.dart';
import '../models/block.dart';

/// Generic base implementation of BlockOps with in-memory storage.
/// Use this when working with custom block types (e.g., FRB-generated).
///
/// Subclasses must implement BlockAccessOps and BlockCreationOps methods
/// for their specific block type.
abstract class InMemoryOutlinerRepositoryBase<T> implements BlockOps<T> {
  late T _root;
  final String Function()? _idGenerator;
  final _changeController = StreamController<T>.broadcast();

  InMemoryOutlinerRepositoryBase({
    bool initializeSampleData = true,
    String Function()? idGenerator,
  }) : _idGenerator = idGenerator {
    _root = create(
      id: _idGenerator?.call(),
      content: '',
      isCollapsed: false,
    );

    if (initializeSampleData) {
      _initializeSampleData();
    }
  }

  @override
  Stream<T> get changeStream => _changeController.stream;

  void dispose() {
    _changeController.close();
  }

  // BlockAccessOps and BlockCreationOps methods must be implemented by subclasses

  void _initializeSampleData() {
    final sampleChildren = [
      create(
        content: 'Welcome to Flutter Outliner',
        children: [
          create(content: 'This is a LogSeq-inspired outliner'),
          create(content: 'Try editing blocks by clicking on them'),
        ],
      ),
      create(
        content: 'Features',
        children: [
          create(
            content: 'Hierarchical blocks',
            children: [create(content: 'Nested as deep as you want')],
          ),
          create(content: 'Collapsible sections'),
          create(content: 'Block-based editing'),
        ],
      ),
      create(content: 'Start typing to create your outline...'),
    ];

    _setRootChildren(sampleChildren);
  }

  void _setRootChildren(List<T> children) {
    _root = copyWith(_root, children: children);
    _changeController.add(_root);
  }

  // BlockTreeOps implementation
  @override
  List<T> getTopLevelBlocks() {
    return getChildren(_root);
  }

  @override
  bool isDescendantOf(T potentialAncestor, T block) {
    if (getId(potentialAncestor) == getId(block)) return true;
    for (var child in getChildren(block)) {
      if (isDescendantOf(potentialAncestor, child)) return true;
    }
    return false;
  }

  @override
  Future<T> getRootBlock() async {
    return _root;
  }

  @override
  Future<T?> findBlockById(String blockId) async {
    if (blockId == getId(_root)) {
      return _root;
    }
    return findById(_root, blockId);
  }

  @override
  Future<T?> findParent(T block) async {
    final blockId = getId(block);
    if (blockId == getId(_root)) {
      return null; // Root has no parent
    }
    final parentId = _findParentIdInTree(_root, blockId);
    if (parentId == null) return null;
    return findById(_root, parentId);
  }

  @override
  Future<T?> findNextVisibleBlock(T block) async {
    if (hasChildren(block) && !getIsCollapsed(block)) {
      return getChildren(block).first;
    }

    return _findNextSiblingOrAncestor(block);
  }

  Future<T?> _findNextSiblingOrAncestor(T block) async {
    final parent = await findParent(block);
    if (parent == null) return null;

    final siblings = getChildren(parent);
    final currentIndex = siblings.indexWhere((child) => getId(child) == getId(block));

    if (currentIndex != -1 && currentIndex < siblings.length - 1) {
      return siblings[currentIndex + 1];
    }

    return _findNextSiblingOrAncestor(parent);
  }

  @override
  Future<T?> findPreviousVisibleBlock(T block) async {
    final parent = await findParent(block);
    if (parent == null) return null;

    final siblings = getChildren(parent);
    final currentIndex = siblings.indexWhere((child) => getId(child) == getId(block));

    if (currentIndex > 0) {
      final previousSibling = siblings[currentIndex - 1];
      return _findLastVisibleDescendant(previousSibling);
    }

    // If this is the first child, parent is the previous block (unless it's root)
    if (getId(parent) == getId(_root)) {
      return null;
    }

    return parent;
  }

  Future<T?> _findLastVisibleDescendant(T block) async {
    if (hasChildren(block) && !getIsCollapsed(block)) {
      return _findLastVisibleDescendant(getChildren(block).last);
    }

    return block;
  }

  // BlockMutationOps implementation

  @override
  Future<void> updateBlock(T block, String content) async {
    if (getId(block) == getId(_root)) {
      return;
    }
    final updatedChildren = _updateBlockInList(
      getChildren(_root),
      getId(block),
      (b) => copyWith(b, content: content),
    );
    _setRootChildren(updatedChildren);
  }

  @override
  Future<void> deleteBlock(T block) async {
    if (getId(block) == getId(_root)) {
      return;
    }
    final updatedChildren = _removeBlockFromList(getChildren(_root), getId(block));
    _setRootChildren(updatedChildren);
  }

  @override
  Future<void> toggleCollapse(T block) async {
    if (getId(block) == getId(_root)) {
      return;
    }
    final updatedChildren = _updateBlockInList(
      getChildren(_root),
      getId(block),
      (b) => copyWith(
        b,
        isCollapsed: !getIsCollapsed(b),
      ),
    );
    _setRootChildren(updatedChildren);
  }

  @override
  Future<void> addChildBlock(T parent, T child) async {
    if (getId(parent) == getId(_root)) {
      _setRootChildren([...getChildren(_root), child]);
    } else {
      final updatedChildren = _updateBlockInList(
        getChildren(_root),
        getId(parent),
        (p) => copyWith(
          p,
          children: [...getChildren(p), child],
        ),
      );
      _setRootChildren(updatedChildren);
    }
  }

  @override
  Future<void> addTopLevelBlock(T block) async {
    _setRootChildren([...getChildren(_root), block]);
  }

  @override
  Future<void> moveBlock(T block, T? newParent, int newIndex) async {
    final blockId = getId(block);
    final newParentId = newParent != null ? getId(newParent) : getId(_root);

    assert(blockId != getId(_root), 'Cannot move root block');
    assert(blockId != newParentId, 'Cannot make block a child of itself');

    if (newParent != null) {
      assert(
        !isDescendantOf(newParent, block),
        'Cannot move block into its descendant',
      );
    }

    var detached = _removeBlockFromList(getChildren(_root), blockId);

    if (newParentId == getId(_root)) {
      final insertIndex = newIndex.clamp(0, detached.length);
      detached.insert(insertIndex, block);
      _setRootChildren(detached);
      return;
    }

    detached = _updateBlockInList(detached, newParentId, (parent) {
      final children = [...getChildren(parent)];
      final insertIndex = newIndex.clamp(0, children.length);
      children.insert(insertIndex, block);
      return copyWith(parent, children: children);
    });

    _setRootChildren(detached);
  }

  @override
  Future<void> indentBlock(T block) async {
    final parent = await findParent(block);
    if (parent == null) return;

    final siblings = getChildren(parent);
    final currentIndex = siblings.indexWhere((child) => getId(child) == getId(block));
    if (currentIndex <= 0) return;

    final newParent = siblings[currentIndex - 1];
    final newIndex = getChildren(newParent).length;

    await moveBlock(block, newParent, newIndex);
  }

  @override
  Future<void> outdentBlock(T block) async {
    final parent = await findParent(block);
    if (parent == null || getId(parent) == getId(_root)) return;

    final grandParent = await findParent(parent);
    if (grandParent == null) return;

    final siblings = getChildren(grandParent);
    final parentIndex = siblings.indexWhere((child) => getId(child) == getId(parent));
    if (parentIndex == -1) return;

    await moveBlock(block, grandParent, parentIndex + 1);
  }

  @override
  Future<String> splitBlock(T block, int cursorPosition) async {
    if (getId(block) == getId(_root)) {
      return getId(block);
    }

    final parent = await findParent(block);
    if (parent == null) return getId(block);

    final content = getContent(block);
    final safePosition = cursorPosition.clamp(0, content.length);
    final beforeCursor = content.substring(0, safePosition);
    final afterCursor = content.substring(safePosition);

    final newBlock = create(
      id: _idGenerator?.call(),
      content: afterCursor,
    );

    final blockIndex = getChildren(parent).indexWhere((child) => getId(child) == getId(block));
    if (blockIndex == -1) return getId(block);

    if (getId(parent) == getId(_root)) {
      final newChildren = List<T>.from(getChildren(parent));
      newChildren[blockIndex] = copyWith(
        newChildren[blockIndex],
        content: beforeCursor,
      );
      newChildren.insert(blockIndex + 1, newBlock);
      _setRootChildren(newChildren);
      return getId(newBlock);
    }

    final updatedChildren = _updateBlockInList(
      getChildren(_root),
      getId(parent),
      (parentBlock) {
        final newChildren = List<T>.from(getChildren(parentBlock));
        newChildren[blockIndex] = copyWith(
          newChildren[blockIndex],
          content: beforeCursor,
        );
        newChildren.insert(blockIndex + 1, newBlock);
        return copyWith(
          parentBlock,
          children: newChildren,
        );
      },
    );

    _setRootChildren(updatedChildren);
    return getId(newBlock);
  }

  String? _findParentIdInTree(T parent, String blockId) {
    for (var child in getChildren(parent)) {
      if (getId(child) == blockId) {
        return getId(parent);
      }
      final found = _findParentIdInTree(child, blockId);
      if (found != null) return found;
    }
    return null;
  }

  List<T> _removeBlockFromList(List<T> blocks, String blockId) {
    final result = <T>[];
    for (var block in blocks) {
      if (getId(block) == blockId) {
        continue;
      }
      result.add(
        copyWith(block, children: _removeBlockFromList(getChildren(block), blockId)),
      );
    }
    return result;
  }

  List<T> _updateBlockInList(
    List<T> blocks,
    String blockId,
    T Function(T) updater,
  ) {
    return blocks.map((block) {
      if (getId(block) == blockId) {
        return updater(block);
      }
      if (hasChildren(block)) {
        return copyWith(
          block,
          children: _updateBlockInList(getChildren(block), blockId, updater),
        );
      }
      return block;
    }).toList();
  }
}

/// Concrete implementation of BlockOps for the Freezed Block type.
/// This is the recommended implementation for most use cases.
class InMemoryOutlinerRepository extends InMemoryOutlinerRepositoryBase<Block> {
  InMemoryOutlinerRepository({
    bool initializeSampleData = true,
    String Function()? idGenerator,
  }) : super(
          initializeSampleData: initializeSampleData,
          idGenerator: idGenerator,
        );

  // BlockAccessOps implementation for Freezed Block
  @override
  String getId(Block block) => block.id;

  @override
  String getContent(Block block) => block.content;

  @override
  List<Block> getChildren(Block block) => block.children;

  @override
  bool getIsCollapsed(Block block) => block.isCollapsed;

  @override
  DateTime getCreatedAt(Block block) => block.createdAt;

  @override
  DateTime getUpdatedAt(Block block) => block.updatedAt;

  // BlockCreationOps implementation for Freezed Block
  @override
  Block copyWith(
    Block block, {
    String? content,
    List<Block>? children,
    bool? isCollapsed,
  }) {
    return block.copyWith(
      content: content ?? block.content,
      children: children ?? block.children,
      isCollapsed: isCollapsed ?? block.isCollapsed,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Block create({
    String? id,
    required String content,
    List<Block>? children,
    bool? isCollapsed,
  }) {
    return Block.create(
      id: id,
      content: content,
      children: children ?? [],
      isCollapsed: isCollapsed ?? false,
    );
  }
}
