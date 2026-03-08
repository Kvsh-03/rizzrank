import Cocoa
import FlutterMacOS
import FirebaseCore
import FirebaseFirestore

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Configure Firebase before Flutter runs so we can set Firestore settings first.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    // Use memory-only cache to avoid LevelDB lock files (parity with iOS AppDelegate).
    let db = Firestore.firestore()
    var settings = db.settings
    settings.cacheSettings = MemoryCacheSettings()
    db.settings = settings

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
