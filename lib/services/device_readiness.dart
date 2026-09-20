import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceReadiness extends ChangeNotifier {
  DeviceReadiness() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'startRequested') onStartRequested?.call();
    });
  }
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    onStartRequested = null;
    channel.setMethodCallHandler(null);
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  VoidCallback? onStartRequested;
  Future<bool> consumeStartRequest() async {
    try {
      return await channel.invokeMethod<bool>('consumeStartRequest') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static const channel = MethodChannel('inemuri/readiness');
  int? alarmVolume;
  bool? notifications;
  bool canAddTile = false;
  bool tileAdded = false;
  bool busy = false;
  bool get silent => alarmVolume == 0;
  Future<void> refresh() async {
    try {
      final state = await channel.invokeMapMethod<String, dynamic>('status');
      alarmVolume = state?['alarmVolume'] as int?;
      notifications = state?['notifications'] as bool?;
      canAddTile = state?['canAddTile'] == true;
    } on PlatformException {
      alarmVolume = null;
      notifications = null;
    } on MissingPluginException {
      alarmVolume = null;
      notifications = null;
    }
    _notify();
  }

  Future<bool> open(String action) async {
    if (busy) return false;
    busy = true;
    _notify();
    try {
      final ok = await channel.invokeMethod<bool>(action) ?? false;
      if (action == 'addTile' && ok) tileAdded = true;
      return ok;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }
}
