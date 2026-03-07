import 'package:flutter/material.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';

// Simple test to verify TouchBar functionality compiles correctly
void main() {
  runApp(const TouchBarTestApp());
}

class TouchBarTestApp extends StatelessWidget {
  const TouchBarTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TouchBar Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TouchBarTestPage(),
    );
  }
}

class TouchBarTestPage extends StatefulWidget {
  const TouchBarTestPage({super.key});

  @override
  State<TouchBarTestPage> createState() => _TouchBarTestPageState();
}

class _TouchBarTestPageState extends State<TouchBarTestPage> {
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    // Test that TouchBar methods compile and don't crash
    try {
      TouchBarHelper.setDashboardTouchBar();
      setState(() => _status = 'TouchBar initialized');
    } catch (e) {
      setState(() => _status = 'TouchBar error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TouchBar Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testNewTouchBarMethods,
              child: const Text('Test New TouchBar Methods'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testClearTouchBar,
              child: const Text('Test Clear TouchBar'),
            ),
          ],
        ),
      ),
    );
  }

  void _testNewTouchBarMethods() async {
    try {
      // Test the new helper methods compile correctly
      await TouchBarHelper.showDialogWithTouchBar<String>(
        context: context,
        touchBarActions: [
          TouchBarHelperAction(
            label: 'Test',
            action: () => Navigator.pop(context, 'test'),
          ),
        ],
        builder: (context) => AlertDialog(
          title: const Text('Test Dialog'),
          content: const Text('Testing new TouchBar methods'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'test'),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      setState(() => _status = 'Dialog test completed');
    } catch (e) {
      setState(() => _status = 'Dialog test error: $e');
    }
  }

  void _testClearTouchBar() {
    try {
      TouchBarHelper.clearTouchBar();
      setState(() => _status = 'TouchBar cleared');
    } catch (e) {
      setState(() => _status = 'Clear error: $e');
    }
  }
}
