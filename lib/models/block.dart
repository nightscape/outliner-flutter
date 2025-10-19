import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'block.freezed.dart';
part 'block.g.dart';

const _uuid = Uuid();

@freezed
class Block with _$Block {
  const Block._();

  const factory Block({
    required String id,
    required String content,
    @Default([]) List<Block> children,
    @Default(false) bool isCollapsed,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Block;

  factory Block.create({
    String? id,
    required String content,
    List<Block>? children,
    bool? isCollapsed,
  }) {
    final now = DateTime.now();
    return Block(
      id: id ?? _uuid.v4(),
      content: content,
      children: children ?? [],
      isCollapsed: isCollapsed ?? false,
      createdAt: now,
      updatedAt: now,
    );
  }

  bool get hasChildren => children.isNotEmpty;

  int get totalBlocks {
    int count = 1;
    for (var child in children) {
      count += child.totalBlocks;
    }
    return count;
  }

  Block? findBlockById(String blockId) {
    if (id == blockId) return this;
    for (var child in children) {
      final found = child.findBlockById(blockId);
      if (found != null) return found;
    }
    return null;
  }

  factory Block.fromJson(Map<String, dynamic> json) => _$BlockFromJson(json);
}
