package com.burhanrabbani.acs_flutter_sdk

import android.content.Context
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class VideoPlatformViewFactory(
    private val viewManager: VideoViewManager
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any?>()
        val viewType = params["viewKey"] as? String ?: ""
        val view: View? = when (viewType) {
            "localVideoView" -> viewManager.localContainer
            "remoteVideoView" -> viewManager.remoteContainer
            else -> null
        }
        return object : PlatformView {
            override fun getView(): View? = view
            override fun dispose() = Unit
        }
    }
}
