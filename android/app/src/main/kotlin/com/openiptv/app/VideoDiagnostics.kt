package com.openiptv.app

import android.util.Log
import androidx.media3.common.Format
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.DecoderReuseEvaluation
import androidx.media3.exoplayer.analytics.AnalyticsListener

/**
 * Logs which video decoder a stream got and how it behaves (`[OTV-video]`),
 * so decoder problems on particular chips (#157) are measured, not guessed:
 * `adb logcat | grep OTV-video`. Costs nothing while playing — it only
 * logs when the decoder, the picture size or the dropped-frame count changes.
 */
class VideoDiagnostics(private val label: String) : AnalyticsListener {
    /** The hardware/software decoder ExoPlayer picked for the current stream. */
    @Volatile var decoderName: String? = null
        private set

    override fun onVideoDecoderInitialized(
        eventTime: AnalyticsListener.EventTime,
        decoderName: String,
        initializedTimestampMs: Long,
        initializationDurationMs: Long,
    ) {
        this.decoderName = decoderName
        Log.i("OTV-video", "[$label] decoder=$decoderName init=${initializationDurationMs}ms")
    }

    override fun onVideoDecoderReleased(
        eventTime: AnalyticsListener.EventTime,
        decoderName: String,
    ) {
        Log.i("OTV-video", "[$label] decoder released: $decoderName")
    }

    override fun onVideoInputFormatChanged(
        eventTime: AnalyticsListener.EventTime,
        format: Format,
        decoderReuseEvaluation: DecoderReuseEvaluation?,
    ) {
        Log.i(
            "OTV-video",
            "[$label] input ${format.sampleMimeType} ${format.width}x${format.height} " +
                "fps=${format.frameRate} codecs=${format.codecs} " +
                "par=${format.pixelWidthHeightRatio} profile/level in codecs",
        )
    }

    override fun onVideoSizeChanged(eventTime: AnalyticsListener.EventTime, videoSize: VideoSize) {
        Log.i("OTV-video", "[$label] output ${videoSize.width}x${videoSize.height}")
    }

    override fun onDroppedVideoFrames(
        eventTime: AnalyticsListener.EventTime,
        droppedFrames: Int,
        elapsedMs: Long,
    ) {
        Log.w("OTV-video", "[$label] dropped $droppedFrames frames in ${elapsedMs}ms")
    }

    override fun onVideoCodecError(
        eventTime: AnalyticsListener.EventTime,
        videoCodecError: Exception,
    ) {
        Log.e("OTV-video", "[$label] codec error", videoCodecError)
    }
}
