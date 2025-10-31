import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/block_ops.dart';
import '../models/block.dart';
import '../models/outliner_state.dart';
import '../repositories/in_memory_outliner_repository.dart';

final outlinerRepositoryProvider = Provider<BlockOps<Block>>((ref) {
  return InMemoryOutlinerRepository();
});

final outlinerProvider = StateNotifierProvider<OutlinerNotifier<Block>, OutlinerState<Block>>(
  (ref) {
    final ops = ref.watch(outlinerRepositoryProvider);
    return OutlinerNotifier(ops);
  },
);

/// Provider that exposes BlockOps from the current outliner state.
/// This is what widgets should watch to get reactive updates when blocks change.
///
/// IMPORTANT: This creates a wrapper that changes identity when state changes,
/// forcing widgets to rebuild. The wrapper delegates to the actual ops.
final outlinerOpsProvider = Provider<BlockOps<Block>>((ref) {
  final state = ref.watch(outlinerProvider);
  final notifier = ref.read(outlinerProvider.notifier);

  // Return a wrapper that includes the state identity
  // This ensures the provider returns a new value when state changes
  return _ReactiveBlockOps(notifier.ops, state.rootBlock);
});

/// Wrapper that ties BlockOps identity to the current root block.
/// This ensures RiverPod rebuilds consumers when state changes.
class _ReactiveBlockOps implements BlockOps<Block> {
  final BlockOps<Block> _delegate;
  final Block _currentRoot;

  _ReactiveBlockOps(this._delegate, this._currentRoot);

  @override
  Stream<Block> get changeStream => _delegate.changeStream;

  @override
  String getId(Block block) => _delegate.getId(block);

  @override
  String getContent(Block block) => _delegate.getContent(block);

  @override
  List<Block> getChildren(Block block) => _delegate.getChildren(block);

  @override
  bool getIsCollapsed(Block block) => _delegate.getIsCollapsed(block);

  @override
  DateTime getCreatedAt(Block block) => _delegate.getCreatedAt(block);

  @override
  DateTime getUpdatedAt(Block block) => _delegate.getUpdatedAt(block);

  @override
  List<Block> getTopLevelBlocks() => getChildren(_currentRoot);

  @override
  bool isDescendantOf(Block potentialAncestor, Block block) =>
      _delegate.isDescendantOf(potentialAncestor, block);

  @override
  Future<Block?> findNextVisibleBlock(Block block) =>
      _delegate.findNextVisibleBlock(block);

  @override
  Future<Block?> findPreviousVisibleBlock(Block block) =>
      _delegate.findPreviousVisibleBlock(block);

  @override
  Future<Block?> findParent(Block block) => _delegate.findParent(block);

  @override
  Future<Block?> findBlockById(String blockId) =>
      _delegate.findBlockById(blockId);

  @override
  Future<Block> getRootBlock() async => _currentRoot;

  @override
  Future<void> updateBlock(Block block, String content) =>
      _delegate.updateBlock(block, content);

  @override
  Future<void> deleteBlock(Block block) => _delegate.deleteBlock(block);

  @override
  Future<void> moveBlock(Block block, Block? newParent, int newIndex) =>
      _delegate.moveBlock(block, newParent, newIndex);

  @override
  Future<void> toggleCollapse(Block block) => _delegate.toggleCollapse(block);

  @override
  Future<void> addChildBlock(Block parent, Block child) =>
      _delegate.addChildBlock(parent, child);

  @override
  Future<void> addTopLevelBlock(Block block) =>
      _delegate.addTopLevelBlock(block);

  @override
  Future<String> splitBlock(Block block, int cursorPosition) =>
      _delegate.splitBlock(block, cursorPosition);

  @override
  Future<void> indentBlock(Block block) => _delegate.indentBlock(block);

  @override
  Future<void> outdentBlock(Block block) => _delegate.outdentBlock(block);

  @override
  Block copyWith(Block block,
          {String? content, List<Block>? children, bool? isCollapsed}) =>
      _delegate.copyWith(block,
          content: content, children: children, isCollapsed: isCollapsed);

  @override
  Block create(
          {String? id,
          required String content,
          List<Block>? children,
          bool? isCollapsed}) =>
      _delegate.create(
          id: id, content: content, children: children, isCollapsed: isCollapsed);

  // Override equality to depend on current root
  // This ensures RiverPod sees a different value when state changes
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ReactiveBlockOps &&
          runtimeType == other.runtimeType &&
          _currentRoot == other._currentRoot;

  @override
  int get hashCode => _currentRoot.hashCode;
}

class OutlinerNotifier<T> extends StateNotifier<OutlinerState<T>> {
  final BlockOps<T> ops;
  String? _currentViewRootId;

  OutlinerNotifier(this.ops) : super(_createInitialState(ops)) {
    _initialize();
  }

  static OutlinerState<T> _createInitialState<T>(BlockOps<T> ops) {
    return OutlinerState(
      rootBlock: ops.create(content: ''),
    );
  }

  void _initialize() {
    ops.changeStream.listen(_onBlockTreeChanged);
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final root = await ops.getRootBlock();
    _onBlockTreeChanged(root);
  }

