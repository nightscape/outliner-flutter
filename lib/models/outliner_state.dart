import 'package:freezed_annotation/freezed_annotation.dart';
import 'block.dart';

part 'outliner_state.freezed.dart';

@freezed
class OutlinerState with _$OutlinerState {
  const factory OutlinerState.loading() = _Loading;
  const factory OutlinerState.loaded(
    List<Block> blocks, {
    String? focusedBlockId,
  }) = _Loaded;
  const factory OutlinerState.error(String message) = _Error;
}
