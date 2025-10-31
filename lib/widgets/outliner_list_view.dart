import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/outliner_config.dart';
import '../core/block_ops.dart';
import '../models/outliner_state.dart';
import '../providers/outliner_provider.dart';
import 'draggable_block_widget.dart';

/// Core outliner list widget without any app-specific UI chrome.
///
/// Displays a hierarchical list of editable blocks with drag-and-drop support.
/// Generic type [T] allows using any block type (Freezed, FRB-generated, custom).
///
/// Gets reactive block operations from a Riverpod provider, which means the UI
/// automatically updates when blocks change.
///
/// Example usage:
/// ```dart
/// // Define a provider for your BlockOps<T>
/// final blockOpsProvider = StateNotifierProvider<MyBlockNotifier, BlockOps<MyBlock>>(...);
///
/// // Then use the widget
/// OutlinerListView<MyBlock>(
///   opsProvider: blockOpsProvider,
///   notifierProvider: myNotifierProvider,
///   config: OutlinerConfig(...),
/// )
/// ```
class OutlinerListView<T> extends ConsumerWidget {
  /// Provider that supplies BlockOps<T> (must be compatible with ProviderListenable<BlockOps<T>>)
  final ProviderListenable<BlockOps<T>> opsProvider;

  /// Provider for the outliner notifier (used for state-changing operations)
  final StateNotifierProvider<OutlinerNotifier<T>, OutlinerState<T>>? notifierProvider;

  /// Configuration for the outliner
  final OutlinerConfig config;

  /// Custom builder for rendering block content when not editing
  final Widget Function(BuildContext context, T block)? blockBuilder;

  /// Custom builder for rendering block content when editing
  final Widget Function(
    BuildContext context,
    T block,
    TextEditingController controller,
    FocusNode focusNode,
    VoidCallback onSubmitted,
  )?
  editingBlockBuilder;

  /// Custom builder for rendering bullet/collapse indicator
  final Widget Function(
    BuildContext context,
    T block,
    bool hasChildren,
    bool isCollapsed,
    VoidCallback? onToggle,
  )?
  bulletBuilder;

  /// Custom builder for TextField decoration when editing
  final InputDecoration Function(BuildContext context)?
  textFieldDecorationBuilder;

  /// Custom builder for drag feedback widget
  final Widget Function(BuildContext context, T block)? dragFeedbackBuilder;

  /// Custom builder for drop zone indicators
  final Widget Function(BuildContext context, bool isHighlighted, double depth)?
  dropZoneBuilder;

  /// Custom builder for empty state
  /// Parameters: context, callback to add first block
  /// If null, shows simple empty message
  final Widget Function(BuildContext context, VoidCallback onAddBlock)?
  emptyBuilder;

  const OutlinerListView({
    super.key,
    required this.opsProvider,
    this.notifierProvider,
    this.config = const OutlinerConfig(),
    this.blockBuilder,
    this.editingBlockBuilder,
    this.bulletBuilder,
    this.textFieldDecorationBuilder,
    this.dragFeedbackBuilder,
    this.dropZoneBuilder,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ops = ref.watch(opsProvider);
    final blocks = ops.getTopLevelBlocks();

    if (blocks.isEmpty) {
      return _buildEmptyState(context, ops);
    }

    return ListView(
      padding: config.padding,
      children: blocks
          .asMap()
          .entries
          .map(
            (entry) {
              final index = entry.key;
              final block = entry.value;
              final isLastSibling = index == blocks.length - 1;

              return DraggableBlockWidget<T>(
                key: ValueKey(ops.getId(block)),
                block: block,
                ops: ops,
                notifierProvider: notifierProvider,
                keyboardShortcutsEnabled: config.keyboardShortcutsEnabled,
                style: config.blockStyle,
                isLastSibling: isLastSibling,
                blockBuilder: blockBuilder,
                editingBlockBuilder: editingBlockBuilder,
                bulletBuilder: bulletBuilder,
                textFieldDecorationBuilder: textFieldDecorationBuilder,
                dragFeedbackBuilder: dragFeedbackBuilder,
                dropZoneBuilder: dropZoneBuilder,
              );
            },
          )
          .toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context, BlockOps<T> ops) {
    // This is called from build() which already has access to WidgetRef
    // We need to restructure this to accept ref as a parameter
    // For now, we'll make this a separate ConsumerWidget
    return _EmptyStateWidget<T>(
      ops: ops,
      notifierProvider: notifierProvider,
      emptyBuilder: emptyBuilder,
    );
  }
}

class _EmptyStateWidget<T> extends ConsumerWidget {
  final BlockOps<T> ops;
  final StateNotifierProvider<OutlinerNotifier<T>, OutlinerState<T>>? notifierProvider;
  final Widget Function(BuildContext context, VoidCallback onAddBlock)? emptyBuilder;

  const _EmptyStateWidget({
    required this.ops,
    this.notifierProvider,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onAddBlock() {
      final provider = notifierProvider ?? outlinerProvider;
      final notifier = ref.read(provider.notifier);
      final newBlock = ops.create(content: '');
      notifier.ops.addTopLevelBlock(newBlock);
    }

    if (emptyBuilder != null) {
      return emptyBuilder!(context, onAddBlock);
    }

    // Default simple empty widget
    return Center(
      child: GestureDetector(
        onTap: onAddBlock,
        child: const Text('No blocks. Tap to add one.'),
      ),
    );
  }
}
