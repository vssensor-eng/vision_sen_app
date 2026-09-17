#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/bootstrap_android_localonly.sh"

MAIN="android/app/src/main/kotlin/com/visionsen/visionsen_setup/MainActivity.kt"
python3 - "$MAIN" <<'PYEOF'
from pathlib import Path
import sys

p = Path(sys.argv[1])
t = p.read_text(encoding='utf-8')

def rep(old: str, new: str, label: str):
    global t
    if old not in t:
        raise SystemExit(f'v1.6.4 patch target not found: {label}')
    t = t.replace(old, new, 1)

rep(
'''    private var pendingAssociationInfo: AssociationInfo? = null
    private var companionChooserLaunched = false
''',
'''    private var pendingAssociationInfo: AssociationInfo? = null
    private var activeAssociationInfo: AssociationInfo? = null
    private var activeAssociationBssid: String? = null
    private var companionChooserLaunched = false
''',
'active association fields',
)

rep(
'''        pendingDiscovery = null
        pendingAssociationInfo = null
        companionChooserLaunched = false
        disassociateCompanion(association, scan)
        runOnUiThread {
''',
'''        pendingDiscovery = null
        pendingAssociationInfo = null
        companionChooserLaunched = false
        releaseActiveAssociation()
        activeAssociationInfo = association
        activeAssociationBssid = scan?.BSSID?.trim()?.takeIf { it.isNotEmpty() }
        runOnUiThread {
''',
'keep companion association through provisioning',
)

rep(
'''        val pending = pendingConnect ?: return
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
''',
'''        val pending = pendingConnect ?: return
        pendingConnect = null

        // Some OEM permission controllers can report a stale grantResults value
        // while the package permission has already been committed. Re-read the
        // actual package permission state after the system dialog settles.
        mainHandler.postDelayed({
            val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) ==
                PackageManager.PERMISSION_GRANTED
            if (!granted) {
                releaseActiveAssociation()
                pending.result.error(
                    "NEARBY_PERMISSION_DENIED",
                    "Android Yakındaki Wi-Fi cihazları izni gerçekten etkin değil.",
                    mapOf(
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "permissionGranted" to false,
                    ),
                )
                return@postDelayed
            }
            startProvisioningRequest(
                pending.ssid,
                pending.password,
                pending.timeoutMs,
                pending.result,
            )
        }, 250L)
''',
'permission callback recheck',
)

rep(
'''                provisioningNetwork = null
                provisioningSsid = null
                cancelDhcpTimeout()
                if (delivered.compareAndSet(false, true)) {
''',
'''                provisioningNetwork = null
                provisioningSsid = null
                cancelDhcpTimeout()
                releaseActiveAssociation()
                if (delivered.compareAndSet(false, true)) {
''',
'onUnavailable association cleanup',
)

rep(
'''                if (activeCallback === this) {
                    try {
                        connectivityManager.unregisterNetworkCallback(this)
                    } catch (_: Exception) {
                    }
                    activeCallback = null
                }
                notifyProvisioningDisconnected()
''',
'''                if (activeCallback === this) {
                    try {
                        connectivityManager.unregisterNetworkCallback(this)
                    } catch (_: Exception) {
                    }
                    activeCallback = null
                }
                releaseActiveAssociation()
                notifyProvisioningDisconnected()
''',
'onLost association cleanup',
)

rep(
'''        } catch (e: SecurityException) {
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
''',
'''        } catch (e: SecurityException) {
            activeCallback = null
            provisioningNetwork = null
            provisioningSsid = null
            releaseActiveAssociation()
            if (delivered.compareAndSet(false, true)) {
                val nearbyGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                    checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) ==
                    PackageManager.PERMISSION_GRANTED
                val code = when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !nearbyGranted ->
                        "NEARBY_PERMISSION_DENIED"
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ->
                        "ANDROID_LEGACY_LOCATION_REQUIRED"
                    else -> "WIFI_SECURITY"
                }
                val message = when (code) {
                    "NEARBY_PERMISSION_DENIED" ->
                        "Android Yakındaki Wi-Fi cihazları izni etkin değil."
                    "ANDROID_LEGACY_LOCATION_REQUIRED" ->
                        "Android 12L ve altı sürümlerde otomatik Wi-Fi bağlantısı işletim sistemi tarafından konum iznine bağlanmıştır."
                    else ->
                        "Android Wi-Fi bağlantı isteğini güvenlik nedeniyle reddetti: ${e.message ?: "bilinmeyen neden"}"
                }
                result.error(
                    code,
                    message,
                    mapOf(
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "nearbyPermissionGranted" to nearbyGranted,
                        "exception" to (e.message ?: ""),
                    ),
                )
            }
''',
'SecurityException classification',
)

rep(
'''        } catch (e: Exception) {
            activeCallback = null
            provisioningNetwork = null
            provisioningSsid = null
            if (delivered.compareAndSet(false, true)) {
''',
'''        } catch (e: Exception) {
            activeCallback = null
            provisioningNetwork = null
            provisioningSsid = null
            releaseActiveAssociation()
            if (delivered.compareAndSet(false, true)) {
''',
'generic connect failure cleanup',
)

rep(
'''    private fun notifyProvisioningDisconnected() {
''',
'''    @Suppress("DEPRECATION")
    private fun releaseActiveAssociation() {
        val info = activeAssociationInfo
        val bssid = activeAssociationBssid
        activeAssociationInfo = null
        activeAssociationBssid = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && info != null) {
                companionDeviceManager.disassociate(info.id)
            } else if (!bssid.isNullOrBlank()) {
                companionDeviceManager.disassociate(bssid)
            }
        } catch (_: Exception) {
        }
    }

    private fun notifyProvisioningDisconnected() {
''',
'release association helper',
)

rep(
'''        provisioningNetwork = null
        provisioningSsid = null
        pendingConnect = null
        if (notifyFlutter && hadNetwork) notifyProvisioningDisconnected()
''',
'''        provisioningNetwork = null
        provisioningSsid = null
        pendingConnect = null
        releaseActiveAssociation()
        if (notifyFlutter && hadNetwork) notifyProvisioningDisconnected()
''',
'disconnect association cleanup',
)

p.write_text(t, encoding='utf-8')
PYEOF

echo "Android v1.6.4 provisioning hardening hazır: permission recheck + association lifetime + truthful security errors."
