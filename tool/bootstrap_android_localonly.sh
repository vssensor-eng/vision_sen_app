#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/bootstrap_android.sh"

# Keep the generated/test APK UI aligned with the no-location discovery flow.
python3 - <<'PYEOF'
from pathlib import Path
p = Path('lib/screens/wifi_provision_screen.dart')
if p.exists():
    t = p.read_text(encoding='utf-8')
    t = t.replace(
        '3. Uygulamada listelenen VISIONSEN-OIM3 cihazını seçin.',
        '3. Android cihaz seçim ekranında VISIONSEN-OIM3 cihazını seçin. Konum izni kullanılmaz.',
    )
    t = t.replace(
        'Mobil v1.6.2+20 • Wi-Fi discovery + DHCP doğrulamalı Provisioning Protocol v2',
        'Mobil v1.6.3+21 • Konum izinsiz Wi-Fi seçim + DHCP doğrulamalı Provisioning Protocol v2',
    )
    p.write_text(t, encoding='utf-8')
PYEOF

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
    'android.permission.ACCESS_COARSE_LOCATION',
]:
    text = re.sub(
        r'\s*<uses-permission[^>]+android:name="' + re.escape(permission) + r'"[^>]*/>\s*',
        '\n',
        text,
    )
text = re.sub(
    r'\s*<uses-feature[^>]+android:name="android\.software\.companion_device_setup"[^>]*/>\s*',
    '\n',
    text,
)
perms = '''    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
    <uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" android:usesPermissionFlags="neverForLocation" />
    <uses-feature android:name="android.software.companion_device_setup" android:required="false" />
'''
text = re.sub(r'(<manifest[^>]*>)', r'\1\n' + perms, text, count=1)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

MAIN_ACTIVITY="android/app/src/main/kotlin/com/visionsen/visionsen_setup/MainActivity.kt"
cat > "$MAIN_ACTIVITY" <<'KOTLIN'
package com.visionsen.visionsen_setup

import android.Manifest
import android.app.Activity
import android.companion.AssociationInfo
import android.companion.AssociationRequest
import android.companion.CompanionDeviceManager
import android.companion.WifiDeviceFilter
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.ScanResult
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
import java.util.regex.Pattern

class MainActivity : FlutterActivity() {
    private val channelName = "com.visionsen/setup"
    private val connectPermissionRequestCode = 4173
    private val companionDeviceRequestCode = 4175
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private lateinit var connectivityManager: ConnectivityManager
    private lateinit var wifiManager: WifiManager
    private lateinit var companionDeviceManager: CompanionDeviceManager
    private var methodChannel: MethodChannel? = null

    private var provisioningNetwork: Network? = null
    private var provisioningSsid: String? = null
    private var activeCallback: ConnectivityManager.NetworkCallback? = null
    private var pendingConnect: PendingConnect? = null
    private var pendingDiscovery: PendingDiscovery? = null
    private var pendingAssociationInfo: AssociationInfo? = null
    private var companionChooserLaunched = false
    private var dhcpTimeoutRunnable: Runnable? = null

    private data class PendingConnect(
        val ssid: String,
        val password: String,
        val timeoutMs: Int,
        val result: MethodChannel.Result,
    )

