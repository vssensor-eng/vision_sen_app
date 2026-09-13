# VisionSen Mobil — v1.6.6

VisionSen Mobil, **Ortam İzleme 2.5.81 + Mobil API** ile çalışır. ESP32 OIM3 cihaz yapılandırması yalnız login sonrasında **Yapılandır** sekmesinden ve cihazın geçici yerel Wi-Fi ağı üzerinden yapılır.

## v1.6.6 — üretici seri kimliği + konum izinsiz Wi-Fi provisioning

- Uyumlu ESP firmware: **OIM3 v2.1.4 / Provisioning Protocol v2**.
- Ürün seri numarası müşteri ayarı değildir. Firmware seri kimliğini yalnız üreticiye ait `factory_data` bölümünden okur.
- Kurulum SSID formatı: `VISIONSEN-OIM3-{SERIAL}`. Örnek: `VISIONSEN-OIM3-ESP-000001`.
- Mobil uygulamada seri numarası giriş alanı yoktur; seri yalnız `/api/info` üzerinden salt-okunur gösterilir.
- Uygulama yalnız `serial_locked=true` ve `identity_source=factory_data` bildiren cihazı kabul eder.
- `/api/config` isteğinde `serial` gönderilmez.
- Test aşamasındaki ürün için legacy seri/config migration yolu yoktur.

## Android Wi-Fi bağlantısı

- ESP32 yapılandırma taşıması BLE/NimBLE yerine **Wi-Fi SoftAP Provisioning Protocol v2** kullanır.
- `ACCESS_FINE_LOCATION` ve `ACCESS_COARSE_LOCATION` kullanılmaz ve manifestte tanımlı değildir.
- `WifiManager.startScan()` / `getScanResults()` kullanılmaz.
- VisionSen cihaz seçimi Android `CompanionDeviceManager` + `WifiDeviceFilter` üzerinden yapılır.
- Android 13+ için `NEARBY_WIFI_DEVICES` manifestte `neverForLocation` ile tanımlıdır.
- `CHANGE_NETWORK_STATE`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` ve `CHANGE_WIFI_STATE` bağlantı yönetimi için kullanılır; `WRITE_SETTINGS` kullanılmaz.
- Seçilen cihaz `WifiNetworkSpecifier` ile local-only olarak bağlanır; bağlantı telefon `192.168.4.x` DHCP adresi aldıktan sonra başarılı sayılır.
- `/api/info` ve `/api/config` yalnız cihazın seçilen Android `Network` nesnesi üzerinden `192.168.4.1` adresine gider; cloud/login trafiği normal internet bağlantısında kalır.
- Uygulama arka plana geçtiğinde, sekmeden çıkıldığında, logout yapıldığında veya Activity kapandığında provisioning request ve companion association temizlenir.

## Oturum

- Başarılı giriş tokenı `FlutterSecureStorage` içinde korunur.
- Uygulama kapatılıp açıldığında geçerli token ile oturum geri yüklenir.
- Geçici internet/DNS hatası tokenı silmez; token yalnız sunucu açıkça `401` döndürürse veya kullanıcı **Çıkış Yap** seçerse temizlenir.
- Son başarılı kullanıcı adı hatırlanır; parola cihazda kalıcı olarak saklanmaz.

## OIM3 Wi-Fi kurulum akışı

1. Üretici cihazın `factory_data` alanına seri numarasını yazar.
2. ESP32 cihazı kapatıp açın.
3. Uygulamadaki **Cihazları Bul** düğmesine dokunun.
4. Android seçim ekranında `VISIONSEN-OIM3-ESP-...` cihazınızı seçin.
5. Android 13+ gerekiyorsa yalnız **Yakındaki Wi-Fi cihazları** iznini gösterir.
6. Telefon `192.168.4.x` adresi aldıktan sonra uygulama `/api/info` isteğini gönderir.
7. Uygulama factory serial kimliğini doğrular ve seri numarasını yalnız gösterir.
8. Wi-Fi, sunucu, cihaz adı, gönderim aralığı ve firma anahtarını kaydedin.
9. `SAVED` alındığında ESP bağlantısı bırakılır; cihaz yeniden başlar ve normal Wi-Fi/telemetri moduna geçer.

## Android build

```bash
bash tool/bootstrap_android_v166.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Mobil sürüm: **1.6.6+24**.
