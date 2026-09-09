import AVFoundation
import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow {
  private let splashAudio = SplashAudioPlayer()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = NSColor.black
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.backgroundColor = NSColor.black

    RegisterGeneratedPlugins(registry: flutterViewController)
    let messenger = flutterViewController.engine.binaryMessenger
    registerAppIconChannel(messenger: messenger)
    registerAppSettingsChannel(messenger: messenger)
    splashAudio.register(messenger: messenger)

    super.awakeFromNib()
  }

  private func registerAppIconChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.set.principles/app_icon",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let name = call.arguments as? String else {
        result(
          FlutterError(
            code: "bad_args",
            message: "Expected icon name string",
            details: nil
          )
        )
        return
      }
      if name == "blue" {
        NSApp.applicationIconImage = NSImage(named: "AppIconBlue")
      } else {
        NSApp.applicationIconImage = nil
      }
      result(nil)
    }
  }

  private func registerAppSettingsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.set.principles/app_settings",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "openNotificationSettings":
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
          ?? URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        guard let url else {
          result(false)
          return
        }
        result(NSWorkspace.shared.open(url))
      case "clearDeliveredNotifications":
        // Delivered Notification Center only — pending schedules stay.
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

final class SplashAudioPlayer: NSObject {
  private var player: AVAudioPlayer?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.set.principles/splash_audio",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "play":
        guard let data = call.arguments as? FlutterStandardTypedData else {
          result(
            FlutterError(
              code: "bad_args",
              message: "Expected WAV bytes",
              details: nil
            )
          )
          return
        }
        do {
          try self.play(data: data.data)
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "play_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      case "stop":
        self.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func play(data: Data) throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("principles_epic_start.wav")
    try data.write(to: url, options: .atomic)
    player = try AVAudioPlayer(contentsOf: url)
    player?.volume = 1
    player?.prepareToPlay()
    if player?.play() != true {
      throw NSError(
        domain: "SplashAudio",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "AVAudioPlayer.play() returned false"]
      )
    }
  }

  private func stop() {
    player?.stop()
    player = nil
  }
}
