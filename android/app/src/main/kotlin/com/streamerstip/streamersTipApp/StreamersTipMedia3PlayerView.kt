package com.streamerstip.streamersTipApp

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class StreamersTipMedia3PlayerViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<Any, Any>()
        return StreamersTipMedia3PlayerView(context, messenger, viewId, params)
    }
}

class StreamersTipMedia3PlayerView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    params: Map<*, *>,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "streamers_tip/media3_player_$viewId")
    private val root = FrameLayout(context)
    private val playerView = PlayerView(context)
    private val player = ExoPlayer.Builder(context).build()
    private var currentUrl: String? = null
    private var disposed = false

    init {
        playerView.useController = false
        playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
        playerView.player = player
        root.addView(
            playerView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        player.repeatMode = Player.REPEAT_MODE_ONE
        player.volume = if (params["muted"] as? Boolean == false) 1f else 0f
        player.addListener(
            object : Player.Listener {
                override fun onRenderedFirstFrame() {
                    channel.invokeMethod(
                        "event",
                        mapOf(
                            "type" to "firstFrame",
                            "videoId" to (params["videoId"] as? String).orEmpty(),
                        ),
                    )
                }

                override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                    channel.invokeMethod(
                        "event",
                        mapOf(
                            "type" to "error",
                            "message" to (error.message ?: error.errorCodeName),
                        ),
                    )
                }
            },
        )
        channel.setMethodCallHandler(this)

        val url = params["url"] as? String
        if (!url.isNullOrBlank()) {
            setSource(url, params["autoplay"] as? Boolean == true)
        }
    }

    override fun getView(): View = root

    override fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        playerView.player = null
        player.release()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.success(null)
            return
        }
        when (call.method) {
            "setSource" -> {
                val url = call.argument<String>("url").orEmpty()
                val autoplay = call.argument<Boolean>("autoplay") == true
                if (url.isNotBlank()) {
                    setSource(url, autoplay)
                }
                result.success(null)
            }

            "play" -> {
                player.playWhenReady = true
                player.play()
                result.success(null)
            }

            "pause" -> {
                player.pause()
                result.success(null)
            }

            "setMuted" -> {
                player.volume = if (call.argument<Boolean>("muted") == true) 0f else 1f
                result.success(null)
            }

            "setLooping" -> {
                player.repeatMode =
                    if (call.argument<Boolean>("looping") == false) Player.REPEAT_MODE_OFF
                    else Player.REPEAT_MODE_ONE
                result.success(null)
            }

            "seekTo" -> {
                player.seekTo(call.argument<Number>("positionMs")?.toLong() ?: 0L)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun setSource(url: String, autoplay: Boolean) {
        if (currentUrl == url) {
            if (autoplay) {
                player.playWhenReady = true
                player.play()
            }
            return
        }
        currentUrl = url
        player.setMediaItem(MediaItem.fromUri(url))
        player.prepare()
        player.playWhenReady = autoplay
        if (autoplay) {
            player.play()
        }
    }
}
