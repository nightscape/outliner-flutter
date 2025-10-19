// A platform-agnostic Flutter library for hierarchical block-based editing.
//
// This library provides an outliner interface similar to LogSeq/Notion with:
// - Hierarchical block structure with nested children
// - Inline editing with focus management
// - Drag-and-drop reordering (before, after, as-child)
// - Collapsible sections
// - Customizable rendering via builder callbacks
// - Immutable state management with Riverpod
// - Repository pattern for flexible persistence
//
// ## Quick Start
//
// ```dart
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:outliner_view/outliner_view.dart';
//
// void main() {
//   runApp(
//     ProviderScope(
//       child: MaterialApp(
//         home: Scaffold(
//           appBar: AppBar(title: Text('My Outliner')),
//           body: OutlinerListView(),
//         ),
//       ),
//     ),
//   );
// }
// ```
//
// ## Customization
//
// Customize appearance with [BlockStyle] and [OutlinerConfig]:
//
// ```dart
// OutlinerListView(
//   config: OutlinerConfig(
//     blockStyle: BlockStyle(
//       indentWidth: 32.0,
//       bulletSize: 8.0,
//       textStyle: TextStyle(fontSize: 18),
//     ),
//   ),
// )
// ```
//
// Use builder callbacks for custom rendering:
//
// ```dart
// OutlinerListView(
//   // Custom display widget (when not editing)
//   blockBuilder: (context, block) {
//     return MyCustomBlockWidget(block: block);
//   },
//   // Custom editing widget (when editing)
//   editingBlockBuilder: (context, block, controller, focusNode, onSubmitted) {
//     return MyCustomEditor(
//       controller: controller,
//       focusNode: focusNode,
//       onSubmitted: onSubmitted,
//     );
//   },
//   // Custom bullet/collapse indicator
//   bulletBuilder: (context, block, hasChildren, isCollapsed, onToggle) {
//     return MyCustomBullet(/* ... */);
//   },
// )
// ```

// Models
export 'models/block.dart';
export 'models/outliner_state.dart';
export 'models/drag_data.dart';

// State Management
export 'providers/outliner_provider.dart';

// Repository Pattern
export 'repositories/outliner_repository.dart';
export 'repositories/in_memory_outliner_repository.dart';

// Configuration
export 'config/block_style.dart';
export 'config/outliner_config.dart';

// Widgets
export 'widgets/outliner_list_view.dart';
export 'widgets/block_widget.dart';
export 'widgets/draggable_block_widget.dart';
