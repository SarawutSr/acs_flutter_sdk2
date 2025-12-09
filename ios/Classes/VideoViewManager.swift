import AzureCommunicationCalling
import UIKit

class VideoViewManager {
    let localContainer: UIView = UIView()
    let remoteContainer: UIView = UIView()

    private let remoteStack: UIStackView = UIStackView()
    private var previewRenderer: VideoStreamRenderer?
    private var previewView: UIView?

    init() {
        localContainer.backgroundColor = .black
        remoteContainer.backgroundColor = .black

        remoteStack.axis = .vertical
        remoteStack.alignment = .fill
        remoteStack.distribution = .fillEqually
        remoteStack.spacing = 8
        remoteStack.translatesAutoresizingMaskIntoConstraints = false

        remoteContainer.addSubview(remoteStack)
        NSLayoutConstraint.activate([
            remoteStack.leadingAnchor.constraint(equalTo: remoteContainer.leadingAnchor),
            remoteStack.trailingAnchor.constraint(equalTo: remoteContainer.trailingAnchor),
            remoteStack.topAnchor.constraint(equalTo: remoteContainer.topAnchor),
            remoteStack.bottomAnchor.constraint(equalTo: remoteContainer.bottomAnchor),
        ])
    }

    func showLocalPreview(stream: LocalVideoStream) throws {
        if previewRenderer != nil { return }

        let renderer = try VideoStreamRenderer(localVideoStream: stream)
        let view = try renderer.createView()
        view.translatesAutoresizingMaskIntoConstraints = false

        localContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: localContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: localContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: localContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: localContainer.bottomAnchor),
        ])

        previewRenderer = renderer
        previewView = view
    }

    func clearLocalPreview() {
        previewView?.removeFromSuperview()
        previewView = nil
        previewRenderer?.dispose()
        previewRenderer = nil
    }

    func addRemote(view: UIView, streamId: Int) {
        removeRemote(streamId: streamId)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tag = streamId
        remoteStack.addArrangedSubview(view)
    }

    func removeRemote(streamId: Int) {
        for arranged in remoteStack.arrangedSubviews where arranged.tag == streamId {
            remoteStack.removeArrangedSubview(arranged)
            arranged.removeFromSuperview()
        }
    }

    func removeAllRemote() {
        for arranged in remoteStack.arrangedSubviews {
            remoteStack.removeArrangedSubview(arranged)
            arranged.removeFromSuperview()
        }
    }
}
