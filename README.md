# outliner_view

A platform-agnostic Flutter library for hierarchical block-based editing, inspired by LogSeq and Notion.

## Features

- **Hierarchical Block Structure**: Nested blocks with unlimited depth
- **Inline Editing**: Click to edit, automatic focus management
- **Drag-and-Drop Reordering**: Intuitive three-zone drag system (before, after, as-child)
- **Collapsible Sections**: Expand/collapse blocks with children
- **Platform-Agnostic**: No hardcoded Material/Cupertino dependencies
- **Customizable Rendering**: Builder callbacks for complete UI control
- **Immutable State**: Clean Riverpod + Freezed architecture
- **Repository Pattern**: Flexible persistence layer
- **Generic Block Support**: Type class abstraction for custom block types (FRB, built_value, etc.)

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  outliner_view: ^0.1.0
  flutter_riverpod: ^2.6.1  # Required for state management
  hooks_riverpod: ^2.6.1     # Required (provides HookConsumerWidget)
  flutter_hooks: ^0.20.5     # Required (provides hook functions like useState, useEffect)
```

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outliner_view/outliner_view.dart';

void main() {
  runApp(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: Text('My Outliner')),
          body: OutlinerListView(),
        ),
      ),
    ),
  );
}
```

## Customization

### Styling

Customize appearance with `BlockStyle` and `OutlinerConfig`:

```dart
OutlinerListView(
  config: OutlinerConfig(
    blockStyle: BlockStyle(
      indentWidth: 32.0,
      bulletSize: 8.0,
      bulletColor: Colors.blue,
      textStyle: TextStyle(fontSize: 18, color: Colors.black87),
      emptyTextStyle: TextStyle(fontSize: 16, color: Colors.grey),
    ),
    keyboardShortcutsEnabled: true,
    padding: EdgeInsets.all(24),
  ),
)
```

### Custom Block Rendering

Use builder callbacks to customize how blocks are rendered:

```dart
OutlinerListView(
  // Custom block content when not editing
  blockBuilder: (context, block) {
    return MarkdownWidget(content: block.content);
  },

  // Custom block content when editing
  editingBlockBuilder: (context, block, controller, focusNode, onSubmitted) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Edit here...',
      ),
      onSubmitted: (_) => onSubmitted(),
    );
  },

  // Custom bullet/collapse indicator
  bulletBuilder: (context, block, hasChildren, isCollapsed, onToggle) {
    if (hasChildren) {
      return IconButton(
        icon: Icon(isCollapsed ? Icons.chevron_right : Icons.expand_more),
        onPressed: onToggle,
      );
    }
    return Icon(Icons.circle, size: 8);
  },

  // Custom TextField decoration (ignored if editingBlockBuilder is provided)
  textFieldDecorationBuilder: (context) {
    return InputDecoration(
      border: OutlineInputBorder(),
      hintText: 'Type something...',
    );
  },
)
```

#### Available Builder Callbacks

The library provides several builder callbacks for customization:

- **`blockBuilder`**: Renders block content when **not editing**. Use this for custom rich text display, markdown rendering, or any custom content visualization.
  - Parameters: `context`, `block`
  - Default: Plain text display

- **`editingBlockBuilder`**: Renders block content when **editing**. Use this for custom editors, rich text editing, or specialized input widgets.
  - Parameters: `context`, `block`, `controller`, `focusNode`, `onSubmitted`
  - Default: Simple `TextField` with `textFieldDecorationBuilder` decoration
  - Note: When provided, `textFieldDecorationBuilder` is ignored

- **`bulletBuilder`**: Custom bullet/collapse indicator for each block.
  - Parameters: `context`, `block`, `hasChildren`, `isCollapsed`, `onToggle`
  - Default: Circle bullet or arrow icon

- **`textFieldDecorationBuilder`**: Custom decoration for the default TextField when editing (only used if `editingBlockBuilder` is not provided).
  - Parameters: `context`
  - Default: Minimal decoration with no border

- **`dragFeedbackBuilder`**: Custom widget shown while dragging a block.
  - Parameters: `context`, `block`
  - Default: Material-style feedback

- **`dropZoneBuilder`**: Custom drop zone indicators.
  - Parameters: `context`, `isHighlighted`, `depth`
  - Default: Colored bars

### State Management

Access the outliner state and operations:

```dart
Consumer(
  builder: (context, ref, child) {
    // Watch state
    final state = ref.watch(outlinerProvider);

    // Access notifier for operations
    final notifier = ref.read(outlinerProvider.notifier);

    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            notifier.addRootBlock(Block.create(content: 'New block'));
          },
          child: Text('Add Block'),
        ),
        Expanded(child: OutlinerListView()),
      ],
    );
  },
)
```

### Custom Persistence

Implement your own repository for custom storage:

```dart
class FirestoreOutlinerRepository implements OutlinerRepository {
  @override
  Future<List<Block>> loadBlocks() async {
    // Load from Firestore
  }

  @override
  Future<void> saveBlocks(List<Block> blocks) async {
    // Save to Firestore
  }
}

// Use in your app
final outlinerProvider = StateNotifierProvider<OutlinerNotifier<Block>, OutlinerState<Block>>(
  (ref) => OutlinerNotifier(FirestoreOutlinerRepository()),
);
```

