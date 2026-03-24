import UIKit
import Flutter
import AVKit
import AVFoundation
import CoreMedia

@main
@objc class AppDelegate: FlutterAppDelegate,
    FlutterImplicitEngineDelegate,
    AVPictureInPictureControllerDelegate {

    private var intentChannel: FlutterMethodChannel?
    private var pipPlayer: AVPlayer?
    private var pipPlayerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?
    private var pipHostView: UIView?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let channel = FlutterMethodChannel(
            name: "com.predidit.kazumi/intent",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        intentChannel = channel
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "openWithReferer":
                guard let args = call.arguments as? [String: Any],
                      let url = args["url"] as? String,
                      let referer = args["referer"] as? String else {
                    result(nil)
                    return
                }
                self?.openVideoWithReferer(url: url, referer: referer)
                result(nil)
            case "isPictureInPictureSupported":
                result(self?.isPictureInPictureSupported() ?? false)
            case "enterPictureInPictureMode":
                guard let args = call.arguments as? [String: Any],
                      let url = args["url"] as? String else {
                    result(false)
                    return
                }
                let referer = args["referer"] as? String ?? ""
                let position = args["position"] as? Int ?? 0
                let playing = args["playing"] as? Bool ?? true
                let entered = self?.enterPictureInPictureMode(
                    url: url,
                    referer: referer,
                    positionMilliseconds: position,
                    playing: playing
                ) ?? false
                result(entered)
            case "updatePictureInPictureActions":
                // Android-only for now. Keep no-op on iOS for compatibility.
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let storageChannel = FlutterMethodChannel(
            name: "com.predidit.kazumi/storage",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        storageChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "getAvailableStorage" {
                do {
                    let attrs = try FileManager.default.attributesOfFileSystem(
                        forPath: NSHomeDirectory()
                    )
                    if let freeSize = attrs[.systemFreeSize] as? Int64 {
                        result(freeSize)
                    } else {
                        result(-1)
                    }
                } catch {
                    result(-1)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // TODO: ADD VLC SUPPORT
    // VLC can be downloaded from iOS App Store, but don't know how to build selectable app lists, while checking if it is installled.
    // VLC supports more video formats than AVPlayer but does not support referer while AVPlayer does
    private func openVideoWithReferer(url: String, referer: String) {
        guard let videoUrl = URL(string: url) else { return }

        let headers: [String: String] = [
            "Referer": referer,
        ]
        let asset = AVURLAsset(url: videoUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.videoGravity = AVLayerVideoGravity.resizeAspect
        playerViewController.allowsPictureInPicturePlayback = true
        if #available(iOS 14.2, *) {
            playerViewController.canStartPictureInPictureAutomaticallyFromInline = true
        }

        // Use UIScene API instead of deprecated keyWindow
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        rootViewController.present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }

//        guard let appURL = URL(string: "vlc-x-callback://x-callback-url/stream?url=" + url) else {
//            return
//        }
//        if UIApplication.shared.canOpenURL(appURL) && referer.isEmpty {
//            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
//        }
    }

    private func isPictureInPictureSupported() -> Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    private func enterPictureInPictureMode(
        url: String,
        referer: String,
        positionMilliseconds: Int,
        playing: Bool
    ) -> Bool {
        if !isPictureInPictureSupported() {
            return false
        }
        guard let videoURL = URL(string: url) else {
            return false
        }

        cleanupPictureInPictureResources()

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: []
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("AppDelegate: failed to configure AVAudioSession for PIP: \(error)")
        }

        let options: [String: Any]
        if referer.isEmpty {
            options = [:]
        } else {
            options = ["AVURLAssetHTTPHeaderFieldsKey": ["Referer": referer]]
        }
        let asset = AVURLAsset(url: videoURL, options: options.isEmpty ? nil : options)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        if positionMilliseconds > 0 {
            let time = CMTime(value: CMTimeValue(positionMilliseconds), timescale: 1000)
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if playing {
            player.play()
        }

        guard let host = resolveRootViewController()?.view else {
            return false
        }
        let hostView = UIView(frame: CGRect(x: -2, y: -2, width: 1, height: 1))
        hostView.isUserInteractionEnabled = false
        hostView.clipsToBounds = true
        hostView.backgroundColor = .clear
        host.addSubview(hostView)

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = hostView.bounds
        playerLayer.videoGravity = .resizeAspect
        hostView.layer.addSublayer(playerLayer)

        guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else {
            player.pause()
            playerLayer.removeFromSuperlayer()
            hostView.removeFromSuperview()
            return false
        }
        controller.delegate = self
        if #available(iOS 14.2, *) {
            controller.canStartPictureInPictureAutomaticallyFromInline = true
        }

        pipPlayer = player
        pipPlayerLayer = playerLayer
        pipController = controller
        pipHostView = hostView

        controller.startPictureInPicture()
        return true
    }

    private func resolveRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }
        return windowScene.windows.first?.rootViewController
    }

    private func notifyFlutterPIPStopped() {
        let seconds = pipPlayer?.currentTime().seconds ?? 0
        let position = (seconds.isFinite && seconds > 0) ? Int(seconds * 1000) : 0
        let playing = pipPlayer?.timeControlStatus == .playing
        intentChannel?.invokeMethod("onIosPipStopped", arguments: [
            "position": position,
            "playing": playing
        ])
    }

    private func cleanupPictureInPictureResources() {
        pipController?.delegate = nil
        pipController = nil
        pipPlayer?.pause()
        pipPlayer = nil
        pipPlayerLayer?.removeFromSuperlayer()
        pipPlayerLayer = nil
        pipHostView?.removeFromSuperview()
        pipHostView = nil
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        notifyFlutterPIPStopped()
        cleanupPictureInPictureResources()
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        NSLog("AppDelegate: failed to start PIP: \(error)")
        cleanupPictureInPictureResources()
    }
}
