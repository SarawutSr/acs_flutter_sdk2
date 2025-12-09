import AzureCommunicationCalling
import UIKit

class RemoteVideoRegistry {
    private struct StreamHolder {
        let renderer: VideoStreamRenderer
        let view: UIView
    }

    private var holders: [Int: StreamHolder] = [:]

    func start(stream: RemoteVideoStream) throws -> UIView {
        let streamId = Int(stream.id)
        if let existing = holders[streamId] {
            return existing.view
        }

        let renderer = try VideoStreamRenderer(remoteVideoStream: stream)
        let view = try renderer.createView()
        view.translatesAutoresizingMaskIntoConstraints = false

        holders[streamId] = StreamHolder(renderer: renderer, view: view)
        return view
    }

    func stop(streamId: Int) {
        guard let holder = holders.removeValue(forKey: streamId) else { return }
        holder.view.removeFromSuperview()
        holder.renderer.dispose()
    }

    func clear() {
        holders.values.forEach { holder in
            holder.view.removeFromSuperview()
            holder.renderer.dispose()
        }
        holders.removeAll()
    }
}
