#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/bootstrap_android_v164.sh"

MANIFEST="android/app/src/main/AndroidManifest.xml"
MAIN="android/app/src/main/kotlin/com/visionsen/visionsen_setup/MainActivity.kt"

# ConnectivityManager.requestNetwork() requires CHANGE_NETWORK_STATE (or the
# unrelated WRITE_SETTINGS special access). CHANGE_NETWORK_STATE is a normal
# install-time permission, so it does not show a runtime dialog and does not
# expose location data.
python3 - "$MANIFEST" <<'PYEOF'
from pathlib import Path
import re, sys

p = Path(sys.argv[1])
t = p.read_text(encoding='utf-8')
# Make the operation idempotent.
t = re.sub(
    r'\s*<uses-permission[^>]+android:name="android\.permission\.CHANGE_NETWORK_STATE"[^>]*/>\s*',
    '\n',
    t,
)
needle = '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />'
if needle not in t:
    raise SystemExit('ACCESS_NETWORK_STATE manifest permission not found')
t = t.replace(
    needle,
    needle + '\n    <uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />',
    1,
)
p.write_text(t, encoding='utf-8')
PYEOF

# Add a native preflight so a packaging regression can never be misreported as
# a Nearby Wi-Fi runtime permission problem again.
python3 - "$MAIN" <<'PYEOF'
from pathlib import Path
import sys

p = Path(sys.argv[1])
t = p.read_text(encoding='utf-8')
old = '''    private fun startProvisioningRequest(
        ssid: String,
        password: String,
        timeoutMs: Int,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
'''
new = '''    private fun startProvisioningRequest(
        ssid: String,
        password: String,
        timeoutMs: Int,
        result: MethodChannel.Result,
    ) {
        if (checkSelfPermission(Manifest.permission.CHANGE_NETWORK_STATE) !=
            PackageManager.PERMISSION_GRANTED) {
            releaseActiveAssociation()
            result.error(
                "APP_NETWORK_PERMISSION_MISSING",
                "Uygulama paketinde CHANGE_NETWORK_STATE izni etkin değil. Uygulamayı güncelleyin.",
                mapOf("permission" to Manifest.permission.CHANGE_NETWORK_STATE),
            )
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
'''
if old not in t:
    raise SystemExit('v1.6.5 preflight patch target not found')
t = t.replace(old, new, 1)
p.write_text(t, encoding='utf-8')
PYEOF

# Keep visible build version aligned in the generated APK without changing the
# provisioning behavior.
python3 - <<'PYEOF'
from pathlib import Path
p = Path('lib/screens/wifi_provision_screen.dart')
if p.exists():
    t = p.read_text(encoding='utf-8')
    t = t.replace(
        'Mobil v1.6.4+22 • Konum izinsiz Wi-Fi + sağlamlaştırılmış izin akışı',
        'Mobil v1.6.5+23 • Konum izinsiz Wi-Fi + ağ izin düzeltmesi',
    )
    p.write_text(t, encoding='utf-8')
PYEOF

echo "Android v1.6.5 provisioning hazır: CHANGE_NETWORK_STATE + preflight + no-location flow."
