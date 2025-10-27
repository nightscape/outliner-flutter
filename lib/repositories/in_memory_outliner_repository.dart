import '../models/block.dart';
import '../models/tree_constants.dart';
import 'outliner_repository.dart';

class InMemoryOutlinerRepository implements OutlinerRepository {
  late Block _root;
  final String Function()? _idGenerator;

  InMemoryOutlinerRepository({
    bool initializeSampleData = true,
    String Function()? idGenerator,
  }) : _idGenerator = idGenerator {
    _root = Block.create(
      content: '',
      isCollapsed: false,
    );

    if (initializeSampleData) {
      _initializeSampleData();
    }
  }

  void _initializeSampleData() {
    final sampleChildren = [
      Block.create(
        content: 'Welcome to Flutter Outliner',
        children: [
          Block.create(content: 'This is a LogSeq-inspired outliner'),
          Block.create(content: 'Try editing blocks by clicking on them'),
        ],
      ),
      Block.create(
        content: 'Features',
        children: [
          Block.create(
            content: 'Hierarchical blocks',
            children: [Block.create(content: 'Nested as deep as you want')],
          ),
          Block.create(content: 'Collapsible sections'),
          Block.create(content: 'Block-based editing'),
        ],
      ),
      Block.create(content: 'Start typing to create your outline...'),
    ];

    _setRootChildren(sampleChildren);
  }

  void _setRootChildren(List<Block> children) {
    _root = _root.copyWith(children: children, updatedAt: DateTime.now());
  }

  @override
  Future<Block> getRootBlock() async {
    return _root;
  }


  @override
  Future<Block?> findBlockById(String blockId) async {
    if (blockId == _root.id) {
      return _root;
    }
    return _root.findBlockById(blockId);
  }

  @override
  Future<String> findParentId(String blockId) async {
    if (blockId == _root.id) {
      throw ArgumentError('findParentId called on root block: $blockId');
    }
    final parentId = _findParentIdInTree(_root, blockId);
    if (parentId == null) {
      throw ArgumentError('Block not found in tree: $blockId');
    }
    return parentId;
  }

  @override
  Future<int> findBlockIndex(String blockId) async {
    if (blockId == _root.id) {
      return -1;
    }
    final parentId = await findParentId(blockId);
    final parent = _root.findBlockById(parentId);
    if (parent == null) {
      return -1;
    }
    return parent.children.indexWhere((child) => child.id == blockId);
  }

  @override
  Future<int> getTotalBlocks() async {
    return _root.totalBlocks - 1;
  }

  @override
  Future<void> updateBlock(String blockId, String content) async {
    if (blockId == _root.id) {
      return;
    }
    final updatedChildren = _updateBlockInList(
      _root.children,
      blockId,
      (block) => block.copyWith(content: content, updatedAt: DateTime.now()),
    );
    _setRootChildren(updatedChildren);
  }

  @override
  Future<void> toggleBlockCollapse(String blockId) async {
    if (blockId == _root.id) {
      return;
    }
    final updatedChildren = _updateBlockInList(
      _root.children,
      blockId,
      (block) => block.copyWith(
        isCollapsed: !block.isCollapsed,
        updatedAt: DateTime.now(),
      ),
    );
    _setRootChildren(updatedChildren);
  }

  @override
  Future<void> addChildBlock(String parentId, Block child) async {
    if (parentId == _root.id) {
      _setRootChildren([..._root.children, child]);
    } else {
      final updatedChildren = _updateBlockInList(
        _root.children,
        parentId,
        (parent) => parent.copyWith(
          children: [...parent.children, child],
          updatedAt: DateTime.now(),
        ),
      );
      _setRootChildren(updatedChildren);
    }
  }

  @override
  Future<void> removeBlock(String blockId) async {
    if (blockId == _root.id) {
      return;
    }
    final updatedChildren = _removeBlockFromList(_root.children, blockId);
    _setRootChildren(updatedChildren);
  }

  @override
  Future<void> moveBlock(
    String blockId,
    String newParentId,
    int newIndex,
  ) async {
    assert(blockId != _root.id, 'Cannot move root block');
    assert(blockId != newParentId, 'Cannot make block a child of itself');

    final block = await findBlockById(blockId);
    assert(block != null, 'Block not found: $blockId');

    assert(
      !isDescendantOf(newParentId, blockId),
      'Cannot move block into its descendant',
    );

    var detached = _removeBlockFromList(_root.children, blockId);

    if (newParentId == _root.id) {
      final insertIndex = newIndex.clamp(0, detached.length);
      detached.insert(insertIndex, block!);
      _setRootChildren(detached);
      return;
    }

    detached = _updateBlockInList(detached, newParentId, (parent) {
      final children = [...parent.children];
      final insertIndex = newIndex.clamp(0, children.length);
      children.insert(insertIndex, block!);
      return parent.copyWith(children: children, updatedAt: DateTime.now());
    });

    _setRootChildren(detached);
  }

  @override
  Future<void> indentBlock(String blockId) async {
    final parentId = await findParentId(blockId);
    final parent = await findBlockById(parentId);
    if (parent == null) return;

    final siblings = parent.children;
    final currentIndex = siblings.indexWhere((child) => child.id == blockId);
    if (currentIndex <= 0) return;

    final newParentId = siblings[currentIndex - 1].id;
    final newParent = await findBlockById(newParentId);
    final newIndex = newParent?.children.length ?? 0;

    await moveBlock(blockId, newParentId, newIndex);
  }

