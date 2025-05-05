import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Заметьте, что статические поля следует определить выше конкретного состояния
  static const platform = MethodChannel('samples.flutter.dev/files');

  bool _trackingEnabled = false;

  @override
  void initState() {
    super.initState();
    checkTrackingStatus(); // Проверка состояния трекинга при старте
  }

  Future<void> checkTrackingStatus() async {
    try {
      final bool result = await platform.invokeMethod('isTrackingEnabled');
      setState(() {
        _trackingEnabled = result;
      });
    } on PlatformException catch (e) {
      print("Failed to check tracking status: '${e.message}'.");
    }
  }

  Future<void> toggleTracking() async {
    try {
      final bool result = await platform.invokeMethod('toggleTracking');
      setState(() {
        _trackingEnabled = result;
      });
    } on PlatformException catch (e) {
      print("Failed to toggle tracking: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Directory Tracking Demo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_trackingEnabled ? 'Tracking Enabled' : 'Tracking Disabled'),
              ElevatedButton(
                onPressed: toggleTracking,
                child: Text(
                  _trackingEnabled ? 'Stop Tracking' : 'Start Tracking',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
