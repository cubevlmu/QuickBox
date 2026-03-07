package me.cubevlmu.qbox

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "quick_box/launcher"
    private val iconSizePx = 56

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLaunchableApps" -> result.success(getLaunchableApps())
                    "getIconCacheDir" -> result.success(getIconCacheDir())
                    "getAppIconsBatch" -> {
                        val packageNames = call.argument<List<String>>("packageNames")
                        if (packageNames.isNullOrEmpty()) {
                            result.success(emptyMap<String, ByteArray>())
                        } else {
                            result.success(getAppIconsBatch(packageNames))
                        }
                    }
                    "getAppIcon" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            result.success(getAppIcon(packageName))
                        }
                    }

                    "launchApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            result.success(launchApp(packageName))
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun getLaunchableApps(): List<Map<String, String>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val matches = packageManager.queryIntentActivities(
            launcherIntent,
            PackageManager.MATCH_ALL
        )

        return matches
            .mapNotNull { info ->
                val packageName = info.activityInfo?.packageName ?: return@mapNotNull null
                val label = info.loadLabel(packageManager)?.toString() ?: packageName
                mapOf("packageName" to packageName, "label" to label)
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["label"]?.lowercase() }
    }

    private fun getAppIcon(packageName: String): ByteArray? {
        return try {
            val icon = packageManager.getApplicationIcon(packageName)
            drawableToPngBytes(icon)
        } catch (_: Exception) {
            null
        }
    }

    private fun getAppIconsBatch(packageNames: List<String>): Map<String, ByteArray> {
        val result = mutableMapOf<String, ByteArray>()
        for (packageName in packageNames) {
            if (packageName.isBlank()) continue
            val bytes = getAppIcon(packageName) ?: continue
            result[packageName] = bytes
        }
        return result
    }

    private fun getIconCacheDir(): String {
        val dir = java.io.File(cacheDir, "app_icon_cache")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir.absolutePath
    }

    private fun drawableToPngBytes(drawable: Drawable): ByteArray? {
        val bitmap = Bitmap.createBitmap(iconSizePx, iconSizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)

        val output = ByteArrayOutputStream()
        return try {
            bitmap.compress(Bitmap.CompressFormat.PNG, 92, output)
            output.toByteArray()
        } finally {
            output.close()
            bitmap.recycle()
        }
    }

    private fun launchApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
