import Flutter
import UIKit
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // CRITICAL: Initialize Firebase FIRST before registering plugins
    // This ensures Firebase is ready when Flutter code tries to access it
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    
    // Register Flutter plugins AFTER Firebase is initialized
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