  @override
  Future<void> outdentBlock(String blockId) async {
    final parentId = await findParentId(blockId);
    if (parentId == _root.id) return;

    final grandParentId = await findParentId(parentId);
    final grandParent = await findBlockById(grandParentId);
    if (grandParent == null) return;

    final siblings = grandParent.children;
    final parentIndex = siblings.indexWhere((child) => child.id == parentId);
    if (parentIndex == -1) return;

    await moveBlock(blockId, grandParentId, parentIndex + 1);
  }

  @override
  Future<String> splitBlock(String blockId, int cursorPosition) async {
    final block = await findBlockById(blockId);
    if (block == null || blockId == _root.id) {
      return blockId;
    }

    final parentId = await findParentId(blockId);
    final parent = parentId == _root.id ? _root : await findBlockById(parentId);
    if (parent == null) return blockId;

    final content = block.content;
    final safePosition = cursorPosition.clamp(0, content.length);
    final beforeCursor = content.substring(0, safePosition);
    final afterCursor = content.substring(safePosition);

    final newBlock = Block.create(
      id: _idGenerator?.call(),
      content: afterCursor,
    );

    // Find the index of the block to split within its parent
    final blockIndex = parent.children.indexWhere((child) => child.id == blockId);
    if (blockIndex == -1) return blockId;

    if (parentId == _root.id) {
      final newChildren = List<Block>.from(parent.children);
      newChildren[blockIndex] = newChildren[blockIndex].copyWith(
        content: beforeCursor,
        updatedAt: DateTime.now(),
      );
      newChildren.insert(blockIndex + 1, newBlock);
      _setRootChildren(newChildren);
      return newBlock.id;
    }

    // Update the parent block using _updateBlockInList
    final updatedChildren = _updateBlockInList(
      _root.children,
      parentId,
      (parentBlock) {
        final newChildren = List<Block>.from(parentBlock.children);
        // Update the content of the original block
        newChildren[blockIndex] = newChildren[blockIndex].copyWith(
          content: beforeCursor,
          updatedAt: DateTime.now(),
        );
        // Insert the new block right after
        newChildren.insert(blockIndex + 1, newBlock);
        return parentBlock.copyWith(
          children: newChildren,
          updatedAt: DateTime.now(),
        );
      },
    );

    _setRootChildren(updatedChildren);
    return newBlock.id;
  }

  @override
  Future<String?> findNextVisibleBlock(String blockId) async {
    final block = await findBlockById(blockId);
    if (block == null) return null;

    if (block.hasChildren && !block.isCollapsed) {
      return block.children.first.id;
    }

    return _findNextSiblingOrAncestor(blockId);
  }

  Future<String?> _findNextSiblingOrAncestor(String blockId) async {
    final parentId = await findParentId(blockId);
    if (parentId == _root.id) return null;

    final parent = await findBlockById(parentId);
    if (parent == null) return null;

    final siblings = parent.children;
    final currentIndex = siblings.indexWhere((child) => child.id == blockId);

    if (currentIndex != -1 && currentIndex < siblings.length - 1) {
      return siblings[currentIndex + 1].id;
    }

    return _findNextSiblingOrAncestor(parentId);
  }

  @override
  Future<String?> findPreviousVisibleBlock(String blockId) async {
    final parentId = await findParentId(blockId);
    final parent = await findBlockById(parentId);
    if (parent == null) return null;

    final siblings = parent.children;
    final currentIndex = siblings.indexWhere((child) => child.id == blockId);

    if (currentIndex > 0) {
      final previousSibling = siblings[currentIndex - 1];
      return _findLastVisibleDescendant(previousSibling.id);
    }

    if (parentId == _root.id) {
      return null;
    }

    return parentId;
  }

  Future<String?> _findLastVisibleDescendant(String blockId) async {
    final block = await findBlockById(blockId);
    if (block == null) return null;

    if (block.hasChildren && !block.isCollapsed) {
      return _findLastVisibleDescendant(block.children.last.id);
    }

    return blockId;
  }

  bool isDescendantOf(String potentialDescendantId, String ancestorId) {
    if (ancestorId == potentialDescendantId) return true;
    final ancestor = _root.findBlockById(ancestorId);
    if (ancestor == null) return false;
    return _isDescendantOf(potentialDescendantId, ancestor);
  }

  bool _isDescendantOf(String potentialDescendantId, Block ancestor) {
    for (var child in ancestor.children) {
      if (child.id == potentialDescendantId) return true;
      if (_isDescendantOf(potentialDescendantId, child)) return true;
    }
    return false;
  }

  String? _findParentIdInTree(Block parent, String blockId) {
    for (var child in parent.children) {
      if (child.id == blockId) {
        return parent.id;
      }
      final found = _findParentIdInTree(child, blockId);
      if (found != null) return found;
    }
    return null;
  }

  List<Block> _removeBlockFromList(List<Block> blocks, String blockId) {
    final result = <Block>[];
    for (var block in blocks) {
      if (block.id == blockId) {
        continue;
      }
      result.add(
        block.copyWith(children: _removeBlockFromList(block.children, blockId)),
      );
    }
    return result;
  }

  List<Block> _updateBlockInList(
    List<Block> blocks,
    String blockId,
    Block Function(Block) updater,
  ) {
    return blocks.map((block) {
      if (block.id == blockId) {
        return updater(block);
      }
      if (block.hasChildren) {
        return block.copyWith(
          children: _updateBlockInList(block.children, blockId, updater),
        );
      }
      return block;
    }).toList();
  }
}
