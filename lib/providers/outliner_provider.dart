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

  OutlinerNotifier(this._repository) : super(const OutlinerState.loading()) {
    loadBlocks();
  }

  Future<void> loadBlocks() async {
    final currentFocusedBlockId = state.whenOrNull(
      loaded: (_, focusedBlockId) => focusedBlockId,
    );

    state = const OutlinerState.loading();
    try {
      final blocks = await _repository.getRootBlocks();
      state = OutlinerState.loaded(
        blocks,
        focusedBlockId: currentFocusedBlockId,
      );
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  void setFocusedBlock(String? blockId) {
    state.whenOrNull(
      loaded: (blocks, _) {
        state = OutlinerState.loaded(blocks, focusedBlockId: blockId);
      },
    );
  }

  String? get focusedBlockId {
    return state.whenOrNull(loaded: (_, focusedBlockId) => focusedBlockId);
  }

  Future<void> addRootBlock(Block block) async {
    try {
      await _repository.addRootBlock(block);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> insertRootBlock(int index, Block block) async {
    try {
      await _repository.insertRootBlock(index, block);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
  }

  Future<void> removeRootBlock(Block block) async {
    try {
      await _repository.removeRootBlock(block);
      await loadBlocks();
    } catch (e) {
      state = OutlinerState.error(e.toString());
    }
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
    String? newParentId,
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
      await _repository.splitBlock(blockId, cursorPosition);
      await loadBlocks();
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

  Future<String?> findParentId(String blockId) async {
    try {
      return await _repository.findParentId(blockId);
    } catch (e) {
      return null;
    }
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
}
