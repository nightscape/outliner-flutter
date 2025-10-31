import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'package:outliner_view/repositories/in_memory_outliner_repository.dart';
import 'package:outliner_view/widgets/outliner_list_view.dart';
import 'operation_generators.dart';
import 'operation_interpreter.dart';
import 'property_test_base.dart';
import 'test_context.dart';

// Deterministic ID generator for property tests
class IdGenerator {
  int _counter = 0;

  String next() {
    return 'pbt-block-${_counter++}';
  }
}

Future<(ProviderContainer, InMemoryOutlinerRepository)> _createContainer({
  List<Block> rootBlocks = const [],
  required IdGenerator sutIdGenerator,
}) async {
  final sutRepo = InMemoryOutlinerRepository(
    initializeSampleData: false,
    idGenerator: sutIdGenerator.next,
  );

  final container = ProviderContainer(
    overrides: [
      outlinerProvider.overrideWith(
        (ref) => OutlinerNotifier(sutRepo),
      ),
    ],
  );

  final notifier = container.read(outlinerProvider.notifier);
  await Future.delayed(const Duration(milliseconds: 10));
  final rootBlock = notifier.state.rootBlock;
  for (final block in rootBlocks) {
    await notifier.addChildBlock(rootBlock, block);
    await Future.delayed(const Duration(milliseconds: 10));
  }
  return (container, sutRepo);
}

Future<void> _pumpOutliner(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 400,
            child: OutlinerListView<Block>(
              opsProvider: outlinerRepositoryProvider,
              notifierProvider: outlinerProvider,
            ),
          ),
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
      final refIdGenerator = IdGenerator();
      await runPropertyTest<Block, UIContext<Block>>(
        blockGenerator: BlockGenerators.blockList(),
        createContext: (blocks) async {
          final (container, sutRepo) = await _createContainer(
            rootBlocks: blocks,
            sutIdGenerator: sutIdGenerator,
          );
          await _pumpOutliner(tester, container);

          // Create reference repository with same initial blocks
          final referenceRepo = InMemoryOutlinerRepository(
            initializeSampleData: false,
            idGenerator: refIdGenerator.next,
          );
          final refRoot = await referenceRepo.getRootBlock();
          for (var block in blocks) {
            await referenceRepo.addChildBlock(refRoot, block);
          }

          return UIContext<Block>(tester, container, sutIdGenerator, referenceRepo, outlinerProvider);
        },
        interpreter: UIInterpreter<Block>(),
        checkInvariants: (ctx, testContext) async {
          await checkStructuralInvariants(ctx, testContext);
        },
        tearDown: (ctx) async {
          ctx.container.dispose();
          await ctx.tester.pumpWidget(Container());
          await ctx.tester.pumpAndSettle();
        },
        includeUIOperations: true,
      );
    });
  });
}
