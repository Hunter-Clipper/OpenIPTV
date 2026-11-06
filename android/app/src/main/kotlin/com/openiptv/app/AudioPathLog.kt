package com.openiptv.app

import android.util.Log
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.audio.AudioSink

/** Logs how audio is leaving the device, for tunneling / passthrough tests (#159). */
class AudioPathLog(
    private val label: String,
    private val built: OutputModes.Output,
) : AnalyticsListener {
    override fun onAudioTrackInitialized(
        eventTime: AnalyticsListener.EventTime,
        audioTrackConfig: AudioSink.AudioTrackConfig,
    ) {
        Log.i("OTV-audio", "[$label] encoding=${audioTrackConfig.encoding} " +
            "channelConfig=${audioTrackConfig.channelConfig} rate=${audioTrackConfig.sampleRate} " +
            "tunneling=${audioTrackConfig.tunneling} offload=${audioTrackConfig.offload} " +
            "built=$built")
    }
}
