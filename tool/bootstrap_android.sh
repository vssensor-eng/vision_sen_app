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

# VisionSen BLE taraması konum amacıyla kullanılmaz. Eski paketlerde kalmış
# olabilecek konum izinlerini de temizliyoruz; uygulama konum izni istemez.
content = re.sub(r'\s*<uses-permission[^>]+android:name="android\.permission\.ACCESS_(?:FINE|COARSE)_LOCATION"[^>]*/>\s*', '\n', content)

perms = '''    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
'''

for permission in [
    'android.permission.BLUETOOTH',
    'android.permission.BLUETOOTH_ADMIN',
    'android.permission.BLUETOOTH_SCAN',
    'android.permission.BLUETOOTH_CONNECT',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.INTERNET',
    'android.permission.ACCESS_WIFI_STATE',
    'android.permission.CHANGE_WIFI_STATE',
]:
    content = re.sub(
        r'\s*<uses-permission[^>]+android:name="' + re.escape(permission) + r'"[^>]*/>\s*',
        '\n',
        content,
    )

content = re.sub(r'(<manifest[^>]*>)', r'\1\n' + perms, content, count=1)
open(path, 'w', encoding='utf-8').write(content)
PYEOF

# Android yerel bildirim köprüsü. Yeni alarm yakalandığında Flutter bu MethodChannel
# üzerinden yüksek öncelikli, sesli sistem bildirimi üretir.
MAIN_ACTIVITY="android/app/src/main/kotlin/com/visionsen/visionsen_setup/MainActivity.kt"
mkdir -p "$(dirname "$MAIN_ACTIVITY")"
cat > "$MAIN_ACTIVITY" <<'KOTLIN'
package com.visionsen.visionsen_setup

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.visionsen/alarm_notifications"
        private const val NOTIFICATION_CHANNEL = "visionsen_alarm_channel"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createAlarmChannel()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1001
                    val title = call.argument<String>("title") ?: "VisionSen Alarmı"
                    val body = call.argument<String>("body") ?: "Yeni bir alarm oluştu."
                    showAlarmNotification(id, title, body)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createAlarmChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val audio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .build()
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL,
            "VisionSen Alarmları",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "VisionSen sensör ve cihaz alarm bildirimleri"
            enableVibration(true)
            setSound(sound, audio)
        }
        manager.createNotificationChannel(channel)
    }

    private fun showAlarmNotification(id: Int, title: String, body: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL)
        } else {
            Notification.Builder(this)
                .setPriority(Notification.PRIORITY_MAX)
                .setSound(sound)
        }

        builder
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)

        if (pendingIntent != null) builder.setContentIntent(pendingIntent)

        manager.notify(id, builder.build())
    }
}
KOTLIN

echo "Android platform dosyaları hazır. Konum izni kaldırıldı, alarm bildirimi etkin."

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
