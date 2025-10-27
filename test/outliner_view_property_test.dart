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

// Deterministic ID generator for property tests
class IdGenerator {
  int _counter = 0;

  String next() {
    return 'pbt-block-${_counter++}';
  }
}

Future<ProviderContainer> _createContainer({
  List<Block> rootBlocks = const [],
  required IdGenerator sutIdGenerator,
}) async {
  final container = ProviderContainer(
    overrides: [
      outlinerProvider.overrideWith(
        (ref) => OutlinerNotifier(
          InMemoryOutlinerRepository(
            initializeSampleData: false,
            idGenerator: sutIdGenerator.next,
          ),
        ),
      ),
    ],
  );

  final notifier = container.read(outlinerProvider.notifier);
  await notifier.loadBlocks();
  final rootId = notifier.state.whenOrNull(
    loaded: (rootBlock, _, __, ___) => rootBlock.id,
  );
  if (rootId != null) {
    for (final block in rootBlocks) {
      await notifier.addChildBlock(rootId, block);
    }
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
      final sutIdGenerator = IdGenerator();
      final modelIdGenerator = IdGenerator();
      await runPropertyTest<UIContext, UIOutlinerModel>(
        blockGenerator: BlockGenerators.blockList(),
        createContext: (blocks) async {
          final container = await _createContainer(
            rootBlocks: blocks,
            sutIdGenerator: sutIdGenerator,
          );
          await _pumpOutliner(tester, container);
          return UIContext(tester, container, modelIdGenerator);
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
