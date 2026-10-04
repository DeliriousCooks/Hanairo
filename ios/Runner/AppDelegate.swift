import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Do not globally activate an AVAudioSession here.
    //
    // Activating a playback session at app launch can make iOS treat Booru as
    // the current media/audio app even when another app (such as YouTube) is
    // playing. That can interfere with the Dynamic Island / Now Playing
    // hand-off and cause taps on another app's media activity to return to
    // Booru.
    //
    // Video playback should configure audio only while Booru is actually
    // playing a video.

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }
}
