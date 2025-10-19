# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `editingBlockBuilder` callback for custom editing widgets
  - Allows full customization of the editing experience
  - Provides access to `TextEditingController`, `FocusNode`, and `onSubmitted` callback
  - Works seamlessly with sensible defaults when not provided

### Documentation
- Clarified dependency requirements in README and CLAUDE.md
  - Explained that both `flutter_hooks` and `hooks_riverpod` are required
  - `flutter_hooks` provides hook functions (useState, useEffect, etc.)
  - `hooks_riverpod` provides HookConsumerWidget for combining hooks with Riverpod
  - Both packages are needed in version 2.6.1 as hooks_riverpod doesn't re-export hooks

## [0.1.0] - 2025-10-20

### Added
- Initial release of outliner_view library
- Platform-agnostic hierarchical block-based editing
- Core widgets: `OutlinerListView`, `BlockWidget`, `DraggableBlockWidget`
- Immutable state management with Riverpod + Freezed
- Drag-and-drop reordering with three drop zones (before, after, as-child)
- Collapsible/expandable sections
- Inline block editing with focus management
- Customizable rendering via builder callbacks:
  - `blockBuilder` for custom block content when not editing
  - `bulletBuilder` for custom bullets/collapse indicators
  - `textFieldDecorationBuilder` for custom TextField styling
- Configuration classes: `BlockStyle` and `OutlinerConfig`
- Repository pattern for flexible persistence (`OutlinerRepository` interface)
- Default in-memory repository implementation
- Keyboard shortcuts support (Tab/Shift+Tab for indent/outdent, Enter for split)
- Mobile-friendly focus tracking with convenience methods:
  - `indentFocusedBlock()`, `outdentFocusedBlock()`, `removeFocusedBlock()`
  - `splitFocusedBlock()`, `addChildToFocusedBlock()`
- Comprehensive property-based tests using `dartproptest`
- Example app demonstrating Material Design integration
- Complete API documentation

### Features
- Unlimited nesting depth for hierarchical blocks
- Automatic prevention of circular parent-child relationships
- No block duplication - all structural invariants maintained
- Clean separation between library core and UI framework
- Full customization without subclassing

[0.1.0]: https://github.com/nightscape/outliner_view/releases/tag/v0.1.0
