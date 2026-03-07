import 'package:flutter/material.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';

// Example usage of the new TouchBar helper methods
class TouchBarExample extends StatelessWidget {
  const TouchBarExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TouchBar Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _showDialogWithTouchBar(context),
              child: const Text('Show Dialog with TouchBar'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showBottomSheetWithTouchBar(context),
              child: const Text('Show Bottom Sheet with TouchBar'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showManualTouchBar(context),
              child: const Text('Show Manual TouchBar (old way)'),
            ),
          ],
        ),
      ),
    );
  }

  // NEW WAY: Using helper methods that automatically clear TouchBar
  void _showDialogWithTouchBar(BuildContext context) async {
    await TouchBarHelper.showDialogWithTouchBar<String>(
      context: context,
      touchBarActions: [
        TouchBarHelperAction(
          label: 'Cancel',
          action: () => Navigator.pop(context, 'cancelled'),
        ),
        TouchBarHelperAction(
          label: 'Save',
          action: () => Navigator.pop(context, 'saved'),
          isPrimary: true,
        ),
      ],
      builder: (context) => AlertDialog(
        title: const Text('Dialog with TouchBar'),
        content: const Text(
          'This dialog has TouchBar buttons that will disappear when closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancelled'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'saved'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // TouchBar is automatically cleared here!
    print('Dialog closed - TouchBar should be cleared');
  }

  void _showBottomSheetWithTouchBar(BuildContext context) async {
    await TouchBarHelper.showModalBottomSheetWithTouchBar<String>(
      context: context,
      touchBarActions: [
        TouchBarHelperAction(
          label: 'Close',
          action: () => Navigator.pop(context, 'closed'),
          isPrimary: true,
        ),
      ],
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bottom Sheet with TouchBar'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'closed'),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );

    // TouchBar is automatically cleared here!
    print('Bottom sheet closed - TouchBar should be cleared');
  }

  // OLD WAY: Manual TouchBar management (buttons may linger)
  void _showManualTouchBar(BuildContext context) {
    // Set TouchBar manually
    TouchBarHelper.setPopupTouchBar(
      context: context,
      actions: [
        TouchBarHelperAction(
          label: 'Manual',
          action: () => print('Manual button pressed'),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual TouchBar'),
        content: const Text(
          'This uses the old manual way - TouchBar may not clear properly.',
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
}

// Usage instructions for your existing code:
/*

MIGRATION GUIDE:
================

OLD WAY (buttons may linger):
-----------------------------
showModalBottomSheet(
  context: context,
  builder: (context) {
    TouchBarHelper.setPopupTouchBar(
      context: context,
      actions: [TouchBarHelperAction(...)],
    );
    return Container(...);
  },
).then((_) {
  // You had to manually restore dashboard TouchBar
  _updateTouchBar();
});

NEW WAY (buttons automatically disappear):
------------------------------------------
TouchBarHelper.showModalBottomSheetWithTouchBar(
  context: context,
  touchBarActions: [TouchBarHelperAction(...)],
  builder: (context) => Container(...),
);
// TouchBar is automatically cleared when dialog closes!

For dialogs, use:
TouchBarHelper.showDialogWithTouchBar(
  context: context,
  touchBarActions: [TouchBarHelperAction(...)],
  builder: (context) => AlertDialog(...),
);

*/
