import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var volumeObserver: NSKeyValueObservation?
  private var volumeChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "app.booruwave/hardware_volume",
        binaryMessenger: controller.binaryMessenger
      )
      volumeChannel = channel

      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
      try? session.setActive(true)

      volumeObserver = session.observe(\AVAudioSession.outputVolume, options: [.old, .new]) { [weak self] _, change in
        guard
          let old = change.oldValue as? Float,
          let new = change.newValue as? Float,
          new > old + 0.001
        else { return }

        DispatchQueue.main.async {
          self?.volumeChannel?.invokeMethod("volumeUp", arguments: new)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  deinit {
    volumeObserver?.invalidate()
  }
}
