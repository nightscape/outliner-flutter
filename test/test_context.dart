import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/models/outliner_state.dart';
import 'package:outliner_view/providers/outliner_provider.dart';

List<Block> getBlocks(OutlinerState state) {
  return state.maybeWhen(
    loaded: (blocks, focusedBlockId) => blocks,
    orElse: () => [],
  );
}

abstract class TestContext {
  OutlinerNotifier get notifier;
  List<Block> get blocks => getBlocks(notifier.state);
}

class NotifierContext extends TestContext {
  @override
  final OutlinerNotifier notifier;

  NotifierContext(this.notifier);
}

class UIContext extends TestContext {
  final WidgetTester tester;
  final ProviderContainer container;

  UIContext(this.tester, this.container);

  @override
  OutlinerNotifier get notifier => container.read(outlinerProvider.notifier);

  @override
  List<Block> get blocks => getBlocks(container.read(outlinerProvider));
}
