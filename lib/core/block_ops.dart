/// Read-only field access operations (synchronous).
///
/// This interface provides basic field access to block properties.
/// Implementations should be lightweight and fast since these are
/// called frequently during rendering.
abstract class BlockAccessOps<T> {
  const BlockAccessOps();

  /// Get the unique identifier of a block
  String getId(T block);

  /// Get the text content of a block
  String getContent(T block);

  /// Get the list of child blocks
  List<T> getChildren(T block);

  /// Check if the block is collapsed
  bool getIsCollapsed(T block);

  /// Get the creation timestamp
  DateTime getCreatedAt(T block);

  /// Get the last update timestamp
  DateTime getUpdatedAt(T block);
}

/// Tree traversal and query operations.
///
/// This interface provides operations for navigating and querying
/// the block tree structure.
abstract class BlockTreeOps<T> {
  const BlockTreeOps();

  /// Get all top-level blocks (children of the root)
  List<T> getTopLevelBlocks();

  /// Check if [potentialAncestor] is an ancestor of [block]
  /// Used to prevent circular references in drag-and-drop
  bool isDescendantOf(T potentialAncestor, T block);

  /// Find the next visible block after [block] in the tree.
  /// Returns null if [block] is the last visible block.
  /// Respects collapsed state - skips children of collapsed blocks.
  Future<T?> findNextVisibleBlock(T block);

  /// Find the previous visible block before [block] in the tree.
  /// Returns null if [block] is the first visible block.
  /// Respects collapsed state - skips children of collapsed blocks.
  Future<T?> findPreviousVisibleBlock(T block);

  /// Find the parent of [block].
  /// Returns null if [block] is a top-level block.
  Future<T?> findParent(T block);

  /// Find a block by its ID in the entire tree.
  /// Returns null if not found.
  Future<T?> findBlockById(String blockId);

  /// Get the root block (invisible container for top-level blocks).
  Future<T> getRootBlock();
}

/// Mutation operations (asynchronous).
///
/// This interface provides all operations that modify block data.
/// These operations are async because they may involve persistence,
/// network calls, or triggering reactive updates.
abstract class BlockMutationOps<T> {
  const BlockMutationOps();

  /// Update block content
  Future<void> updateBlock(T block, String content);

  /// Delete a block
  Future<void> deleteBlock(T block);

  /// Move a block to a new position
  /// [newParent] is the new parent block (null for root level)
  /// [newIndex] is the index within the new parent's children
  Future<void> moveBlock(T block, T? newParent, int newIndex);

  /// Toggle collapse state of a block
  Future<void> toggleCollapse(T block);

  /// Add a new child block to a parent
  Future<void> addChildBlock(T parent, T child);

  /// Add a new block at the top level (root)
  Future<void> addTopLevelBlock(T block);

  /// Split a block at the cursor position, creating a new block with the content after the cursor
  /// Returns the ID of the newly created block for focus management
  Future<String> splitBlock(T block, int cursorPosition);

  /// Indent a block (make it a child of its previous sibling)
  Future<void> indentBlock(T block);

  /// Outdent a block (move it up one level in the hierarchy)
  Future<void> outdentBlock(T block);
}

/// Block creation operations.
///
/// This interface provides factory methods for creating new blocks
/// and copying existing blocks with modifications.
abstract class BlockCreationOps<T> {
  const BlockCreationOps();

  /// Create a copy of the block with updated fields
  T copyWith(
    T block, {
    String? content,
    List<T>? children,
    bool? isCollapsed,
  });

  /// Create a new block with the given properties
  T create({
    String? id,
    required String content,
    List<T>? children,
    bool? isCollapsed,
  });
}

/// Complete block operations interface.
///
/// This is the main interface that combines all block operation types.
/// Implementations should provide both synchronous field access and
/// asynchronous persistence operations.
///
/// This abstraction allows widgets to work with different block implementations
/// (e.g., Freezed-generated, FRB-generated from Rust) without requiring
/// inheritance or modification of generated code.
///
/// Implementations should emit changes through the [changeStream] whenever
/// the block tree is modified. UI components can subscribe to this stream
/// to reactively update when data changes.
abstract class BlockOps<T>
    implements
        BlockAccessOps<T>,
        BlockTreeOps<T>,
        BlockMutationOps<T>,
        BlockCreationOps<T> {
  const BlockOps();

  /// Stream that emits the root block whenever the block tree changes.
  /// Subscribe to this stream to receive reactive updates.
  Stream<T> get changeStream;
}

/// Extension providing derived operations on BlockOps
extension BlockOpsExt<T> on BlockOps<T> {
  /// Check if the block has any children
  bool hasChildren(T block) => getChildren(block).isNotEmpty;

  /// Find a block by ID in the tree
  T? findById(T block, String id) {
    if (getId(block) == id) return block;
    for (final child in getChildren(block)) {
      final found = findById(child, id);
      if (found != null) return found;
    }
    return null;
  }

  /// Count total blocks including descendants
  int totalBlocks(T block) {
    int count = 1;
    for (var child in getChildren(block)) {
      count += totalBlocks(child);
    }
    return count;
  }
}
