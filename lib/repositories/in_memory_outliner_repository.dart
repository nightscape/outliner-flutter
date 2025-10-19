import '../models/block.dart';
import 'outliner_repository.dart';

class InMemoryOutlinerRepository implements OutlinerRepository {
  List<Block> _blocks = [];

  InMemoryOutlinerRepository({bool initializeSampleData = true}) {
    if (initializeSampleData) {
      _initializeSampleData();
    }
  }

  void _initializeSampleData() {
    _blocks = [
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
  }

  @override
  Future<List<Block>> getRootBlocks() async {
    return List.unmodifiable(_blocks);
  }

  @override
  Future<Block?> findBlockById(String blockId) async {
    return _findBlockInRoots(blockId);
  }

  @override
  Future<String?> findParentId(String blockId) async {
    for (var rootBlock in _blocks) {
      if (rootBlock.id == blockId) {
        return null;
      }
      final parentId = _findParentIdInTree(rootBlock, blockId);
      if (parentId != null) return parentId;
    }
    return null;
  }

  @override
  Future<int> findBlockIndex(String blockId) async {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].id == blockId) {
        return i;
      }
    }

    for (var rootBlock in _blocks) {
      final index = _findBlockIndexInTree(rootBlock, blockId);
      if (index != -1) return index;
    }
    return -1;
  }

  @override
  Future<int> getTotalBlocks() async {
    int count = 0;
    for (var block in _blocks) {
      count += block.totalBlocks;
    }
    return count;
  }

  @override
  Future<void> addRootBlock(Block block) async {
    _blocks = [..._blocks, block];
  }

  @override
  Future<void> insertRootBlock(int index, Block block) async {
    final newBlocks = [..._blocks];
    newBlocks.insert(index, block);
    _blocks = newBlocks;
  }

  @override
  Future<void> removeRootBlock(Block block) async {
    _blocks = _blocks.where((b) => b.id != block.id).toList();
  }

  @override
  Future<void> updateBlock(String blockId, String content) async {
    _blocks = _updateBlockInList(_blocks, blockId, (block) {
      return block.copyWith(content: content, updatedAt: DateTime.now());
    });
  }

  @override
  Future<void> toggleBlockCollapse(String blockId) async {
    _blocks = _updateBlockInList(_blocks, blockId, (block) {
      return block.copyWith(isCollapsed: !block.isCollapsed);
    });
  }

  @override
  Future<void> addChildBlock(String parentId, Block child) async {
    _blocks = _updateBlockInList(_blocks, parentId, (parent) {
      return parent.copyWith(
        children: [...parent.children, child],
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<void> removeBlock(String blockId) async {
    _blocks = _removeBlockFromList(_blocks, blockId);
  }

  @override
  Future<void> moveBlock(
    String blockId,
    String? newParentId,
    int newIndex,
  ) async {
    final block = _findBlockInRoots(blockId);
    if (block == null) return;

    if (newParentId != null) {
      if (blockId == newParentId) return;
      if (_isDescendantOf(newParentId, block)) return;
    }

    var newState = _removeBlockFromList(_blocks, blockId);

    if (newParentId == null) {
      newState.insert(newIndex.clamp(0, newState.length), block);
    } else {
      newState = _updateBlockInList(newState, newParentId, (parent) {
        final newChildren = [...parent.children];
        newChildren.insert(newIndex.clamp(0, newChildren.length), block);
        return parent.copyWith(
          children: newChildren,
          updatedAt: DateTime.now(),
        );
      });
    }

    _blocks = newState;
  }

  @override
  Future<void> indentBlock(String blockId) async {
    final parentId = await findParentId(blockId);
    final currentIndex = await findBlockIndex(blockId);

    List<Block> siblings;
    if (parentId == null) {
      siblings = _blocks;
    } else {
      final parent = _findBlockInRoots(parentId);
      if (parent == null) return;
      siblings = parent.children;
    }

    if (currentIndex <= 0) return;

    final previousSiblingId = siblings[currentIndex - 1].id;
    final block = _findBlockInRoots(blockId);
    if (block == null) return;

    var newState = _removeBlockFromList(_blocks, blockId);
    newState = _updateBlockInList(newState, previousSiblingId, (sibling) {
      return sibling.copyWith(
        children: [...sibling.children, block],
        updatedAt: DateTime.now(),
      );
    });

    _blocks = newState;
  }

  @override
  Future<void> outdentBlock(String blockId) async {
    final parentId = await findParentId(blockId);
    if (parentId == null) return;

    final block = _findBlockInRoots(blockId);
    if (block == null) return;

    final grandparentId = await findParentId(parentId);
    final parentIndex = await findBlockIndex(parentId);

    var newState = _removeBlockFromList(_blocks, blockId);

    if (grandparentId == null) {
      newState.insert((parentIndex + 1).clamp(0, newState.length), block);
    } else {
      newState = _updateBlockInList(newState, grandparentId, (grandparent) {
        final newChildren = [...grandparent.children];
        final parentIndexInGrandparent = newChildren.indexWhere(
          (b) => b.id == parentId,
        );
        if (parentIndexInGrandparent != -1) {
          newChildren.insert(
            (parentIndexInGrandparent + 1).clamp(0, newChildren.length),
            block,
          );
        }
        return grandparent.copyWith(
          children: newChildren,
          updatedAt: DateTime.now(),
        );
      });
    }

    _blocks = newState;
  }

  @override
  Future<void> splitBlock(String blockId, int cursorPosition) async {
    final block = _findBlockInRoots(blockId);
    if (block == null) return;

    final content = block.content;
    final safePosition = cursorPosition.clamp(0, content.length);
    final beforeCursor = content.substring(0, safePosition);
    final afterCursor = content.substring(safePosition);

    final newBlock = Block.create(content: afterCursor);

    _blocks = _updateBlockInList(_blocks, blockId, (b) {
      return b.copyWith(content: beforeCursor, updatedAt: DateTime.now());
    });

    final parentId = await findParentId(blockId);
    final blockIndex = await findBlockIndex(blockId);

    if (parentId == null) {
      final newState = [..._blocks];
      newState.insert(blockIndex + 1, newBlock);
      _blocks = newState;
    } else {
      _blocks = _updateBlockInList(_blocks, parentId, (parent) {
        final newChildren = [...parent.children];
        final childIndex = newChildren.indexWhere((c) => c.id == blockId);
        if (childIndex != -1) {
          newChildren.insert(childIndex + 1, newBlock);
        }
        return parent.copyWith(
          children: newChildren,
          updatedAt: DateTime.now(),
        );
      });
    }
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

  Block? _findBlockInRoots(String blockId) {
    for (var rootBlock in _blocks) {
      final found = rootBlock.findBlockById(blockId);
      if (found != null) return found;
    }
    return null;
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

  int _findBlockIndexInTree(Block parent, String blockId) {
    for (var i = 0; i < parent.children.length; i++) {
      if (parent.children[i].id == blockId) {
        return i;
      }
      final found = _findBlockIndexInTree(parent.children[i], blockId);
      if (found != -1) return found;
    }
    return -1;
  }

  bool _isDescendantOf(String potentialDescendantId, Block ancestor) {
    if (ancestor.id == potentialDescendantId) return true;
    for (var child in ancestor.children) {
      if (_isDescendantOf(potentialDescendantId, child)) return true;
    }
    return false;
  }
}
