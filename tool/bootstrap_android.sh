#!/usr/bin/env bash
set -euo pipefail

# Kaynak ZIP android/ platform klasörünü bilinçli olarak taşımıyor. Aynı Flutter
# sürümüyle deterministik Android iskeleti üretir ve gerekli BLE/ağ izinlerini ekler.
if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter komutu bulunamadı. Flutter 3.24.0 kurup PATH'e ekleyin." >&2
  exit 1
fi

if [ ! -d android ]; then
  flutter create --platforms=android --project-name vision_sen_app --org com.visionsen .
fi

MANIFEST="android/app/src/main/AndroidManifest.xml"
python3 - "$MANIFEST" <<'PYEOF'
import sys, re
path = sys.argv[1]
content = open(path, encoding='utf-8').read()
perms = '''    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
'''
if 'android.permission.BLUETOOTH_SCAN' not in content:
    content = re.sub(r'(<manifest[^>]*>)', r'\1\n' + perms, content, count=1)
open(path, 'w', encoding='utf-8').write(content)
PYEOF

echo "Android platform dosyaları hazır."
