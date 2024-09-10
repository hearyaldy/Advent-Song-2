// AppDelegate.swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let shareChannel = FlutterMethodChannel(name: "com.example.advent_song/share",
                                            binaryMessenger: controller.binaryMessenger)

    shareChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "share" {
            if let args = call.arguments as? [String: Any],
               let title = args["title"] as? String,
               let lyrics = args["lyrics"] as? String {
                self.shareSong(content: "\(title)\n\n\(lyrics)")
                result(nil)
            } else {
                result(FlutterError(code: "ERROR", message: "Invalid arguments", details: nil))
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func shareSong(content: String) {
    let activityViewController = UIActivityViewController(activityItems: [content], applicationActivities: nil)
    if let viewController = window?.rootViewController {
        viewController.present(activityViewController, animated: true, completion: nil)
    }
  }
}
