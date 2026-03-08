import Flutter
import UIKit
import FirebaseCore
import FirebaseFirestore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase before Flutter runs so we can set Firestore settings first.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    // Use memory-only cache to avoid LevelDB lock on second launch (firebase-ios-sdk#3967).
    let db = Firestore.firestore()
    var settings = db.settings
    settings.cacheSettings = MemoryCacheSettings()
    db.settings = settings

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
