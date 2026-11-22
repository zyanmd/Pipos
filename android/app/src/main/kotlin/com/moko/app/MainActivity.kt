package com.moko.app

import android.content.Context
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
import android.util.Rational
import android.view.OrientationEventListener
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var autoPipEnabled = false
    private var pipChannel: MethodChannel? = null
    private var deepLinkChannel: MethodChannel? = null
    private var initialDeepLink: String? = null
    private var fullscreenOrientationListener: OrientationEventListener? = null
    private var isFullscreenLandscape = false

    private fun startFullscreenOrientationListener() {
        isFullscreenLandscape = true
        if (fullscreenOrientationListener == null) {
            fullscreenOrientationListener = object : OrientationEventListener(this, SensorManager.SENSOR_DELAY_NORMAL) {
                override fun onOrientationChanged(orientation: Int) {
                    if (orientation == ORIENTATION_UNKNOWN || !isFullscreenLandscape) return
                    // 230..310 degrees -> Landscape normal (90 deg counter-clockwise)
                    if (orientation in 230..310) {
                        if (requestedOrientation != ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE) {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                        }
                    }
                    // 50..130 degrees -> Reverse Landscape (270 deg counter-clockwise)
                    else if (orientation in 50..130) {
                        if (requestedOrientation != ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE) {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                        }
                    }
                }
            }
        }
        if (fullscreenOrientationListener?.canDetectOrientation() == true) {
            fullscreenOrientationListener?.enable()
        }
    }

    private fun stopFullscreenOrientationListener() {
        isFullscreenLandscape = false
        try {
            fullscreenOrientationListener?.disable()
        } catch (_: Exception) {}
    }

    override fun onPause() {
        super.onPause()
        stopFullscreenOrientationListener()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        } catch (_: Exception) {}
        com.moko.app.security.AntiTamper.verifyIntegrity(this)
        enableHighRefreshRate()
        initialDeepLink = extractDeepLinkUri(intent)
        // Ensure Auto-PiP is strictly disabled by default
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val builder = PictureInPictureParams.Builder()
            builder.setAutoEnterEnabled(false)
            setPictureInPictureParams(builder.build())
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uriString = extractDeepLinkUri(intent)
        if (!uriString.isNullOrEmpty()) {
            deepLinkChannel?.invokeMethod("onDeepLink", uriString)
        }
    }

    private fun extractDeepLinkUri(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return null
        // Ignore home_widget clicks so HomeWidgetService handles them without duplication
        if (intent.hasExtra("homeWidget")) return null
        val data = intent.data ?: return null
        val scheme = data.scheme?.lowercase() ?: return null
        if (scheme == "moko") {
            val host = data.host?.lowercase()
            if ((host == "anime" || host == "continue") && data.getQueryParameter("url") != null) {
                return null
            }
            return data.toString()
        }
        return null
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
                    val isPortrait = call.argument<Boolean>("isPortrait") ?: false
                    try {
                        if (isPortrait) {
                            stopFullscreenOrientationListener()
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                        } else {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                            startFullscreenOrientationListener()
                        }
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "exitFullscreen" -> {
                    try {
                        stopFullscreenOrientationListener()
                        // Restore brightness override
                        val lp = window.attributes
                        lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        window.attributes = lp

                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            try {
                                if (requestedOrientation == ActivityInfo.SCREEN_ORIENTATION_PORTRAIT) {
                                    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                                }
                            } catch (_: Exception) {}
                        }, 1000)
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "setBrightness" -> {
                    val b = call.argument<Double>("brightness")?.toFloat() ?: -1.0f
                    try {
                        runOnUiThread {
                            val lp = window.attributes
                            lp.screenBrightness = if (b < 0f) WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE else b.coerceIn(0.01f, 1.0f)
                            window.attributes = lp
                        }
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                    } catch (_: Exception) {}
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        pipChannel?.setMethodCallHandler(handler)

        // Setup DeepLink Channel
        deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moko.app/deeplink")
        deepLinkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(initialDeepLink)
                    initialDeepLink = null
                }
                else -> result.notImplemented()
            }
        }

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

        // Setup Auto-Rotate Channel
        val autoRotateChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moko.app/auto_rotate")
        autoRotateChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canModifySystemSettings" -> {
                    result.success(canModifySystemSettings())
                }
                "openWriteSettings" -> {
                    openWriteSettingsPermission()
                    result.success(true)
                }
                "setSystemAutoRotate" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(setSystemAutoRotate(enabled))
                }
                "isSystemAutoRotateEnabled" -> {
                    result.success(isSystemAutoRotateEnabled())
                }
                "setAutoDisableOnExit" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    try {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().putBoolean("flutter.auto_disable_rotate_on_exit", enabled).apply()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canModifySystemSettings(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.System.canWrite(this)
        } else {
            true
        }
    }

    private fun openWriteSettingsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (_: Exception) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                } catch (_: Exception) {}
            }
        }
    }

    private fun setSystemAutoRotate(enabled: Boolean): Boolean {
        if (!canModifySystemSettings()) return false
        return try {
            Settings.System.putInt(
                contentResolver,
                Settings.System.ACCELEROMETER_ROTATION,
                if (enabled) 1 else 0
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun isSystemAutoRotateEnabled(): Boolean {
        return try {
            Settings.System.getInt(contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0) == 1
        } catch (_: Exception) {
            false
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
        if (!isInPictureInPictureMode) {
            // If exiting PiP mode, immediately disallow auto-enter until video re-enables it
            autoPipEnabled = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val builder = PictureInPictureParams.Builder()
                builder.setAutoEnterEnabled(false)
                setPictureInPictureParams(builder.build())
            }
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val shouldDisable = prefs.getBoolean("flutter.auto_disable_rotate_on_exit", true)
                if (shouldDisable) {
                    setSystemAutoRotate(false)
                }
            } catch (_: Exception) {}
            try {
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            } catch (_: Exception) {}
        }
    }

    override fun onStop() {
        super.onStop()
        val isInPip = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) isInPictureInPictureMode else false
        if (!isInPip) {
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val shouldDisable = prefs.getBoolean("flutter.auto_disable_rotate_on_exit", true)
                if (shouldDisable) {
                    setSystemAutoRotate(false)
                }
            } catch (_: Exception) {}
            try {
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            } catch (_: Exception) {}
        }
    }

    override fun onDestroy() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val shouldDisable = prefs.getBoolean("flutter.auto_disable_rotate_on_exit", true)
            if (shouldDisable) {
                setSystemAutoRotate(false)
            }
        } catch (_: Exception) {}
        try {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onStart() {
        super.onStart()
        enableHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRate()
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
