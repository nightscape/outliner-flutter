import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/outliner_config.dart';
import '../models/block.dart';
import '../providers/outliner_provider.dart';
import 'draggable_block_widget.dart';

/// Core outliner list widget without any app-specific UI chrome.
///
/// Displays a hierarchical list of editable blocks with drag-and-drop support.
/// All UI states (loading, error, empty) are customizable via builder callbacks.
///
/// Example basic usage:
/// ```dart
/// OutlinerListView()
/// ```
///
/// Example with custom styling and builders:
/// ```dart
/// OutlinerListView(
///   config: OutlinerConfig(
///     blockStyle: BlockStyle(indentWidth: 32.0),
///   ),
///   loadingBuilder: (context) => MyCustomLoadingWidget(),
///   emptyBuilder: (context, onAddBlock) => MyEmptyState(onAdd: onAddBlock),
/// )
/// ```
class OutlinerListView extends ConsumerWidget {
  /// Configuration for the outliner
  final OutlinerConfig config;

  /// Custom builder for rendering block content when not editing
  final Widget Function(BuildContext context, Block block)? blockBuilder;

  /// Custom builder for rendering block content when editing
  final Widget Function(
    BuildContext context,
    Block block,
    TextEditingController controller,
    FocusNode focusNode,
    VoidCallback onSubmitted,
  )?
  editingBlockBuilder;

  /// Custom builder for rendering bullet/collapse indicator
  final Widget Function(
    BuildContext context,
    Block block,
    bool hasChildren,
    bool isCollapsed,
    VoidCallback? onToggle,
  )?
  bulletBuilder;

  /// Custom builder for TextField decoration when editing
  final InputDecoration Function(BuildContext context)?
  textFieldDecorationBuilder;

  /// Custom builder for drag feedback widget
  final Widget Function(BuildContext context, Block block)? dragFeedbackBuilder;

  /// Custom builder for drop zone indicators
  final Widget Function(BuildContext context, bool isHighlighted, double depth)?
  dropZoneBuilder;

  /// Custom builder for loading state
  /// If null, shows a simple centered loading indicator
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Custom builder for error state
  /// Parameters: context, error message, retry callback
  /// If null, shows simple error text with retry button
  final Widget Function(
    BuildContext context,
    String errorMessage,
    VoidCallback onRetry,
  )?
  errorBuilder;

  /// Custom builder for empty state
  /// Parameters: context, callback to add first block
  /// If null, shows simple empty message
  final Widget Function(BuildContext context, VoidCallback onAddBlock)?
  emptyBuilder;

  const OutlinerListView({
    super.key,
    this.config = const OutlinerConfig(),
    this.blockBuilder,
    this.editingBlockBuilder,
    this.bulletBuilder,
    this.textFieldDecorationBuilder,
    this.dragFeedbackBuilder,
    this.dropZoneBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlinerState = ref.watch(outlinerProvider);

    return outlinerState.when(
      loading: () => _buildLoadingState(context),
      error: (message) => _buildErrorState(context, ref, message),
      loaded: (blocks, focusedBlockId) => _buildLoadedState(context, blocks),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    if (loadingBuilder != null) {
      return loadingBuilder!(context);
    }

    // Default simple loading widget
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String message) {
    void onRetry() {
      ref.read(outlinerProvider.notifier).loadBlocks();
    }

    if (errorBuilder != null) {
      return errorBuilder!(context, message, onRetry);
    }

    // Default simple error widget
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Error loading blocks'),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 16),
          GestureDetector(onTap: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, List<Block> blocks) {
    if (blocks.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView(
      padding: config.padding,
      children: blocks
          .map(
            (block) => DraggableBlockWidget(
              key: ValueKey(block.id),
              block: block,
              keyboardShortcutsEnabled: config.keyboardShortcutsEnabled,
              style: config.blockStyle,
              blockBuilder: blockBuilder,
              editingBlockBuilder: editingBlockBuilder,
              bulletBuilder: bulletBuilder,
              textFieldDecorationBuilder: textFieldDecorationBuilder,
              dragFeedbackBuilder: dragFeedbackBuilder,
              dropZoneBuilder: dropZoneBuilder,
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    // Empty state needs access to WidgetRef, so we wrap in Consumer
    return Consumer(
      builder: (context, ref, _) {
        void onAddBlock() {
          ref
              .read(outlinerProvider.notifier)
              .addRootBlock(Block.create(content: ''));
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
      },
    );
  }
}
