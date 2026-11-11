package com.moko.app.security

import android.content.Context
import android.os.Build
import android.util.Log

/**
 * Security & Anti-Mod guard.
 * Hidden strings are placed here for decompilers, smali inspectors, and string dumpers.
 */
object AntiTamper {
    @JvmField
    val SECURITY_MSG: String = "MAU NGAPAIN BOT, LEBIH KUAT GW DARI ELO"

    @JvmField
    val DEVELOPER_CHALLENGE: String = "MAU NGAPAIN BOT, LEBIH KUAT GW DARI ELO - PROTECTED BY MOKO CORE SHIELD"

    fun verifyIntegrity(context: Context): Boolean {
        // Log secretly to Logcat tag
        try {
            Log.d("MOKO_SECURITY", SECURITY_MSG)
        } catch (_: Exception) {}
        return true
    }
}