### Custom Block Types (Advanced)

The library supports **custom block implementations** through a type class abstraction. This is particularly useful when working with code generation tools like Flutter Rust Bridge (FRB).

#### Using with FRB-Generated Blocks

1. **Create a BlockOps implementation** for your FRB type:

```dart
import 'package:outliner_view/outliner_view.dart';
import 'package:your_app/frb_generated.dart';

class FrbBlockOps implements BlockOps<FrbBlock> {
  const FrbBlockOps();

  @override
  String getId(FrbBlock block) => block.id;

  @override
  String getContent(FrbBlock block) => block.content;

  @override
  List<FrbBlock> getChildren(FrbBlock block) => block.children;

  @override
  bool getIsCollapsed(FrbBlock block) => block.isCollapsed;

  @override
  DateTime getCreatedAt(FrbBlock block) => block.createdAt;

  @override
  DateTime getUpdatedAt(FrbBlock block) => block.updatedAt;

  @override
  FrbBlock copyWith(
    FrbBlock block, {
    String? content,
    List<FrbBlock>? children,
    bool? isCollapsed,
  }) {
    return FrbBlock(
      id: block.id,
      content: content ?? block.content,
      children: children ?? block.children,
      isCollapsed: isCollapsed ?? block.isCollapsed,
      createdAt: block.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  FrbBlock create({
    String? id,
    required String content,
    List<FrbBlock>? children,
    bool? isCollapsed,
  }) {
    return FrbBlock(
      id: id ?? Uuid().v4(),
      content: content,
      children: children ?? [],
      isCollapsed: isCollapsed ?? false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
```

2. **Create a repository** with your custom type:

```dart
final frbRepository = InMemoryOutlinerRepositoryBase<FrbBlock>(
  ops: const FrbBlockOps(),
);
```

3. **Update your providers**:

```dart
final frbOutlinerProvider =
  StateNotifierProvider<OutlinerNotifier<FrbBlock>, OutlinerState<FrbBlock>>(
    (ref) {
      return OutlinerNotifier(frbRepository);
    },
  );
```

**Benefits**:
- ✅ No conversion boilerplate between your types and the outliner
- ✅ Works with code-generated types (FRB, built_value, etc.)
- ✅ Type-safe operations
- ✅ Full control over block implementation

**See `lib/core/README.md` for complete documentation.**

## API Reference

### Core Widgets

- **`OutlinerListView`**: Main widget displaying the block hierarchy
- **`BlockWidget`**: Individual block with editing capabilities
- **`DraggableBlockWidget`**: Drag-and-drop wrapper

### State Management

- **`outlinerProvider`**: Main state provider
- **`OutlinerNotifier`**: State management with operations:
  - `addRootBlock(Block)`: Add block at root level
  - `moveBlock(String id, String? parentId, int index)`: Move/reorder blocks
  - `indentBlock(String id)` / `outdentBlock(String id)`: Change nesting
  - `updateBlock(String id, String content)`: Update block content
  - `splitBlock(String id, int cursorPosition)`: Split at cursor
  - `toggleBlockCollapse(String id)`: Expand/collapse
  - `setFocusedBlock(String id)`: Track focus

### Models

- **`Block`**: Immutable block model (Freezed)
- **`OutlinerState<T>`**: State union (loading | loaded | error)
- **`BlockStyle`**: Visual styling configuration
- **`OutlinerConfig`**: Global configuration

### Core Abstractions (Advanced)

- **`BlockOps<T>`**: Type class interface for block operations
- **`FreezedBlockOps`**: BlockOps implementation for Freezed Block type
- **`InMemoryOutlinerRepositoryBase<T>`**: Generic repository base class

## Mobile Support

Disable keyboard shortcuts for mobile and use custom UI triggers:

```dart
OutlinerListView(
  config: OutlinerConfig(
    keyboardShortcutsEnabled: false,
  ),
)

// Custom UI controls
Consumer(
  builder: (context, ref, child) {
    final notifier = ref.read(outlinerProvider.notifier);
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.format_indent_increase),
          onPressed: () => notifier.indentFocusedBlock(),
        ),
        IconButton(
          icon: Icon(Icons.format_indent_decrease),
          onPressed: () => notifier.outdentFocusedBlock(),
        ),
      ],
    );
  },
)
```

## Example

See the `example/` directory for a complete Material Design implementation showing:
- Custom Material UI chrome (AppBar, FAB, empty states)
- Custom builders with Material widgets
- Block counter and add button
- Error handling and loading states

Run the example:

```bash
cd example
flutter run
```

## Testing

The library includes comprehensive property-based tests using `dartproptest` to ensure:
- Structural invariants are maintained
- No block duplication or loss
- Parent-child relationships stay consistent
- Drag-and-drop operations preserve tree integrity

Run tests:

```bash
flutter test
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions welcome! Please open an issue or PR on [GitHub](https://github.com/nightscape/outliner_view).
