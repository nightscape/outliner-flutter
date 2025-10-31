import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'package:outliner_view/repositories/in_memory_outliner_repository.dart';
import 'operation_generators.dart';
import 'operation_interpreter.dart';
import 'property_test_base.dart';
import 'test_context.dart';

void main() {
  group('Notifier Property Tests (Fast - No UI)', () {
    test('all operations preserve structural invariants', () async {
      await runPropertyTest<Block, NotifierContext<Block>>(
        blockGenerator: BlockGenerators.blockList(),
        createContext: (blocks) async {
          // Use shared ID generator to ensure root blocks have same ID
          int idCounter = 0;
          String sharedIdGen() => 'test-block-${idCounter++}';

          // Create SUT repository
          final sutRepo = InMemoryOutlinerRepository(
            initializeSampleData: false,
            idGenerator: sharedIdGen,
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
          for (var block in blocks) {
            await notifier.addChildBlock(rootBlock, block);
            await Future.delayed(const Duration(milliseconds: 10));
          }

          // Create reference repository with same ID generator state
          // Reset counter to 0 so root block gets same ID
          idCounter = 0;
          final referenceRepo = InMemoryOutlinerRepository(
            initializeSampleData: false,
            idGenerator: sharedIdGen,
          );
          final refRoot = await referenceRepo.getRootBlock();
          for (var block in blocks) {
            await referenceRepo.addChildBlock(refRoot, block);
          }

          return NotifierContext<Block>(notifier, referenceRepo);
        },
        interpreter: NotifierInterpreter<Block>(),
        checkInvariants: (ctx, testContext) async {
          await checkStructuralInvariants(ctx, testContext);
        },
        tearDown: null,
        includeUIOperations: false,
      );
    });
  });
}
