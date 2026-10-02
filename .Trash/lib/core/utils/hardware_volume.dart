import 'dart:async';
import 'package:flutter/services.dart';

/// Bridges iOS hardware-volume changes into Dart. The native side reports
/// only upward volume changes; viewers use that as an intuitive "unmute"
/// gesture when a video is muted.
class HardwareVolumeService {
  HardwareVolumeService._();
  static final HardwareVolumeService instance = HardwareVolumeService._();

  static const _channel = MethodChannel('app.booruwave/hardware_volume');
  final StreamController<void> _volumeUpController =
      StreamController<void>.broadcast();
  bool _initialized = false;

  Stream<void> get onVolumeUp => _volumeUpController.stream;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUp') {
        _volumeUpController.add(null);
      }
    });
  }

  void dispose() {
    _volumeUpController.close();
  }
}
