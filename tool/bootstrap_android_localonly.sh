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
    'android.permission.ACCESS_NETWORK_STATE',
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
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
    <uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
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
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.Inet4Address
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val channelName = "com.visionsen/setup"
    private val connectPermissionRequestCode = 4173
    private val scanPermissionRequestCode = 4174
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private lateinit var connectivityManager: ConnectivityManager
    private lateinit var wifiManager: WifiManager
    private var methodChannel: MethodChannel? = null
    private var provisioningNetwork: Network? = null
    private var provisioningSsid: String? = null
    private var activeCallback: ConnectivityManager.NetworkCallback? = null
    private var pendingConnect: PendingConnect? = null
    private var pendingScan: PendingScan? = null
    private var dhcpTimeoutRunnable: Runnable? = null

    private data class PendingConnect(
        val ssid: String,
        val password: String,
        val timeoutMs: Int,
        val result: MethodChannel.Result,
    )

    private data class PendingScan(
        val ssidPrefix: String,
        val result: MethodChannel.Result,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        wifiManager = applicationContext
            .getSystemService(Context.WIFI_SERVICE) as WifiManager

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanProvisioningWifi" -> scanProvisioningWifi(call, result)
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

    private fun scanProvisioningWifi(call: MethodCall, result: MethodChannel.Result) {
        val prefix = call.argument<String>("ssidPrefix")?.trim().orEmpty()
        if (prefix.isEmpty()) {
            result.error("WIFI_ARGUMENT", "Kurulum Wi-Fi öneki geçersiz.", null)
            return
        }
        if (!wifiManager.isWifiEnabled) {
            result.success(mapOf("wifiEnabled" to false, "devices" to emptyList<Any>()))
            return
        }

        val missing = missingScanPermissions()
        if (missing.isNotEmpty()) {
            pendingScan = PendingScan(prefix, result)
            requestPermissions(missing.toTypedArray(), scanPermissionRequestCode)
            return
        }
        startProvisioningScan(prefix, result)
    }

    private fun missingScanPermissions(): List<String> {
        val required = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED) {
            required += Manifest.permission.ACCESS_FINE_LOCATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) !=
            PackageManager.PERMISSION_GRANTED) {
            required += Manifest.permission.NEARBY_WIFI_DEVICES
        }
        return required
    }

    private fun startProvisioningScan(
        ssidPrefix: String,
        result: MethodChannel.Result,
    ) {
        if (!wifiManager.isWifiEnabled) {
            result.success(mapOf("wifiEnabled" to false, "devices" to emptyList<Any>()))
            return
        }
        try {
            // startScan may be throttled on recent Android versions. We still
            // read the cached scan list after a short delay, which is normally
            // refreshed by the system Wi-Fi subsystem.
            wifiManager.startScan()
            mainHandler.postDelayed({
                try {
                    result.success(
                        mapOf(
                            "wifiEnabled" to wifiManager.isWifiEnabled,
                            "devices" to readVisionSenScanResults(ssidPrefix),
                        ),
                    )
                } catch (e: SecurityException) {
                    result.error("PERMISSION_DENIED", e.message, null)
                } catch (e: Exception) {
                    result.error("WIFI_SCAN", e.message, null)
                }
            }, 1800L)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.message, null)
        } catch (e: Exception) {
            result.error("WIFI_SCAN", e.message, null)
        }
    }

    @Suppress("DEPRECATION")
    private fun readVisionSenScanResults(ssidPrefix: String): List<Map<String, Any>> {
        return wifiManager.scanResults
            .asSequence()
            .mapNotNull { scan ->
                val ssid = scan.SSID?.trim().orEmpty()
                if (!ssid.startsWith(ssidPrefix)) return@mapNotNull null
                mapOf(
                    "ssid" to ssid,
                    "rssi" to scan.level,
                )
            }
            .groupBy { it["ssid"] as String }
            .map { (_, entries) ->
                entries.maxByOrNull { (it["rssi"] as Int) } ?: entries.first()
            }
            .sortedByDescending { it["rssi"] as Int }
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
        if (!wifiManager.isWifiEnabled) {
            result.error("WIFI_DISABLED", "Telefon Wi-Fi kapalı.", null)
            return
        }

        val ssid = call.argument<String>("ssid")?.trim().orEmpty()
        val password = call.argument<String>("password").orEmpty()
        val timeoutMs = (call.argument<Number>("timeoutMs")?.toInt() ?: 35000)
            .coerceIn(15000, 60000)
        if (ssid.isEmpty() || password.length < 8) {
            result.error("WIFI_ARGUMENT", "Kurulum Wi-Fi bilgileri geçersiz.", null)
            return
        }

        if (provisioningNetwork != null && provisioningSsid == ssid) {
            result.success(
                mapOf(
                    "connected" to true,
                    "ssid" to ssid,
                    "localIp" to localIpv4(provisioningNetwork),
                ),
            )
            return
        }
        if (pendingConnect != null || activeCallback != null) {
            result.error("WIFI_BUSY", "Wi-Fi bağlantı isteği devam ediyor.", null)
            return
        }

        val permission = requiredConnectPermission()
        if (permission != null &&
            checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            pendingConnect = PendingConnect(ssid, password, timeoutMs, result)
            requestPermissions(arrayOf(permission), connectPermissionRequestCode)
            return
        }

        startProvisioningRequest(ssid, password, timeoutMs, result)
    }

    private fun requiredConnectPermission(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.NEARBY_WIFI_DEVICES
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }

        if (requestCode == scanPermissionRequestCode) {
            val pending = pendingScan ?: return
            pendingScan = null
            if (!granted) {
                pending.result.error(
                    "PERMISSION_DENIED",
                    "Wi-Fi cihaz tarama izni verilmedi.",
                    null,
                )
                return
            }
            startProvisioningScan(pending.ssidPrefix, pending.result)
            return
        }

        if (requestCode == connectPermissionRequestCode) {
            val pending = pendingConnect ?: return
            pendingConnect = null
            if (!granted) {
                pending.result.error(
                    "PERMISSION_DENIED",
                    "Yakındaki Wi-Fi cihazlarına erişim izni verilmedi.",
                    null,
                )
                return
            }
            startProvisioningRequest(
                pending.ssid,
                pending.password,
                pending.timeoutMs,
                pending.result,
            )
        }
    }

    private fun startProvisioningRequest(
        ssid: String,
        password: String,
        timeoutMs: Int,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("ANDROID_VERSION", "Android 10+ gereklidir.", null)
            return
        }

        disconnectProvisioningInternal(notifyFlutter = false)

        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
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
                provisioningSsid = ssid
                deliverIfDhcpReady(network, ssid, result, delivered)

                val timeout = Runnable {
                    if (provisioningNetwork == network &&
                        delivered.compareAndSet(false, true)) {
                        disconnectProvisioningInternal(notifyFlutter = false)
                        result.error(
                            "DHCP_TIMEOUT",
                            "Cihaz ağına bağlanıldı ancak 192.168.4.x yerel IP alınamadı.",
                            null,
                        )
                    }
                }
                dhcpTimeoutRunnable = timeout
                mainHandler.postDelayed(timeout, 9000L)
            }

            override fun onLinkPropertiesChanged(
                network: Network,
                linkProperties: LinkProperties,
            ) {
                if (provisioningNetwork != network) return
                deliverIfDhcpReady(network, ssid, result, delivered, linkProperties)
            }

            override fun onUnavailable() {
                if (activeCallback === this) activeCallback = null
                provisioningNetwork = null
                provisioningSsid = null
                cancelDhcpTimeout()
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
                provisioningSsid = null
                cancelDhcpTimeout()
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
            provisioningSsid = null
            if (delivered.compareAndSet(false, true)) {
                result.error("PERMISSION_DENIED", e.message, null)
            }
        } catch (e: Exception) {
            activeCallback = null
            provisioningNetwork = null
            provisioningSsid = null
            if (delivered.compareAndSet(false, true)) {
                result.error("WIFI_UNAVAILABLE", e.message, null)
            }
        }
    }

    private fun deliverIfDhcpReady(
        network: Network,
        ssid: String,
        result: MethodChannel.Result,
        delivered: AtomicBoolean,
        suppliedLinkProperties: LinkProperties? = null,
    ) {
        val localIp = localIpv4(network, suppliedLinkProperties) ?: return
        if (!localIp.startsWith("192.168.4.")) return
        if (!delivered.compareAndSet(false, true)) return
        cancelDhcpTimeout()
        runOnUiThread {
            result.success(
                mapOf(
                    "connected" to true,
                    "ssid" to ssid,
                    "localIp" to localIp,
                ),
            )
        }
    }

    private fun localIpv4(
        network: Network?,
        suppliedLinkProperties: LinkProperties? = null,
    ): String? {
        if (network == null) return null
        return try {
            val linkProperties = suppliedLinkProperties
                ?: connectivityManager.getLinkProperties(network)
            linkProperties?.linkAddresses
                ?.asSequence()
                ?.map { it.address }
                ?.filterIsInstance<Inet4Address>()
                ?.firstOrNull { !it.isLoopbackAddress }
                ?.hostAddress
        } catch (_: Exception) {
            null
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
                ?: provisioningSsid
                ?: "VISIONSEN-OIM3-XXXX"
        } catch (_: Exception) {
            provisioningSsid ?: "VISIONSEN-OIM3-XXXX"
        }
    }

    private fun localHttpRequest(call: MethodCall, result: MethodChannel.Result) {
        val network = provisioningNetwork
        if (network == null || localIpv4(network)?.startsWith("192.168.4.") != true) {
            result.error(
                "NO_PROVISIONING_NETWORK",
                "VisionSen cihaz Wi-Fi bağlantısı aktif değil veya DHCP hazır değil.",
                null,
            )
            return
        }

        val method = call.argument<String>("method")?.uppercase() ?: "GET"
        val path = call.argument<String>("path") ?: "/"
        val body = call.argument<String>("body") ?: ""
        val timeoutMs = (call.argument<Number>("timeoutMs")?.toInt() ?: 6500)
            .coerceIn(1000, 15000)
        if (method !in setOf("GET", "POST") ||
            path !in setOf("/api/info", "/api/config")) {
            result.error("LOCAL_HTTP_ARGUMENT", "Yerel cihaz isteği reddedildi.", null)
            return
        }

        ioExecutor.execute {
            val attempts = if (method == "GET") 4 else 1
            var lastError: Exception? = null
            for (attempt in 1..attempts) {
                var connection: HttpURLConnection? = null
                try {
                    val conn = network.openConnection(
                        URL("http://192.168.4.1$path"),
                    ) as HttpURLConnection
                    connection = conn
                    conn.instanceFollowRedirects = false
                    conn.connectTimeout = timeoutMs
                    conn.readTimeout = timeoutMs
                    conn.requestMethod = method
                    conn.useCaches = false
                    conn.setRequestProperty("Cache-Control", "no-store")
                    conn.setRequestProperty("Connection", "close")

                    if (method == "POST") {
                        val bytes = body.toByteArray(StandardCharsets.UTF_8)
                        conn.doOutput = true
                        conn.setRequestProperty(
                            "Content-Type",
                            "application/json; charset=utf-8",
                        )
                        conn.setFixedLengthStreamingMode(bytes.size)
                        conn.outputStream.use { it.write(bytes) }
                    }

                    val statusCode = conn.responseCode
                    val stream = if (statusCode in 200..399) {
                        conn.inputStream
                    } else {
                        conn.errorStream
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
                    return@execute
                } catch (e: Exception) {
                    lastError = e
                    if (attempt < attempts) {
                        try {
                            Thread.sleep(350L * attempt)
                        } catch (_: InterruptedException) {
                            Thread.currentThread().interrupt()
                            break
                        }
                    }
                } finally {
                    connection?.disconnect()
                }
            }

            runOnUiThread {
                result.error(
                    "LOCAL_HTTP",
                    lastError?.message ?: "Yerel cihaz isteği başarısız.",
                    null,
                )
            }
        }
    }

    private fun cancelDhcpTimeout() {
        dhcpTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        dhcpTimeoutRunnable = null
    }

    private fun disconnectProvisioningInternal(notifyFlutter: Boolean) {
        cancelDhcpTimeout()
        activeCallback?.let { callback ->
            try {
                connectivityManager.unregisterNetworkCallback(callback)
            } catch (_: Exception) {
            }
        }
        activeCallback = null
        val hadNetwork = provisioningNetwork != null
        provisioningNetwork = null
        provisioningSsid = null
        pendingConnect = null
        if (notifyFlutter && hadNetwork) notifyProvisioningDisconnected()
    }

    private fun notifyProvisioningDisconnected() {
        runOnUiThread {
            methodChannel?.invokeMethod("provisioningDisconnected", null)
        }
    }

    override fun onStop() {
        // Once a provisioning network is actually active, leaving the app must
        // release it. Pending Android connection/permission dialogs are not
        // cancelled here because provisioningNetwork is still null at that time.
        if (::connectivityManager.isInitialized &&
            provisioningNetwork != null &&
            !isChangingConfigurations) {
            disconnectProvisioningInternal(notifyFlutter = true)
        }
        super.onStop()
    }

    override fun onDestroy() {
        if (::connectivityManager.isInitialized) {
            disconnectProvisioningInternal(notifyFlutter = false)
        }
        pendingScan = null
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

echo "Android robust provisioning hazır: discovery + exact SSID + DHCP verify + local HTTP retry + lifecycle cleanup."
