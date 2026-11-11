package com.openiptv.app

import androidx.media3.common.Format
import androidx.media3.exoplayer.video.VideoFrameMetadataListener

/**
 * Works out a stream's frame rate from the gaps between decoded frames, for
 * the stream-details badge: many live streams don't announce one.
 */
class FrameRateProbe(private val next: VideoFrameMetadataListener? = null) : VideoFrameMetadataListener {
    private val gaps = LongArray(SAMPLES)
    private var count = 0
    private var last = Long.MIN_VALUE

    @Volatile var fps = 0f
        private set

    override fun onVideoFrameAboutToBeRendered(
        presentationTimeUs: Long,
        releaseTimeNs: Long,
        format: Format,
        mediaFormat: android.media.MediaFormat?,
    ) {
        next?.onVideoFrameAboutToBeRendered(presentationTimeUs, releaseTimeNs, format, mediaFormat)
        onPresentationTime(presentationTimeUs)
    }

    /** One frame's timestamp; also fed by the tunneled renderer, which has no frame callback. */
    fun onPresentationTime(presentationTimeUs: Long) {
        if (fps > 0f) return // settled for this stream
        val gap = presentationTimeUs - last
        last = presentationTimeUs
        if (gap <= 0 || gap > 200_000) return // first frame, a seek, or a hiccup
        gaps[count++] = gap
        if (count == SAMPLES) {
            val median = gaps.sortedArray()[SAMPLES / 2]
            fps = 1_000_000f / median
        }
    }

    /** A new stream: measure again. */
    fun reset() {
        count = 0
        last = Long.MIN_VALUE
        fps = 0f
    }

    private companion object { const val SAMPLES = 20 }
}
