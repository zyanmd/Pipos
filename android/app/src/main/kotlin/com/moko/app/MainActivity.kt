package com.moko.app

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import android.os.Build
import android.os.Bundle
import android.content.res.Configuration
import android.app.PictureInPictureParams
import android.content.pm.ActivityInfo
import android.hardware.SensorManager
import android.view.OrientationEventListener
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var autoPipEnabled = false
    private var pipChannel: MethodChannel? = null
    private var isFullscreenMode = false
    private var orientationEventListener: OrientationEventListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
        // Ensure Auto-PiP is strictly disabled by default
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val builder = PictureInPictureParams.Builder()
            builder.setAutoEnterEnabled(false)
            setPictureInPictureParams(builder.build())
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moko.app/pip")
        val handler = MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        pipChannel?.invokeMethod("onPipChanged", true)
                        val builder = PictureInPictureParams.Builder()
                        val aspectRatio = Rational(16, 9)
                        builder.setAspectRatio(aspectRatio)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            builder.setAutoEnterEnabled(autoPipEnabled)
                        }
                        val success = enterPictureInPictureMode(builder.build())
                        result.success(success)
                    } else {
                        result.success(false)
                    }
                }
                "isPipSupported" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                }
                "setAutoPip" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    autoPipEnabled = enabled
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val builder = PictureInPictureParams.Builder()
                        builder.setAspectRatio(Rational(16, 9))
                        builder.setAutoEnterEnabled(enabled)
                        setPictureInPictureParams(builder.build())
                    }
                    result.success(true)
                }
                "enterFullscreen" -> {
                    startFullscreenOrientationListener()
                    result.success(true)
                }
                "exitFullscreen" -> {
                    stopFullscreenOrientationListener()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        pipChannel?.setMethodCallHandler(handler)

        // Setup In-App Updater Channel
        val updaterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moko.app/updater")
        updaterChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbis" -> {
                    result.success(Build.SUPPORTED_ABIS.toList())
                }
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file
                            )
                        } else {
                            Uri.fromFile(file)
                        }
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(installIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Only enter PiP if video player explicitly enabled autoPip
        if (autoPipEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            pipChannel?.invokeMethod("onPipChanged", true)
            val builder = PictureInPictureParams.Builder()
            val aspectRatio = Rational(16, 9)
            builder.setAspectRatio(aspectRatio)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setAutoEnterEnabled(true)
            }
            enterPictureInPictureMode(builder.build())
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipChanged", isInPictureInPictureMode)
        if (isInPictureInPictureMode) {
            try {
                orientationEventListener?.disable()
            } catch (_: Exception) {}
        } else {
            if (isFullscreenMode && orientationEventListener?.canDetectOrientation() == true) {
                try {
                    orientationEventListener?.enable()
                } catch (_: Exception) {}
            }
            // If exiting PiP mode, immediately disallow auto-enter until video re-enables it
            autoPipEnabled = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val builder = PictureInPictureParams.Builder()
                builder.setAutoEnterEnabled(false)
                setPictureInPictureParams(builder.build())
            }
        }
    }

    private fun startFullscreenOrientationListener() {
        isFullscreenMode = true
        try {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        } catch (_: Exception) {}

        if (orientationEventListener == null) {
            orientationEventListener = object : OrientationEventListener(this, SensorManager.SENSOR_DELAY_NORMAL) {
                override fun onOrientationChanged(orientation: Int) {
                    if (!isFullscreenMode || orientation == ORIENTATION_UNKNOWN) return
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode) return

                    // 200..290: Standard Landscape (clockwise 270°, top of device on left)
                    // 70..160: Reverse Landscape (clockwise 90°, top of device on right)
                    if (orientation in 200..290) {
                        if (requestedOrientation != ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE) {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                        }
                    } else if (orientation in 70..160) {
                        if (requestedOrientation != ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE) {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                        }
                    }
                }
            }
        }

        if (orientationEventListener?.canDetectOrientation() == true) {
            try {
                orientationEventListener?.enable()
            } catch (_: Exception) {}
        }
    }

    private fun stopFullscreenOrientationListener() {
        isFullscreenMode = false
        try {
            orientationEventListener?.disable()
        } catch (_: Exception) {}
        try {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        } catch (_: Exception) {}
    }

    override fun onPause() {
        super.onPause()
        try {
            orientationEventListener?.disable()
        } catch (_: Exception) {}
    }

    override fun onStart() {
        super.onStart()
        enableHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRate()
        if (isFullscreenMode && orientationEventListener?.canDetectOrientation() == true) {
            try {
                orientationEventListener?.enable()
            } catch (_: Exception) {}
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            orientationEventListener?.disable()
            orientationEventListener = null
        } catch (_: Exception) {}
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            enableHighRefreshRate()
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        enableHighRefreshRate()
    }

    private fun enableHighRefreshRate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val currentDisplay = display
                if (currentDisplay != null) {
                    val modes = currentDisplay.supportedModes
                    var maxMode = currentDisplay.mode
                    var maxRate = maxMode.refreshRate
                    for (mode in modes) {
                        if (mode.refreshRate > maxRate) {
                            maxRate = mode.refreshRate
                            maxMode = mode
                        }
                    }
                    val params = window.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    params.preferredRefreshRate = maxRate
                    window.attributes = params
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                @Suppress("DEPRECATION")
                val currentDisplay = windowManager?.defaultDisplay
                if (currentDisplay != null) {
                    @Suppress("DEPRECATION")
                    val modes = currentDisplay.supportedModes
                    @Suppress("DEPRECATION")
                    var maxMode = currentDisplay.mode
                    var maxRate = maxMode.refreshRate
                    for (mode in modes) {
                        if (mode.refreshRate > maxRate) {
                            maxRate = mode.refreshRate
                            maxMode = mode
                        }
                    }
                    val params = window.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        params.preferredRefreshRate = maxRate
                    }
                    window.attributes = params
                }
            }
        } catch (_: Exception) {
            // Graceful fallback if OEM restricts window manager display attributes
        }
    }
}
