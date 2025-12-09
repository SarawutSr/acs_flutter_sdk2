package com.burhanrabbani.acs_flutter_sdk

import android.content.Context
import com.azure.android.communication.calling.CreateViewOptions
import com.azure.android.communication.calling.RemoteVideoStream
import com.azure.android.communication.calling.ScalingMode
import com.azure.android.communication.calling.VideoStreamRenderer
import com.azure.android.communication.calling.VideoStreamRendererView

/**
 * Tracks active remote video renderers so they can be disposed safely.
 */
class VideoStreamRegistry(private val context: Context) {

    private val streams = mutableMapOf<Int, StreamHolder>()

    fun start(stream: RemoteVideoStream): VideoStreamRendererView? {
        val existing = streams[stream.id]
        if (existing != null) {
            return existing.rendererView
        }

        val renderer = VideoStreamRenderer(stream, context)
        val rendererView = renderer.createView(CreateViewOptions(ScalingMode.FIT))
        streams[stream.id] = StreamHolder(renderer, rendererView)
        return rendererView
    }

    fun stop(streamId: Int) {
        streams.remove(streamId)?.let { holder ->
            holder.rendererView = null
            holder.renderer.dispose()
        }
    }

    fun clear() {
        streams.values.forEach { holder ->
            holder.renderer.dispose()
        }
        streams.clear()
    }

    private data class StreamHolder(
        val renderer: VideoStreamRenderer,
        var rendererView: VideoStreamRendererView?
    )
}
