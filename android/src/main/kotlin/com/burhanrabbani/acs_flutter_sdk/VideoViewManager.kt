package com.burhanrabbani.acs_flutter_sdk

import android.app.Activity
import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.azure.android.communication.calling.CreateViewOptions
import com.azure.android.communication.calling.LocalVideoStream
import com.azure.android.communication.calling.ScalingMode
import com.azure.android.communication.calling.VideoStreamRenderer

/**
 * Holds local and remote video containers and provides helpers to manage them.
 */
class VideoViewManager(context: Context) {
    val localContainer: FrameLayout = FrameLayout(context)
    val remoteContainer: FrameLayout = FrameLayout(context)
    private var previewRenderer: VideoStreamRenderer? = null

    fun showLocalPreview(context: Context, stream: LocalVideoStream?) {
        if (stream == null) return
        if (previewRenderer != null) return

        previewRenderer = VideoStreamRenderer(stream, context).also { renderer ->
            val previewView = renderer.createView(CreateViewOptions(ScalingMode.FIT))
            previewView.tag = LOCAL_PREVIEW_TAG
            localContainer.addView(previewView)
        }
    }

    fun clearLocalPreview() {
        previewRenderer?.let { renderer ->
            renderer.dispose()
            previewRenderer = null
        }
        localContainer.removeAllViews()
    }

    fun addRemoteView(activity: Activity?, streamId: Int, view: View) {
        activity?.runOnUiThread {
            view.tag = streamId
            remoteContainer.addView(view)
        } ?: run {
            view.tag = streamId
            remoteContainer.addView(view)
        }
    }

    fun removeRemoteView(activity: Activity?, streamId: Int) {
        val removeAction = {
            for (index in 0 until remoteContainer.childCount) {
                val child = remoteContainer.getChildAt(index)
                if (child?.tag == streamId) {
                    remoteContainer.removeViewAt(index)
                    break
                }
            }
        }
        activity?.runOnUiThread { removeAction() } ?: removeAction()
    }

    companion object {
        private const val LOCAL_PREVIEW_TAG = "local_preview"
    }
}
