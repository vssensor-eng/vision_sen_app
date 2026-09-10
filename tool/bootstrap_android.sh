#!/usr/bin/env bash
set -euo pipefail

# Kaynak ZIP android/ platform klasörünü bilinçli olarak taşımıyor. Aynı Flutter
# sürümüyle deterministik Android iskeleti üretir ve gerekli BLE/ağ izinlerini ekler.
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

# flutter create tarafindan olusturulan ornek test dosyasini kaldir
rm -f test/widget_test.dart

# Toolchain: compileSdk 35, NDK 26.1, AGP ve Kotlin surumlerini yukselt.
# flutter_secure_storage/FlutterBluePlus'in Android bağımlılıkları NDK 26.1 ister.
# Tink'in R8 aşamasında referans verdiği annotation sınıflarını da release classpath'e
# ekleyerek minifyReleaseWithR8 sırasında "Missing class" hatasını engelleriz.
python3 - <<'PYEOF'
import re
from pathlib import Path

for name in ('android/app/build.gradle', 'android/app/build.gradle.kts'):
    p = Path(name)
    if not p.exists():
        continue

    t = p.read_text()
    t = re.sub(r'compileSdk\s*=?\s*[^\n]+', 'compileSdk = 35', t, count=1)

    # android { } bloğuna sabit NDK sürümünü ekle/değiştir.
    if re.search(r'ndkVersion\s*=?\s*[^\n]+', t):
        t = re.sub(r'ndkVersion\s*=?\s*[^\n]+', 'ndkVersion = "26.1.10909125"', t, count=1)
    else:
        t = re.sub(r'(android\s*\{)', r'\1\n    ndkVersion = "26.1.10909125"', t, count=1)

    # Groovy ve Kotlin DSL için R8'in ihtiyaç duyduğu yalnızca-annotation bağımlılıkları.
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

# Gradle wrapper surumunu AGP 8.6 ile uyumlu hale getir
python3 - <<'PYEOF'
import re
from pathlib import Path

p = Path('android/gradle/wrapper/gradle-wrapper.properties')
if p.exists():
    t = p.read_text()
    t = re.sub(r'distributionUrl=.*', 'distributionUrl=https\\\\://services.gradle.org/distributions/gradle-8.9-all.zip', t)
    p.write_text(t)
PYEOF
