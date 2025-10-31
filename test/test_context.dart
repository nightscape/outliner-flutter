import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outliner_view/core/block_ops.dart';
import 'package:outliner_view/models/block.dart';
import 'package:outliner_view/models/outliner_state.dart';
import 'package:outliner_view/providers/outliner_provider.dart';
import 'package:outliner_view/repositories/in_memory_outliner_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'outliner_view_property_test.dart';

List<T> getBlocks<T>(OutlinerState<T> state, BlockOps<T> ops) {
  return ops.getChildren(state.rootBlock);
}

T getRootBlock<T>(OutlinerState<T> state) {
  return state.rootBlock;
}

abstract class TestContext<T> {
  /// The system under test (SUT) notifier
  OutlinerNotifier<T> get notifier;

  /// The reference repository (trusted implementation)
  BlockOps<T> get referenceRepo;

  /// BlockOps from the SUT
  BlockOps<T> get ops => notifier.ops;

  /// Blocks from the SUT
  List<T> get blocks => getBlocks(notifier.state, ops);

  /// Root block from the SUT
  T get rootBlock => getRootBlock(notifier.state);

  /// Blocks from the reference repository
  Future<List<T>> get referenceBlocks async {
    final root = await referenceRepo.getRootBlock();
    return referenceRepo.getChildren(root);
  }

  /// Root block from the reference repository
  Future<T> get referenceRootBlock => referenceRepo.getRootBlock();
}

class NotifierContext<T> extends TestContext<T> {
  @override
  final OutlinerNotifier<T> notifier;

  @override
  final BlockOps<T> referenceRepo;

  NotifierContext(this.notifier, this.referenceRepo);
}

class UIContext<T> extends TestContext<T> {
  final WidgetTester tester;
  final ProviderContainer container;
  final IdGenerator idGenerator;
  final StateNotifierProvider<OutlinerNotifier<T>, OutlinerState<T>> provider;

  @override
  final BlockOps<T> referenceRepo;

  UIContext(this.tester, this.container, this.idGenerator, this.referenceRepo, this.provider);

  @override
  OutlinerNotifier<T> get notifier => container.read(provider.notifier);

  @override
  List<T> get blocks => getBlocks(container.read(provider), ops);

  @override
  T get rootBlock => getRootBlock(container.read(provider));
}
