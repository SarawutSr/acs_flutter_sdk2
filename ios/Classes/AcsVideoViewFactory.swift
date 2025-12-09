import Flutter
import UIKit

class AcsVideoViewFactory: NSObject, FlutterPlatformViewFactory {
    private let viewManager: VideoViewManager

    init(viewManager: VideoViewManager) {
        self.viewManager = viewManager
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let params = args as? [String: Any]
        let key = params?["viewKey"] as? String ?? ""
        let view: UIView
        switch key {
        case "localVideoView":
            view = viewManager.localContainer
        case "remoteVideoView":
            view = viewManager.remoteContainer
        default:
            view = UIView(frame: frame)
            view.backgroundColor = .black
        }
        return AcsPlatformView(view: view)
    }
}

private class AcsPlatformView: NSObject, FlutterPlatformView {
    private let embeddedView: UIView

    init(view: UIView) {
        embeddedView = view
        super.init()
    }

    func view() -> UIView {
        embeddedView
    }

    func dispose() {}
}
