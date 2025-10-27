import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/block.dart';
import '../models/outliner_state.dart';
import '../repositories/outliner_repository.dart';
import '../repositories/in_memory_outliner_repository.dart';

final outlinerRepositoryProvider = Provider<OutlinerRepository>((ref) {
  return InMemoryOutlinerRepository();
});

final outlinerProvider = StateNotifierProvider<OutlinerNotifier, OutlinerState>(
  (ref) {
    final repository = ref.watch(outlinerRepositoryProvider);
    return OutlinerNotifier(repository);
  },
);

class OutlinerNotifier extends StateNotifier<OutlinerState> {
  final OutlinerRepository _repository;
  String? _currentViewRootId;

  OutlinerNotifier(this._repository) : super(const OutlinerState.loading()) {
    loadBlocks();
  }

  Future<void> loadBlocks() async {
    final previousState = state;
    final currentFocusedBlockId = previousState.whenOrNull(
      loaded: (_, focusedBlockId, __, ___) => focusedBlockId,
    );

    state = const OutlinerState.loading();
    try {
      final root = await _repository.getRootBlock();
      _currentViewRootId ??= root.id;
      final viewRoot = _resolveViewRoot(root, _currentViewRootId!);

      state = OutlinerState.loaded(
        viewRoot,
        focusedBlockId: currentFocusedBlockId,
        viewRootId: viewRoot.id,
      );
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  void setFocusedBlock(String? blockId, {CursorPosition? cursorPosition}) {
    state.whenOrNull(
      loaded: (rootBlock, _, currentCursorPosition, viewRootId) {
        state = OutlinerState.loaded(
          rootBlock,
          focusedBlockId: blockId,
          cursorPosition: cursorPosition ?? currentCursorPosition,
          viewRootId: viewRootId,
        );
      },
    );
  }

  String? get focusedBlockId {
    return state.whenOrNull(
      loaded: (_, focusedBlockId, __, ___) => focusedBlockId,
    );
  }

  Future<void> setViewRoot(String blockId) async {
    _currentViewRootId = blockId;
    await loadBlocks();
  }

  Future<void> resetViewRoot() async {
    final root = await _repository.getRootBlock();
    if (_currentViewRootId != root.id) {
      _currentViewRootId = root.id;
      await loadBlocks();
    }
  }

  Block _resolveViewRoot(Block root, String viewRootId) {
    if (viewRootId == root.id) {
      return root;
    }
    final found = root.findBlockById(viewRootId);
    if (found != null) {
      return found;
    }
    _currentViewRootId = root.id;
    return root;
  }


  Future<void> updateBlock(String blockId, String newContent) async {
    try {
      await _repository.updateBlock(blockId, newContent);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> toggleBlockCollapse(String blockId) async {
    try {
      await _repository.toggleBlockCollapse(blockId);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> addChildBlock(String parentId, Block child) async {
    try {
      await _repository.addChildBlock(parentId, child);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> removeBlock(String blockId) async {
    try {
      await _repository.removeBlock(blockId);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> moveBlock(
    String blockId,
    String newParentId,
    int newIndex,
  ) async {
    try {
      await _repository.moveBlock(blockId, newParentId, newIndex);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> indentBlock(String blockId) async {
    try {
      await _repository.indentBlock(blockId);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> outdentBlock(String blockId) async {
    try {
      await _repository.outdentBlock(blockId);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> splitBlock(String blockId, int cursorPosition) async {
    try {
      final newBlockId = await _repository.splitBlock(blockId, cursorPosition);
      await loadBlocks();
      setFocusedBlock(newBlockId, cursorPosition: CursorPosition.start);
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<int> get totalBlocks async {
    try {
      return await _repository.getTotalBlocks();
    } catch (e) {
      return 0;
    }
  }

  Future<String> findParentId(String blockId) async {
    return await _repository.findParentId(blockId);
  }

  Future<int> findBlockIndex(String blockId) async {
    try {
      return await _repository.findBlockIndex(blockId);
    } catch (e) {
      return -1;
    }
  }

  Future<void> indentFocusedBlock() async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      await indentBlock(blockId);
    }
  }

  Future<void> outdentFocusedBlock() async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      await outdentBlock(blockId);
    }
  }

  Future<void> removeFocusedBlock() async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      setFocusedBlock(null);
      await removeBlock(blockId);
    }
  }

  Future<void> splitFocusedBlock(int cursorPosition) async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      await splitBlock(blockId, cursorPosition);
    }
  }

  Future<void> addChildToFocusedBlock(Block child) async {
    final blockId = focusedBlockId;
    if (blockId != null) {
      await addChildBlock(blockId, child);
    }
  }

  Future<void> focusNextBlock(String blockId) async {
    try {
      final nextBlockId = await _repository.findNextVisibleBlock(blockId);
      if (nextBlockId != null) {
        setFocusedBlock(nextBlockId, cursorPosition: CursorPosition.start);
      }
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> focusPreviousBlock(String blockId) async {
    try {
      final previousBlockId = await _repository.findPreviousVisibleBlock(
        blockId,
      );
      if (previousBlockId != null) {
        setFocusedBlock(previousBlockId, cursorPosition: CursorPosition.end);
      }
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }
}
