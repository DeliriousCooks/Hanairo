import 'dart:async';
import 'package:flutter/services.dart';

/// Optional bridge for hardware-volume events.
///
/// The iOS app no longer installs a global AVAudioSession observer at launch,
/// because doing so can interfere with iOS Now Playing / Dynamic Island
/// ownership when another app (for example YouTube) is playing.
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
