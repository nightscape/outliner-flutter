import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'package:outliner_view/repositories/in_memory_outliner_repository.dart';
import 'operation_generators.dart';
import 'operation_interpreter.dart';
import 'outliner_model.dart';
import 'property_test_base.dart';
import 'test_context.dart';

void main() {
  group('Notifier Property Tests (Fast - No UI)', () {
    test('all operations preserve structural invariants', () async {
      await runPropertyTest<NotifierContext, OutlinerModel>(
        blockGenerator: BlockGenerators.blockList(),
        createContext: (blocks) async {
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
          for (var block in blocks) {
            await notifier.addRootBlock(block);
          }

          return NotifierContext(notifier);
        },
        createModel: (ctx) => OutlinerModel.fromContext(ctx),
        interpreter: NotifierInterpreter(),
        checkInvariants: checkStructuralInvariants,
        tearDown: null,
        onlyVisibleBlocks: false,
      );
    });
  });
}
