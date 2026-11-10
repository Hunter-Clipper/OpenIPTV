package com.openiptv.app

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor.AudioFormat
import androidx.media3.common.audio.BaseAudioProcessor
import java.nio.ByteBuffer

/**
 * Lip-sync nudge: moves the sound later (positive) or earlier (negative) than
 * the picture by [delayMs].
 *
 * Later = silence is written ahead of the sound. Earlier = the first part of
 * the sound is skipped. The audio sink's clock counts what this processor
 * outputs, so either way the picture follows the shifted sound clock, which is
 * exactly the offset heard. Only decoded sound goes through it: surround
 * passthrough and tunneled playback skip audio processors altogether.
 */
class AudioDelayProcessor : BaseAudioProcessor() {
    @Volatile private var targetMs = 0
    private var appliedMs = 0
    private var silenceBytes = 0
    private var dropBytes = 0
    private var bytesPerMs = 0.0
    private var frameSize = 0

    /** Changes the shift while playing; the difference is applied at once. */
    fun setDelayMs(ms: Int) {
        val delta = ms - targetMs
        targetMs = ms
        // Anything not written yet stays pending: only the change is added.
        if (bytesPerMs > 0) addBytes(delta)
        appliedMs = ms
    }

    private fun addBytes(deltaMs: Int) {
        val bytes = alignToFrame((kotlin.math.abs(deltaMs) * bytesPerMs).toInt())
        if (deltaMs > 0) {
            val cancel = minOf(dropBytes, bytes)
            dropBytes -= cancel
            silenceBytes += bytes - cancel
        } else if (deltaMs < 0) {
            val cancel = minOf(silenceBytes, bytes)
            silenceBytes -= cancel
            dropBytes += bytes - cancel
        }
    }

    private fun alignToFrame(bytes: Int) =
        if (frameSize > 0) bytes - bytes % frameSize else bytes

    override fun onConfigure(inputAudioFormat: AudioFormat): AudioFormat {
        val ok = inputAudioFormat.encoding == C.ENCODING_PCM_16BIT ||
            inputAudioFormat.encoding == C.ENCODING_PCM_FLOAT
        if (!ok) return AudioFormat.NOT_SET // not PCM: pass through untouched
        frameSize = inputAudioFormat.bytesPerFrame
        bytesPerMs = inputAudioFormat.sampleRate * frameSize / 1000.0
        return inputAudioFormat
    }

    override fun onFlush() {
        // New stream or a seek: the sink starts its clock again, so the whole
        // shift has to be re-created from the start.
        silenceBytes = 0
        dropBytes = 0
        if (bytesPerMs > 0) addBytes(targetMs)
        appliedMs = targetMs
    }

    override fun onReset() {
        silenceBytes = 0
        dropBytes = 0
        bytesPerMs = 0.0
        frameSize = 0
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        var remaining = inputBuffer.remaining()
        val drop = minOf(dropBytes, remaining)
        if (drop > 0) {
            inputBuffer.position(inputBuffer.position() + drop)
            dropBytes -= drop
            remaining -= drop
        }
        val silence = silenceBytes
        silenceBytes = 0
        if (remaining == 0 && silence == 0) return
        val out = replaceOutputBuffer(silence + remaining)
        if (silence > 0) out.put(ByteArray(silence))
        out.put(inputBuffer)
        out.flip()
    }
}