  void _onBlockTreeChanged(T root) {
    _currentViewRootId ??= ops.getId(root);
    final viewRoot = _resolveViewRoot(root, _currentViewRootId!);

    final currentFocusedBlockId = state.focusedBlockId;
    final newState = OutlinerState(
      rootBlock: viewRoot,
      focusedBlockId: currentFocusedBlockId,
      viewRootId: ops.getId(viewRoot),
    );

    state = newState;
  }

  void setFocusedBlock(String? blockId, {CursorPosition? cursorPosition}) {
    state = state.copyWith(
      focusedBlockId: blockId,
      cursorPosition: cursorPosition ?? state.cursorPosition,
    );
  }

  String? get focusedBlockId {
    return state.focusedBlockId;
  }

  Future<T?> get focusedBlock async {
    final blockId = focusedBlockId;
    if (blockId == null) return null;
    return await ops.findBlockById(blockId);
  }

  Future<void> setViewRoot(String blockId) async {
    _currentViewRootId = blockId;
    final root = await ops.getRootBlock();
    _onBlockTreeChanged(root);
  }

  Future<void> resetViewRoot() async {
    final root = await ops.getRootBlock();
    if (_currentViewRootId != ops.getId(root)) {
      _currentViewRootId = ops.getId(root);
      _onBlockTreeChanged(root);
    }
  }

  T _resolveViewRoot(T root, String viewRootId) {
    if (viewRootId == ops.getId(root)) {
      return root;
    }
    final found = ops.findById(root, viewRootId);
    if (found != null) {
      return found;
    }
    _currentViewRootId = ops.getId(root);
    return root;
  }


  Future<void> updateBlock(T block, String newContent) async {
    await ops.updateBlock(block, newContent);
  }

  Future<void> toggleBlockCollapse(T block) async {
    await ops.toggleCollapse(block);
  }

  Future<void> addChildBlock(T parent, T child) async {
    await ops.addChildBlock(parent, child);
  }

  Future<void> removeBlock(T block) async {
    await ops.deleteBlock(block);
  }

  Future<void> moveBlock(
    T block,
    T? newParent,
    int newIndex,
  ) async {
    await ops.moveBlock(block, newParent, newIndex);
  }

  Future<void> indentBlock(T block) async {
    await ops.indentBlock(block);
  }

  Future<void> outdentBlock(T block) async {
    await ops.outdentBlock(block);
  }

  Future<void> splitBlock(T block, int cursorPosition) async {
    final newBlockId = await ops.splitBlock(block, cursorPosition);
    setFocusedBlock(newBlockId, cursorPosition: CursorPosition.start);
  }

  Future<int> get totalBlocks async {
    try {
      final root = await ops.getRootBlock();
      return ops.totalBlocks(root) - 1; // Exclude root
    } catch (e) {
      return 0;
    }
  }

  Future<String?> findParentId(String blockId) async {
    final block = await ops.findBlockById(blockId);
    if (block == null) return null;
    final parent = await ops.findParent(block);
    return parent != null ? ops.getId(parent) : null;
  }

  Future<int> findBlockIndex(String blockId) async {
    try {
      final block = await ops.findBlockById(blockId);
      if (block == null) return -1;
      final parent = await ops.findParent(block);
      if (parent == null) return -1;
      return ops.getChildren(parent).indexWhere((child) => ops.getId(child) == blockId);
    } catch (e) {
      return -1;
    }
  }

  Future<void> indentFocusedBlock() async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      final block = await ops.findBlockById(blockId);
      if (block != null) {
        await indentBlock(block);
      }
    }
  }

  Future<void> outdentFocusedBlock() async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      final block = await ops.findBlockById(blockId);
      if (block != null) {
        await outdentBlock(block);
      }
    }
  }

  Future<void> removeFocusedBlock() async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      setFocusedBlock(null);
      final block = await ops.findBlockById(blockId);
      if (block != null) {
        await removeBlock(block);
      }
    }
  }

  Future<void> splitFocusedBlock(int cursorPosition) async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      final block = await ops.findBlockById(blockId);
      if (block != null) {
        await splitBlock(block, cursorPosition);
      }
    }
  }

  Future<void> addChildToFocusedBlock(T child) async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      final parent = await ops.findBlockById(blockId);
      if (parent != null) {
        await addChildBlock(parent, child);
      }
    }
  }

  Future<void> focusNextBlock(String blockId) async {
    final block = await ops.findBlockById(blockId);
    if (block != null) {
      final nextBlock = await ops.findNextVisibleBlock(block);
      if (nextBlock != null) {
        setFocusedBlock(ops.getId(nextBlock), cursorPosition: CursorPosition.start);
      }
    }
  }

  Future<void> focusPreviousBlock(String blockId) async {
    final block = await ops.findBlockById(blockId);
    if (block != null) {
      final previousBlock = await ops.findPreviousVisibleBlock(block);
      if (previousBlock != null) {
        setFocusedBlock(ops.getId(previousBlock), cursorPosition: CursorPosition.end);
      }
    }
  }
}
