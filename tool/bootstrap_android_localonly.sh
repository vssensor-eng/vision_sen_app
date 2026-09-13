#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/bootstrap_android.sh"

MANIFEST="android/app/src/main/AndroidManifest.xml"
python3 - "$MANIFEST" <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
for permission in [
    'android.permission.INTERNET',
    'android.permission.ACCESS_WIFI_STATE',
    'android.permission.CHANGE_WIFI_STATE',
    'android.permission.NEARBY_WIFI_DEVICES',
    'android.permission.ACCESS_FINE_LOCATION',
]:
    text = re.sub(
        r'\s*<uses-permission[^>]+android:name="' + re.escape(permission) + r'"[^>]*/>\s*',
        '\n',
        text,
    )
perms = '''    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
    <uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="32" />
'''
text = re.sub(r'(<manifest[^>]*>)', r'\1\n' + perms, text, count=1)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

MAIN_ACTIVITY="android/app/src/main/kotlin/com/visionsen/visionsen_setup/MainActivity.kt"
cat > "$MAIN_ACTIVITY" <<'KOTLIN'
package com.visionsen.visionsen_setup

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.PatternMatcher
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val channelName = "com.visionsen/setup"
    private val permissionRequestCode = 4173
    private val ioExecutor = Executors.newSingleThreadExecutor()

    private lateinit var connectivityManager: ConnectivityManager
    private var methodChannel: MethodChannel? = null
    private var provisioningNetwork: Network? = null
    private var activeCallback: ConnectivityManager.NetworkCallback? = null
    private var pendingConnect: PendingConnect? = null

    private data class PendingConnect(
        val ssidPrefix: String,
        val password: String,
        val timeoutMs: Int,
        val result: MethodChannel.Result,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "connectProvisioningWifi" -> connectProvisioningWifi(call, result)
                    "disconnectProvisioningWifi" -> {
                        disconnectProvisioningInternal(notifyFlutter = false)
                        result.success(null)
                    }
                    "localHttpRequest" -> localHttpRequest(call, result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun connectProvisioningWifi(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(
                "ANDROID_VERSION",
                "Uygulama içi Wi-Fi provisioning Android 10+ gerektirir.",
                null,
            )
            return
        }

        provisioningNetwork?.let { network ->
            result.success(mapOf("connected" to true, "ssid" to selectedSsid(network)))
            return
        }

        if (pendingConnect != null || activeCallback != null) {
            result.error("WIFI_BUSY", "Wi-Fi bağlantı isteği devam ediyor.", null)
            return
        }

        val prefix = call.argument<String>("ssidPrefix")?.trim().orEmpty()
        val password = call.argument<String>("password").orEmpty()
        val timeoutMs = (call.argument<Number>("timeoutMs")?.toInt() ?: 30000)
            .coerceIn(10000, 60000)
        if (prefix.isEmpty() || password.length < 8) {
            result.error("WIFI_ARGUMENT", "Kurulum Wi-Fi bilgileri geçersiz.", null)
            return
        }

        val permission = requiredWifiPermission()
        if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            pendingConnect = PendingConnect(prefix, password, timeoutMs, result)
            requestPermissions(arrayOf(permission), permissionRequestCode)
            return
        }

        startProvisioningRequest(prefix, password, timeoutMs, result)
    }

    private fun requiredWifiPermission(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.NEARBY_WIFI_DEVICES
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return

        val pending = pendingConnect ?: return
        pendingConnect = null
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        if (!granted) {
            pending.result.error(
                "PERMISSION_DENIED",
                "Yakındaki Wi-Fi cihazlarına erişim izni verilmedi.",
                null,
            )
            return
        }
        startProvisioningRequest(
            pending.ssidPrefix,
            pending.password,
            pending.timeoutMs,
            pending.result,
        )
    }

    private fun startProvisioningRequest(
        ssidPrefix: String,
        password: String,
        timeoutMs: Int,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("ANDROID_VERSION", "Android 10+ gereklidir.", null)
            return
        }

        val specifier = WifiNetworkSpecifier.Builder()
            .setSsidPattern(PatternMatcher(ssidPrefix, PatternMatcher.PATTERN_PREFIX))
            .setWpa2Passphrase(password)
            .build()
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        val delivered = AtomicBoolean(false)
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                provisioningNetwork = network
                if (delivered.compareAndSet(false, true)) {
                    runOnUiThread {
                        result.success(
                            mapOf(
                                "connected" to true,
                                "ssid" to selectedSsid(network),
                            ),
                        )
                    }
                }
            }

            override fun onUnavailable() {
                if (activeCallback === this) activeCallback = null
                provisioningNetwork = null
                if (delivered.compareAndSet(false, true)) {
                    runOnUiThread {
                        result.error(
                            "WIFI_UNAVAILABLE",
                            "VisionSen kurulum ağı bulunamadı veya bağlantı onaylanmadı.",
                            null,
                        )
                    }
                }
            }

            override fun onLost(network: Network) {
                if (provisioningNetwork != network) return
                provisioningNetwork = null
                if (activeCallback === this) {
                    try {
                        connectivityManager.unregisterNetworkCallback(this)
                    } catch (_: Exception) {
                    }
                    activeCallback = null
                }
                notifyProvisioningDisconnected()
            }
        }

        activeCallback = callback
        try {
            connectivityManager.requestNetwork(request, callback, timeoutMs)
        } catch (e: SecurityException) {
            activeCallback = null
            provisioningNetwork = null
            if (delivered.compareAndSet(false, true)) {
                result.error("PERMISSION_DENIED", e.message, null)
            }
        } catch (e: Exception) {
            activeCallback = null
            provisioningNetwork = null
            if (delivered.compareAndSet(false, true)) {
                result.error("WIFI_UNAVAILABLE", e.message, null)
            }
        }
    }

    private fun selectedSsid(network: Network): String {
        return try {
            val wifiInfo = connectivityManager
                .getNetworkCapabilities(network)
                ?.transportInfo as? WifiInfo
            wifiInfo?.ssid
                ?.trim('"')
                ?.takeIf { it.isNotBlank() && it != UNKNOWN_SSID }
                ?: "VISIONSEN-OIM3-XXXX"
        } catch (_: Exception) {
            "VISIONSEN-OIM3-XXXX"
        }
    }

    private fun localHttpRequest(call: MethodCall, result: MethodChannel.Result) {
        val network = provisioningNetwork
        if (network == null) {
            result.error(
                "NO_PROVISIONING_NETWORK",
                "VisionSen cihaz Wi-Fi bağlantısı aktif değil.",
                null,
            )
            return
        }

        val method = call.argument<String>("method")?.uppercase() ?: "GET"
        val path = call.argument<String>("path") ?: "/"
        val body = call.argument<String>("body") ?: ""
        val timeoutMs = (call.argument<Number>("timeoutMs")?.toInt() ?: 5000)
            .coerceIn(1000, 15000)
        if (method !in setOf("GET", "POST") ||
            path !in setOf("/api/info", "/api/config")) {
            result.error("LOCAL_HTTP_ARGUMENT", "Yerel cihaz isteği reddedildi.", null)
            return
        }

        ioExecutor.execute {
            var connection: HttpURLConnection? = null
            try {
                connection = network.openConnection(
                    URL("http://192.168.4.1$path"),
                ) as HttpURLConnection
                connection.instanceFollowRedirects = false
                connection.connectTimeout = timeoutMs
                connection.readTimeout = timeoutMs
                connection.requestMethod = method
                connection.useCaches = false
                connection.setRequestProperty("Cache-Control", "no-store")
                connection.setRequestProperty("Connection", "close")

                if (method == "POST") {
                    val bytes = body.toByteArray(StandardCharsets.UTF_8)
                    connection.doOutput = true
                    connection.setRequestProperty(
                        "Content-Type",
                        "application/json; charset=utf-8",
                    )
                    connection.setFixedLengthStreamingMode(bytes.size)
                    connection.outputStream.use { it.write(bytes) }
                }

                val statusCode = connection.responseCode
                val stream = if (statusCode in 200..399) {
                    connection.inputStream
                } else {
                    connection.errorStream
                }
                val responseBody = stream
                    ?.bufferedReader(StandardCharsets.UTF_8)
                    ?.use { it.readText() }
                    .orEmpty()
                runOnUiThread {
                    result.success(
                        mapOf(
                            "statusCode" to statusCode,
                            "body" to responseBody,
                        ),
                    )
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error(
                        "LOCAL_HTTP",
                        e.message ?: "Yerel cihaz isteği başarısız.",
                        null,
                    )
                }
            } finally {
                connection?.disconnect()
            }
        }
    }

    private fun disconnectProvisioningInternal(notifyFlutter: Boolean) {
        activeCallback?.let { callback ->
            try {
                connectivityManager.unregisterNetworkCallback(callback)
            } catch (_: Exception) {
            }
        }
        activeCallback = null
        val hadNetwork = provisioningNetwork != null
        provisioningNetwork = null
        pendingConnect = null
        if (notifyFlutter && hadNetwork) notifyProvisioningDisconnected()
    }

    private fun notifyProvisioningDisconnected() {
        runOnUiThread {
            methodChannel?.invokeMethod("provisioningDisconnected", null)
        }
    }

    override fun onDestroy() {
        disconnectProvisioningInternal(notifyFlutter = false)
        ioExecutor.shutdownNow()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        super.onDestroy()
    }

    companion object {
        private const val UNKNOWN_SSID = "<unknown ssid>"
    }
}
KOTLIN

echo "Android local-only provisioning hazır: WifiNetworkSpecifier + Network.openConnection; process bind yok."
