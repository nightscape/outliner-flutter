import '../models/block.dart';

abstract class OutlinerRepository {
  Future<Block> getRootBlock();

  Future<Block?> findBlockById(String blockId);

  /// Returns the parent ID of the given block.
  /// For the true root block, returns kRootParentId sentinel value.
  Future<String> findParentId(String blockId);

  Future<int> findBlockIndex(String blockId);

  Future<int> getTotalBlocks();

  Future<void> updateBlock(String blockId, String content);

  Future<void> toggleBlockCollapse(String blockId);

  Future<void> addChildBlock(String parentId, Block child);

  Future<void> removeBlock(String blockId);

  Future<void> moveBlock(String blockId, String newParentId, int newIndex);

  Future<void> indentBlock(String blockId);

  Future<void> outdentBlock(String blockId);

  Future<String> splitBlock(String blockId, int cursorPosition);

  Future<String?> findNextVisibleBlock(String blockId);

  Future<String?> findPreviousVisibleBlock(String blockId);
}
