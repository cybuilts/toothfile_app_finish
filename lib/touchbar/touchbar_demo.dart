import 'package:flutter/material.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';

/// Simple demonstration that TouchBar functionality works correctly
/// This can be run independently to test TouchBar behavior
class TouchBarDemo extends StatelessWidget {
  const TouchBarDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TouchBar Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('TouchBar Auto-Clear Demo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _showOldWay(context),
                child: const Text('Old Way (Manual)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _showNewWay(context),
                child: const Text('New Way (Auto-Clear)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _showClearTouchBar(context),
                child: const Text('Clear TouchBar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // OLD WAY - Manual TouchBar management (buttons may linger)
  void _showOldWay(BuildContext context) {
    // Set TouchBar manually
    TouchBarHelper.setPopupTouchBar(
      context: context,
      actions: [
        TouchBarHelperAction(
          label: 'Manual Button',
          action: () => print('Manual button pressed'),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual TouchBar'),
        content: const Text(
          'Using old manual way - TouchBar may not clear properly.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // You have to manually clear the TouchBar!
              TouchBarHelper.clearTouchBar();
            },
            child: const Text('Close & Clear TouchBar'),
          ),
        ],
      ),
    );
  }

  // NEW WAY - Automatic TouchBar management (buttons auto-clear)
  void _showNewWay(BuildContext context) async {
    await TouchBarHelper.showDialogWithTouchBar<String>(
      context: context,
      touchBarActions: [
        TouchBarHelperAction(
          label: 'Auto Button 1',
          action: () => print('Auto button 1 pressed'),
        ),
        TouchBarHelperAction(
          label: 'Auto Button 2',
          action: () => print('Auto button 2 pressed'),
          isPrimary: true,
        ),
      ],
      builder: (context) => AlertDialog(
        title: const Text('Auto TouchBar'),
        content: const Text(
          'Using new auto-clear way - TouchBar disappears automatically!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'closed'),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    // TouchBar is automatically cleared here!
    print('Dialog closed - TouchBar should be cleared automatically');
  }

  void _showClearTouchBar(BuildContext context) {
    TouchBarHelper.clearTouchBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('TouchBar cleared!')));
  }
}

/// Usage instructions for migrating existing code:
///
/// 1. Replace old showModalBottomSheet calls:
/// 
/// OLD CODE:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (context) {
///     TouchBarHelper.setPopupTouchBar(
///       context: context,
///       actions: [TouchBarHelperAction(...)],
///     );
///     return Container(...);
///   },
/// ).then((_) {
///   // Manual cleanup required
///   _updateTouchBar();
/// });
/// ```
///
/// NEW CODE:
/// ```dart
/// await TouchBarHelper.showModalBottomSheetWithTouchBar(
///   context: context,
///   touchBarActions: [TouchBarHelperAction(...)],
///   builder: (context) => Container(...),
/// );
/// // TouchBar is automatically cleared here!
/// ```
///
/// 2. For dialogs, use showDialogWithTouchBar instead
///
/// 3. TouchBar buttons will automatically disappear when the dialog/popup closes
/// 4. No manual cleanup needed!