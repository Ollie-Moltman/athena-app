package com.athena.athena

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjection

/**
 * Singleton to hold the active MediaProjection result.
 * Avoids passing Intent via Intent extras (which is fragile for nested Intents
 * like the MediaProjection result data). Both MainActivity and FloatingOverlayService
 * run in the same process, so this shared singleton is safe.
 */
object ProjectionHolder {
    var resultCode: Int = Activity.RESULT_CANCELED
    var resultData: Intent? = null
    var maxDurationMs: Int = 30000
    var isReady: Boolean = false

    fun set(code: Int, data: Intent, maxDuration: Int) {
        resultCode = code
        resultData = data
        maxDurationMs = maxDuration
        isReady = true
    }

    fun consume(): Pair<Int, Intent>? {
        if (!isReady || resultData == null) return null
        val code = resultCode
        val data = resultData!!
        // Clear immediately so a stale service restart doesn't reuse old data
        isReady = false
        resultData = null
        return code to data
    }

    fun clear() {
        isReady = false
        resultData = null
    }
}
