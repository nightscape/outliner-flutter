enum DragTargetType { before, after, asChild }

sealed class Operation {
  const Operation();
}

class DragOperation extends Operation {
  final String sourceBlockId;
  final String targetBlockId;
  final DragTargetType targetType;

  const DragOperation({
    required this.sourceBlockId,
    required this.targetBlockId,
    required this.targetType,
  });

  @override
  String toString() =>
      'Drag($sourceBlockId -> $targetBlockId as ${targetType.name})';
}

class IndentOperation extends Operation {
  final String blockId;

  const IndentOperation(this.blockId);

  @override
  String toString() => 'Indent($blockId)';
}

class OutdentOperation extends Operation {
  final String blockId;

  const OutdentOperation(this.blockId);

  @override
  String toString() => 'Outdent($blockId)';
}

class EnterOperation extends Operation {
  final String blockId;
  final int cursorPosition;

  const EnterOperation(this.blockId, this.cursorPosition);

  @override
  String toString() => 'Enter($blockId at $cursorPosition)';
}

class ToggleCollapseOperation extends Operation {
  final String blockId;

  const ToggleCollapseOperation(this.blockId);

  @override
  String toString() => 'ToggleCollapse($blockId)';
}
