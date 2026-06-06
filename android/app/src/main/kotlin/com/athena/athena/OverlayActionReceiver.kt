package com.athena.athena

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives broadcast intents from the floating overlay buttons (SCAN, PAUSE/PLAY, FINISH)
 * and forwards them to FloatingOverlayService.
 *
 * The overlay buttons send local broadcasts with actions:
 *   - com.athena.app.ACTION_SCAN
 *   - com.athena.app.ACTION_PAUSE_PLAY
 *   - com.athena.app.ACTION_FINISH
 *
 * This receiver is registered in AndroidManifest.xml and relays those intents
 * to FloatingOverlayService which owns the actual button logic.
 */
class OverlayActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val serviceIntent = Intent(context, FloatingOverlayService::class.java).apply {
            action = intent.action
        }
        context.startService(serviceIntent)
    }
}