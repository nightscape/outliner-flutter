import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/models/outliner_state.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'outliner_view_property_test.dart';

List<Block> getBlocks(OutlinerState state) {
  return state.maybeWhen(
    loaded: (rootBlock, focusedBlockId, cursorPosition, viewRootId) =>
        rootBlock.children,
    orElse: () => [],
  );
}

Block? getRootBlock(OutlinerState state) {
  return state.whenOrNull(
    loaded: (rootBlock, focusedBlockId, cursorPosition, viewRootId) =>
        rootBlock,
  );
}

abstract class TestContext {
  OutlinerNotifier get notifier;
  List<Block> get blocks => getBlocks(notifier.state);
  Block? get rootBlock => getRootBlock(notifier.state);
}

class NotifierContext extends TestContext {
  @override
  final OutlinerNotifier notifier;

  NotifierContext(this.notifier);
}

class UIContext extends TestContext {
  final WidgetTester tester;
  final ProviderContainer container;
  final IdGenerator idGenerator;

  UIContext(this.tester, this.container, this.idGenerator);

  @override
  OutlinerNotifier get notifier => container.read(outlinerProvider.notifier);

  @override
  List<Block> get blocks => getBlocks(container.read(outlinerProvider));

  @override
  Block? get rootBlock => getRootBlock(container.read(outlinerProvider));
}
