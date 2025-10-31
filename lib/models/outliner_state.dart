import 'package:freezed_annotation/freezed_annotation.dart';

part 'outliner_state.freezed.dart';

enum CursorPosition { start, end }

/// State of the outliner, always loaded and ready to use.
/// Loading and error handling should be done at the application level
/// before instantiating the outliner.
@freezed
class OutlinerState<T> with _$OutlinerState<T> {
  const factory OutlinerState({
    required T rootBlock,
    String? focusedBlockId,
    @Default(CursorPosition.end) CursorPosition cursorPosition,
    String? viewRootId,
  }) = _OutlinerState<T>;
}