    private data class PendingDiscovery(
        val ssidPrefix: String,
        val result: MethodChannel.Result,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        wifiManager = applicationContext
            .getSystemService(Context.WIFI_SERVICE) as WifiManager
        companionDeviceManager =
            getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager

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
            result.success(
                mapOf(
                    "wifiEnabled" to false,
                    "devices" to emptyList<Any>(),
                    "cancelled" to false,
                ),
            )
            return
        }
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_COMPANION_DEVICE_SETUP)) {
            result.error(
                "COMPANION_UNAVAILABLE",
                "Bu telefonda Android yardımcı cihaz seçim servisi kullanılamıyor.",
                null,
            )
            return
        }
        if (pendingDiscovery != null) {
            result.error("WIFI_BUSY", "Cihaz arama ekranı zaten açık.", null)
            return
        }

        val filter = WifiDeviceFilter.Builder()
            .setNamePattern(Pattern.compile("^${Pattern.quote(prefix)}.*$"))
            .build()
        val request = AssociationRequest.Builder()
            .addDeviceFilter(filter)
            .setSingleDevice(false)
            .build()

        pendingDiscovery = PendingDiscovery(prefix, result)
        pendingAssociationInfo = null
        companionChooserLaunched = false

        val callback = object : CompanionDeviceManager.Callback() {
            @Suppress("DEPRECATION")
            override fun onDeviceFound(chooserLauncher: IntentSender) {
                launchCompanionChooser(chooserLauncher)
            }

            override fun onAssociationPending(intentSender: IntentSender) {
                launchCompanionChooser(intentSender)
            }

            override fun onAssociationCreated(associationInfo: AssociationInfo) {
                pendingAssociationInfo = associationInfo
                if (!companionChooserLaunched) {
                    val scan = wifiScanFromAssociation(associationInfo)
                    val ssid = scanSsid(scan)
                        ?: associationInfo.displayName?.toString()?.trim()?.trim('"')
                    if (ssid != null && ssid.startsWith(prefix)) {
                        completeCompanionDiscovery(ssid, scan?.level ?: -60, associationInfo)
                    }
                }
            }

            override fun onFailure(errorMessage: CharSequence?) {
                val pending = pendingDiscovery ?: return
                pendingDiscovery = null
                pendingAssociationInfo = null
                companionChooserLaunched = false
                runOnUiThread {
                    pending.result.error(
                        "WIFI_SCAN",
                        errorMessage?.toString()?.takeIf { it.isNotBlank() }
                            ?: "VisionSen cihaz seçim ekranı açılamadı.",
                        null,
                    )
                }
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                companionDeviceManager.associate(request, mainExecutor, callback)
            } else {
                @Suppress("DEPRECATION")
                companionDeviceManager.associate(request, callback, mainHandler)
            }
        } catch (e: Exception) {
            pendingDiscovery = null
            pendingAssociationInfo = null
            companionChooserLaunched = false
            result.error(
                "WIFI_SCAN",
                e.message ?: "VisionSen cihaz seçim ekranı açılamadı.",
                null,
            )
        }
    }

    private fun launchCompanionChooser(sender: IntentSender) {
        if (pendingDiscovery == null || companionChooserLaunched) return
        companionChooserLaunched = true
        runOnUiThread {
            try {
                startIntentSenderForResult(
                    sender,
                    companionDeviceRequestCode,
                    null,
                    0,
                    0,
                    0,
                )
            } catch (e: IntentSender.SendIntentException) {
                val pending = pendingDiscovery
                pendingDiscovery = null
                pendingAssociationInfo = null
                companionChooserLaunched = false
                pending?.result?.error(
                    "WIFI_SCAN",
                    e.message ?: "Android cihaz seçim ekranı açılamadı.",
                    null,
                )
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != companionDeviceRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val pending = pendingDiscovery
        if (pending == null) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            pendingDiscovery = null
            pendingAssociationInfo = null
            companionChooserLaunched = false
            pending.result.success(
                mapOf(
                    "wifiEnabled" to wifiManager.isWifiEnabled,
                    "devices" to emptyList<Any>(),
                    "cancelled" to true,
                ),
            )
            return
        }

        val association = associationFromResult(data) ?: pendingAssociationInfo
        val scan = scanResultFromResult(data) ?: wifiScanFromAssociation(association)
        val ssid = scanSsid(scan)
            ?: association?.displayName?.toString()?.trim()?.trim('"')

        if (ssid == null || !ssid.startsWith(pending.ssidPrefix)) {
            pendingDiscovery = null
            pendingAssociationInfo = null
            companionChooserLaunched = false
            disassociateCompanion(association, scan)
            pending.result.error(
                "WIFI_SCAN",
                "Seçilen ağ VisionSen kurulum ağı olarak doğrulanamadı.",
                null,
            )
            return
        }

        completeCompanionDiscovery(ssid, scan?.level ?: -60, association, scan)
    }

    private fun completeCompanionDiscovery(
        ssid: String,
        rssi: Int,
        association: AssociationInfo?,
        scan: ScanResult? = null,
    ) {
        val pending = pendingDiscovery ?: return
        pendingDiscovery = null
        pendingAssociationInfo = null
        companionChooserLaunched = false
        disassociateCompanion(association, scan)
        runOnUiThread {
            pending.result.success(
                mapOf(
                    "wifiEnabled" to wifiManager.isWifiEnabled,
                    "devices" to listOf(
                        mapOf(
                            "ssid" to ssid,
                            "rssi" to rssi,
                        ),
                    ),
                    "cancelled" to false,
                    "systemSelected" to true,
                ),
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun scanResultFromResult(data: Intent?): ScanResult? {
        if (data == null) return null
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                data.getParcelableExtra(
                    CompanionDeviceManager.EXTRA_DEVICE,
                    ScanResult::class.java,
                )
            } else {
                data.getParcelableExtra(CompanionDeviceManager.EXTRA_DEVICE) as? ScanResult
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun associationFromResult(data: Intent?): AssociationInfo? {
        if (data == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return null
        }
        return try {
            data.getParcelableExtra(
                CompanionDeviceManager.EXTRA_ASSOCIATION,
                AssociationInfo::class.java,
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun wifiScanFromAssociation(info: AssociationInfo?): ScanResult? {
        if (info == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return null
        }
        return try {
            info.associatedDevice?.wifiDevice
        } catch (_: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun scanSsid(scan: ScanResult?): String? {
        if (scan == null) return null
        val value = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                scan.wifiSsid?.toString()
            } else {
                scan.SSID
            }
        } catch (_: Exception) {
            scan.SSID
        }
        return value?.trim()?.trim('"')?.takeIf { it.isNotBlank() }
    }

    @Suppress("DEPRECATION")
    private fun disassociateCompanion(info: AssociationInfo?, scan: ScanResult?) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && info != null) {
                companionDeviceManager.disassociate(info.id)
            } else {
                val bssid = scan?.BSSID?.trim().orEmpty()
                if (bssid.isNotEmpty()) companionDeviceManager.disassociate(bssid)
            }
        } catch (_: Exception) {
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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) !=
            PackageManager.PERMISSION_GRANTED) {
            pendingConnect = PendingConnect(ssid, password, timeoutMs, result)
            requestPermissions(
                arrayOf(Manifest.permission.NEARBY_WIFI_DEVICES),
                connectPermissionRequestCode,
            )
            return
        }

        startProvisioningRequest(ssid, password, timeoutMs, result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != connectPermissionRequestCode) return

        val pending = pendingConnect ?: return
        pendingConnect = null
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        if (!granted) {
            pending.result.error(
                "NEARBY_PERMISSION_DENIED",
                "Android Yakındaki Wi-Fi cihazları izni verilmedi.",
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
                val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    "NEARBY_PERMISSION_DENIED"
                } else {
                    "WIFI_UNAVAILABLE"
                }
                result.error(code, e.message, null)
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
        pendingDiscovery = null
        pendingAssociationInfo = null
        ioExecutor.shutdownNow()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        super.onDestroy()
    }
}
KOTLIN

echo "Android provisioning hazır: no-location companion discovery + exact SSID + DHCP verify + local HTTP retry + lifecycle cleanup."
