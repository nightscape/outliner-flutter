# outliner_view Example

A demonstration app showing how to use the `outliner_view` library with Material Design.

## Features Demonstrated

This example app shows:

- **Material Design Integration**: AppBar, FloatingActionButton, theme integration
- **Custom Builders**: Using Material widgets for bullets and UI chrome
- **State Management**: Proper Riverpod integration with the library
- **Custom UI Elements**:
  - Block counter in AppBar
  - Material-styled empty state
  - Material-styled error state with retry
  - Material-styled loading indicator
- **Theme Support**: Material 3 with light and dark modes

## Running the Example

### Prerequisites

- Flutter SDK 3.9.2 or later
- Dart SDK compatible with Flutter

### Steps

1. **Navigate to the example directory**:
   ```bash
   cd example
   ```

2. **Get dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   # For macOS desktop
   flutter run -d macos

   # For web
   flutter run -d chrome

   # For iOS simulator
   flutter run -d ios

   # For Android emulator
   flutter run -d android
   ```

## Code Structure

```
example/
├── lib/
│   ├── main.dart                 # App entry point with theme setup
│   └── screens/
│       └── demo_screen.dart      # Material Design wrapper for OutlinerListView
└── pubspec.yaml                  # Example app dependencies
```

## Key Implementation Details

### Material Integration

The `DemoScreen` widget shows how to wrap the core `OutlinerListView` with Material Design chrome:

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('Outliner View Example'),
    actions: [
      IconButton(...),  // Add block button
      Text(...),        // Block counter
    ],
  ),
  body: OutlinerListView(
    bulletBuilder: (context, block, hasChildren, isCollapsed, onToggle) {
      // Use Material Icons for bullets
      return Icon(isCollapsed ? Icons.arrow_right : Icons.arrow_drop_down);
    },
    // ... other Material-styled builders
  ),
  floatingActionButton: FloatingActionButton(...),
)
```

### Custom State Builders

The example demonstrates all three customizable state builders:

1. **Loading State**: Material CircularProgressIndicator
2. **Error State**: Material error display with retry button
3. **Empty State**: Material empty state with call-to-action

### Theme Integration

Shows how to integrate the library with Material theme:

```dart
config: OutlinerConfig(
  blockStyle: BlockStyle(
    bulletColor: Theme.of(context).colorScheme.primary,
    textStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
    ),
  ),
)
```

## What You'll Learn

By studying this example, you'll learn how to:

1. **Integrate with Material Design**: Wrap the core library with Material widgets
2. **Customize Appearance**: Use builder callbacks with Material widgets
3. **Manage State**: Connect Riverpod providers to UI actions
4. **Handle Edge Cases**: Loading, error, and empty states
5. **Apply Theming**: Integrate with Material theme system

## Modifying the Example

Feel free to experiment:

- Try different Material widgets in the builders
- Add more custom UI controls in the AppBar
- Implement your own custom repository
- Add Material dialogs for block operations
- Integrate with Material navigation

## Going Further

For a production app, you might want to add:

- Persistence (local storage or cloud)
- Search functionality
- Export/import features
- User authentication
- Custom block types (markdown, code, etc.)
- Undo/redo support

See the main library [README](../README.md) for more information on customization options.
