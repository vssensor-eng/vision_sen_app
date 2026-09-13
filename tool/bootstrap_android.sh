#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter komutu bulunamadı. Flutter 3.24.0 kurup PATH'e ekleyin." >&2
  exit 1
fi

if [ ! -d android ]; then
  flutter create --platforms=android --project-name visionsen_setup --org com.visionsen .
fi

MANIFEST="android/app/src/main/AndroidManifest.xml"
python3 - "$MANIFEST" <<'PYEOF'
import sys, re
path = sys.argv[1]
content = open(path, encoding='utf-8').read()

# VisionSen BLE taraması konum amacıyla kullanılmaz. Eski paketlerden kalmış
# konum ve bildirim izinlerini de temizliyoruz.
for permission in [
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.BLUETOOTH',
    'android.permission.BLUETOOTH_ADMIN',
    'android.permission.BLUETOOTH_SCAN',
    'android.permission.BLUETOOTH_CONNECT',
    'android.permission.INTERNET',
    'android.permission.ACCESS_WIFI_STATE',
    'android.permission.CHANGE_WIFI_STATE',
]:
    content = re.sub(
        r'\s*<uses-permission[^>]+android:name="' + re.escape(permission) + r'"[^>]*/>\s*',
        '\n',
        content,
    )

perms = '''    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
'''

content = re.sub(r'(<manifest[^>]*>)', r'\1\n' + perms, content, count=1)
open(path, 'w', encoding='utf-8').write(content)
PYEOF

# v1.4.1'de eklenen yerel sesli alarm MethodChannel köprüsünü kaldır.
MAIN_ACTIVITY="android/app/src/main/kotlin/com/visionsen/visionsen_setup/MainActivity.kt"
mkdir -p "$(dirname "$MAIN_ACTIVITY")"
cat > "$MAIN_ACTIVITY" <<'KOTLIN'
package com.visionsen.visionsen_setup

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
KOTLIN

echo "Android platform dosyaları hazır. Konum ve yerel sesli alarm bildirimi yok."

rm -f test/widget_test.dart

python3 - <<'PYEOF'
import re
from pathlib import Path

for name in ('android/app/build.gradle', 'android/app/build.gradle.kts'):
    p = Path(name)
    if not p.exists():
        continue

    t = p.read_text()
    t = re.sub(r'compileSdk\s*=?\s*[^\n]+', 'compileSdk = 35', t, count=1)

    if re.search(r'ndkVersion\s*=?\s*[^\n]+', t):
        t = re.sub(r'ndkVersion\s*=?\s*[^\n]+', 'ndkVersion = "26.1.10909125"', t, count=1)
    else:
        t = re.sub(r'(android\s*\{)', r'\1\n    ndkVersion = "26.1.10909125"', t, count=1)

    if name.endswith('.kts'):
        dep1 = '    implementation("com.google.errorprone:error_prone_annotations:2.36.0")'
        dep2 = '    implementation("com.google.code.findbugs:jsr305:3.0.2")'
        block = f'\ndependencies {{\n{dep1}\n{dep2}\n}}\n'
    else:
        dep1 = "    implementation 'com.google.errorprone:error_prone_annotations:2.36.0'"
        dep2 = "    implementation 'com.google.code.findbugs:jsr305:3.0.2'"
        block = f'\ndependencies {{\n{dep1}\n{dep2}\n}}\n'

    if 'com.google.errorprone:error_prone_annotations' not in t:
        t += block

    p.write_text(t)

for name in ('android/settings.gradle', 'android/settings.gradle.kts'):
    p = Path(name)
    if p.exists():
        t = p.read_text()
        t = re.sub(r'(id\s+["\']com\.android\.application["\']\s+version\s+)["\'][^"\']+["\']', r'\1"8.6.0"', t)
        t = re.sub(r'(id\s+["\']org\.jetbrains\.kotlin\.android["\']\s+version\s+)["\'][^"\']+["\']', r'\1"1.9.24"', t)
        p.write_text(t)

p = Path('android/build.gradle')
if p.exists():
    t = p.read_text()
    t = re.sub(r"ext\.kotlin_version\s*=\s*['\"][^'\"]+['\"]", "ext.kotlin_version = '1.9.24'", t)
    p.write_text(t)
PYEOF

python3 - <<'PYEOF'
import re
from pathlib import Path

p = Path('android/gradle/wrapper/gradle-wrapper.properties')
if p.exists():
    t = p.read_text()
    t = re.sub(r'distributionUrl=.*', 'distributionUrl=https\\\\://services.gradle.org/distributions/gradle-8.9-all.zip', t)
    p.write_text(t)
PYEOF
