import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'package:outliner_view/repositories/in_memory_outliner_repository.dart';
import 'package:outliner_view/widgets/outliner_list_view.dart';
import 'operation_generators.dart';
import 'operation_interpreter.dart';
import 'outliner_model.dart';
import 'property_test_base.dart';
import 'test_context.dart';

Future<ProviderContainer> _createContainer({
  List<Block> rootBlocks = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      outlinerProvider.overrideWith(
        (ref) => OutlinerNotifier(
          InMemoryOutlinerRepository(initializeSampleData: false),
        ),
      ),
    ],
  );

  final notifier = container.read(outlinerProvider.notifier);
  await notifier.loadBlocks();
  for (final block in rootBlocks) {
    await notifier.addRootBlock(block);
  }
  return container;
}

Future<void> _pumpOutliner(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 600, width: 400, child: OutlinerListView()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('UI-Based Property Tests', () {
    testWidgets('Stateful property: all operations preserve invariants', (
      WidgetTester tester,
    ) async {
      await runPropertyTest<UIContext, UIOutlinerModel>(
        blockGenerator: BlockGenerators.blockList(),
        createContext: (blocks) async {
          final container = await _createContainer(rootBlocks: blocks);
          await _pumpOutliner(tester, container);
          return UIContext(tester, container);
        },
        createModel: (ctx) => UIOutlinerModel.fromContext(ctx),
        interpreter: UIInterpreter(),
        checkInvariants: checkUIInvariants,
        tearDown: (ctx) async {
          ctx.container.dispose();
          await ctx.tester.pumpWidget(Container());
        },
        onlyVisibleBlocks: true,
      );
    });
  });
}
