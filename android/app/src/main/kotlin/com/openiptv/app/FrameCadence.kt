package com.openiptv.app

import android.media.MediaFormat
import android.util.Log
import androidx.media3.common.Format
import androidx.media3.exoplayer.video.VideoFrameMetadataListener

/**
 * Measures how evenly frames reach the screen (`[OTV-cadence]`, #157), so
 * "jittery" becomes numbers. Every 5 s it logs, from the frames shown in
 * that window:
 *  - the source's own frame rate and how irregular its timestamps are
 *    (`src`: if this is uneven, the stream itself is jittery);
 *  - the interval between frame releases (`rel`): ExoPlayer snaps releases
 *    to the display's vsync, so intervals should be 1 or 2 refresh periods;
 *    `late` counts intervals more than 1.5x the median.
 * Cheap enough to leave on: a few additions per frame, one log line per 5 s.
 */
class FrameCadence(private val label: String) : VideoFrameMetadataListener {
    private var lastPresUs = Long.MIN_VALUE
    private var lastRelNs = Long.MIN_VALUE
    private var windowStartMs = 0L
    private val src = LongArray(MAX)
    private val rel = LongArray(MAX)
    private var n = 0

    override fun onVideoFrameAboutToBeRendered(
        presentationTimeUs: Long,
        releaseTimeNs: Long,
        format: Format,
        mediaFormat: MediaFormat?,
    ) {
        val now = android.os.SystemClock.elapsedRealtime()
        if (windowStartMs == 0L) windowStartMs = now
        if (lastPresUs != Long.MIN_VALUE && n < MAX) {
            src[n] = presentationTimeUs - lastPresUs
            rel[n] = releaseTimeNs - lastRelNs
            n++
        }
        lastPresUs = presentationTimeUs
        lastRelNs = releaseTimeNs
        if (now - windowStartMs >= 5_000) {
            report(now - windowStartMs)
            n = 0
            windowStartMs = now
        }
    }

    /** Forget the previous frame (stream changed, seek) so one gap isn't counted. */
    fun reset() {
        lastPresUs = Long.MIN_VALUE
        lastRelNs = Long.MIN_VALUE
        n = 0
        windowStartMs = 0L
    }

    private fun report(windowMs: Long) {
        if (n < 10) return
        val s = src.copyOf(n).also { it.sort() }
        val r = rel.copyOf(n).also { it.sort() }
        val srcMed = s[n / 2] / 1000.0
        val relMed = r[n / 2] / 1e6
        // Intervals that break the pattern: 1.5x the median, either way.
        val srcOdd = s.count { it / 1000.0 > srcMed * 1.5 || it / 1000.0 < srcMed * 0.5 }
        val relLate = r.count { it / 1e6 > relMed * 1.5 }
        val relShort = r.count { it / 1e6 < relMed * 0.5 }
        Log.i(
            "OTV-cadence",
            "[$label] ${"%.1f".format(n * 1000.0 / windowMs)} frames/s | " +
                "src med=${"%.2f".format(srcMed)}ms min=${"%.2f".format(s[0] / 1000.0)} " +
                "max=${"%.2f".format(s[n - 1] / 1000.0)} odd=$srcOdd | " +
                "rel med=${"%.2f".format(relMed)}ms min=${"%.2f".format(r[0] / 1e6)} " +
                "max=${"%.2f".format(r[n - 1] / 1e6)} late=$relLate short=$relShort",
        )
    }

    private companion object {
        const val MAX = 800 // 5 s at up to 160 fps
    }
}
