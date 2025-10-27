import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outliner_view/outliner_view.dart';

/// Material Design demo screen wrapping OutlinerListView.
///
/// This demonstrates how to use the core library widget with
/// Material UI chrome (AppBar, FAB, custom builders).
class DemoScreen extends ConsumerWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outliner View Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              final state = ref.read(outlinerProvider);
              final rootId = state.whenOrNull(
                loaded: (rootBlock, _, __, ___) => rootBlock.id,
              );
              if (rootId != null) {
                ref
                    .read(outlinerProvider.notifier)
                    .addChildBlock(rootId, Block.create(content: ''));
              }
            },
            tooltip: 'Add new block',
          ),
          const SizedBox(width: 8),
          FutureBuilder<int>(
            future: ref.read(outlinerProvider.notifier).totalBlocks,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '$count blocks',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: OutlinerListView(
        // Material-style loading indicator
        loadingBuilder: (context) {
          return const Center(child: CircularProgressIndicator());
        },
        // Material-style error display
        errorBuilder: (context, message, onRetry) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          );
        },
        // Material-style empty state
        emptyBuilder: (context, onAddBlock) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.note_add,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No blocks yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onAddBlock,
                  icon: const Icon(Icons.add),
                  label: const Text('Create your first block'),
                ),
              ],
            ),
          );
        },
        // Apply Material theme colors to block styles
        config: OutlinerConfig(
          blockStyle: BlockStyle(
            bulletColor: Theme.of(context).colorScheme.error,
            textStyle:
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ) ??
                TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            editingTextStyle:
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ) ??
                TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final state = ref.read(outlinerProvider);
          final rootId = state.whenOrNull(
            loaded: (rootBlock, _, __, ___) => rootBlock.id,
          );
          if (rootId != null) {
            ref
                .read(outlinerProvider.notifier)
                .addChildBlock(rootId, Block.create(content: ''));
          }
        },
        tooltip: 'Add new block',
        child: const Icon(Icons.add),
      ),
    );
  }
}
