import '../models/block.dart';

abstract class OutlinerRepository {
  Future<List<Block>> getRootBlocks();

  Future<Block?> findBlockById(String blockId);

  Future<String?> findParentId(String blockId);

  Future<int> findBlockIndex(String blockId);

  Future<int> getTotalBlocks();

  Future<void> addRootBlock(Block block);

  Future<void> insertRootBlock(int index, Block block);

  Future<void> removeRootBlock(Block block);

  Future<void> updateBlock(String blockId, String content);

  Future<void> toggleBlockCollapse(String blockId);

  Future<void> addChildBlock(String parentId, Block child);

  Future<void> removeBlock(String blockId);

  Future<void> moveBlock(String blockId, String? newParentId, int newIndex);

  Future<void> indentBlock(String blockId);

  Future<void> outdentBlock(String blockId);

  Future<void> splitBlock(String blockId, int cursorPosition);
}
