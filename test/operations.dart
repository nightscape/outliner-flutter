enum DragTargetType { before, after, asChild }

sealed class Operation<T> {
  const Operation();
}

class DragOperation<T> extends Operation<T> {
  final T sourceBlock;
  final T targetBlock;
  final DragTargetType targetType;

  const DragOperation({
    required this.sourceBlock,
    required this.targetBlock,
    required this.targetType,
  });

  @override
  String toString() =>
      'Drag($sourceBlock -> $targetBlock as ${targetType.name})';
}

class IndentOperation<T> extends Operation<T> {
  final T block;

  const IndentOperation(this.block);

  @override
  String toString() => 'Indent($block)';
}

class OutdentOperation<T> extends Operation<T> {
  final T block;

  const OutdentOperation(this.block);

  @override
  String toString() => 'Outdent($block)';
}

class EnterOperation<T> extends Operation<T> {
  final T block;
  final int cursorPosition;

  const EnterOperation(this.block, this.cursorPosition);

  @override
  String toString() => 'Enter($block at $cursorPosition)';
}

class ToggleCollapseOperation<T> extends Operation<T> {
  final T block;

  const ToggleCollapseOperation(this.block);

  @override
  String toString() => 'ToggleCollapse($block)';
}

class ArrowUpOperation<T> extends Operation<T> {
  final T block;

  const ArrowUpOperation(this.block);

  @override
  String toString() => 'ArrowUp($block)';
}

class ArrowDownOperation<T> extends Operation<T> {
  final T block;

  const ArrowDownOperation(this.block);

  @override
  String toString() => 'ArrowDown($block)';
}
