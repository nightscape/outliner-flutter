import 'package:freezed_annotation/freezed_annotation.dart';
import 'block.dart';

part 'outliner_state.freezed.dart';

enum CursorPosition { start, end }

@freezed
class OutlinerState with _$OutlinerState {
  const factory OutlinerState.loading() = _Loading;
  const factory OutlinerState.loaded(
    Block rootBlock, {
    String? focusedBlockId,
    @Default(CursorPosition.end) CursorPosition cursorPosition,
    String? viewRootId,
  }) = _Loaded;
  const factory OutlinerState.error(String message) = _Error;
}
