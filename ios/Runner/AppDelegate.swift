import AudioToolbox
import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let splashAudio = SplashAudioPlayer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    try? AVAudioSession.sharedInstance().setCategory(
      .playback,
      mode: .default,
      options: [.mixWithOthers]
    )
    try? AVAudioSession.sharedInstance().setActive(true)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    splashAudio.register(messenger: messenger)
    AppSettingsChannel.register(messenger: messenger)
  }
}

enum AppSettingsChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.set.principles/app_settings",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "openNotificationSettings":
        DispatchQueue.main.async {
          let url: URL?
          if #available(iOS 16.0, *) {
            url = URL(string: UIApplication.openNotificationSettingsURLString)
          } else {
            url = URL(string: UIApplication.openSettingsURLString)
          }
          guard let url else {
            result(false)
            return
          }
          UIApplication.shared.open(url, options: [:]) { success in
            result(success)
          }
        }
      case "clearDeliveredNotifications":
        // Delivered tray only — pending schedules stay (MAUI ClearAll).
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Plays the splash WAV with AVAudioPlayer. Mixes with video_player so the
/// silent H.264 clip does not steal the session and make play() return false.
final class SplashAudioPlayer: NSObject, AVAudioPlayerDelegate {
  private var player: AVAudioPlayer?
  private var systemSoundId: SystemSoundID = 0

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
        let bytes = data.data
        DispatchQueue.main.async {
          do {
            try self.play(data: bytes)
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
        }
      case "stop":
        DispatchQueue.main.async {
          self.stop()
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func play(data: Data) throws {
    stop()
    guard !data.isEmpty else {
      throw NSError(
        domain: "SplashAudio",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Empty splash WAV"]
      )
    }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try session.setActive(true)

    let newPlayer = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
    newPlayer.delegate = self
    newPlayer.volume = 1
    newPlayer.numberOfLoops = 0
    newPlayer.prepareToPlay()
    player = newPlayer

    if newPlayer.play() {
      return
    }

    try session.setActive(true)
    if newPlayer.play() {
      return
    }

    playAsSystemSound(data: data)
  }

  private func playAsSystemSound(data: Data) {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("principles_epic_start.wav")
    try? data.write(to: url, options: .atomic)
    disposeSystemSound()
    var soundId: SystemSoundID = 0
    guard AudioServicesCreateSystemSoundID(url as CFURL, &soundId) == kAudioServicesNoError else {
      return
    }
    systemSoundId = soundId
    AudioServicesPlaySystemSoundWithCompletion(soundId) { [weak self] in
      self?.disposeSystemSound()
    }
  }

  private func disposeSystemSound() {
    guard systemSoundId != 0 else { return }
    AudioServicesDisposeSystemSoundID(systemSoundId)
    systemSoundId = 0
  }

  private func stop() {
    player?.stop()
    player = nil
    if systemSoundId != 0 {
      AudioServicesDisposeSystemSoundID(systemSoundId)
      systemSoundId = 0
    }
  }
}
