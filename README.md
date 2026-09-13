# VisionSen Mobil — v1.6.4

VisionSen Mobil, **Ortam İzleme 2.5.81 + Mobil API** ile çalışır. ESP32 OIM3 cihaz yapılandırması yalnız login sonrasında **Yapılandır** sekmesinden ve cihazın geçici yerel Wi-Fi ağı üzerinden yapılır.

## v1.6.4 — Konum izinsiz ve sağlamlaştırılmış Wi-Fi provisioning
- ESP32 yapılandırma taşıması BLE/NimBLE yerine **Wi-Fi SoftAP Provisioning Protocol v2** kullanır.
- Cihaz kurulum sırasında `VISIONSEN-OIM3-XXXX` isimli WPA2 ağı açar; mobil uygulama cihazı `http://192.168.4.1` adresindeki yerel API üzerinden yapılandırır.
- `ACCESS_FINE_LOCATION` ve `ACCESS_COARSE_LOCATION` kullanılmaz ve manifestte tanımlı değildir.
- `WifiManager.startScan()` / `getScanResults()` kullanılmaz.
- VisionSen cihaz seçimi Android `CompanionDeviceManager` + `WifiDeviceFilter` üzerinden yapılır.
- Companion association provisioning tamamlanana veya bağlantı iptal edilene kadar korunur; cihaz seçilir seçilmez silinmez.
- Android 13+ için `NEARBY_WIFI_DEVICES` manifestte `neverForLocation` ile tanımlıdır. Bu fiziksel konum izni değildir.
- İzin diyaloğu sonrasında yalnız callback sonucu değil, gerçek paket permission state yeniden okunur.
- Seçilen cihaz `WifiNetworkSpecifier` ile local-only olarak bağlanır; bağlantı ancak telefon `192.168.4.x` DHCP adresi aldıktan sonra başarılı sayılır.
- `/api/info` ve `/api/config` yalnız cihazın seçilen Android `Network` nesnesi üzerinden `192.168.4.1` adresine gider; cloud/login trafiği normal internet bağlantısında kalır.
- Uygulama arka plana geçtiğinde, sekmeden çıkıldığında, logout yapıldığında veya Activity kapandığında provisioning request ve companion association temizlenir.
- Android 12L ve daha eski sürümlerde bazı Wi-Fi bağlantı API'leri işletim sistemi tarafından konum iznine bağlı olabilir. VisionSen konum izni istemediği için bu durumda uygulama yanlış “yakındaki cihaz izni yok” mesajı vermez; işletim sistemi kısıtını açıkça bildirir.
- Mobil sürüm: **1.6.4+22**. Uyumlu OIM3 firmware: **v2.1.3 / Provisioning Protocol v2**.

## Oturum
- Başarılı giriş tokenı `FlutterSecureStorage` içinde korunur.
- Uygulama kapatılıp açıldığında geçerli token ile oturum geri yüklenir.
- Geçici internet/DNS hatası tokenı silmez; token yalnız sunucu açıkça `401` döndürürse veya kullanıcı **Çıkış Yap** seçerse temizlenir.
- Son başarılı kullanıcı adı hatırlanır; parola cihazda kalıcı olarak saklanmaz.

## OIM3 Wi-Fi kurulum akışı
1. ESP32 cihazı kapatıp açın.
2. Uygulamadaki **Cihazları Bul** düğmesine dokunun.
3. Android cihaz seçim ekranında `VISIONSEN-OIM3-*` cihazınızı seçin. Uygulama konum izni istemez.
4. Android 13+ gerekiyorsa yalnız **Yakındaki Wi-Fi cihazları** iznini gösterir; izin verildikten sonra uygulama gerçek permission state'i tekrar doğrular.
5. Seçim sonrası cihaz bağlantısı otomatik başlar.
6. Telefon `192.168.4.x` adresi aldıktan sonra uygulama `/api/info` isteğini local-only network üzerinden gönderir.
7. Yapılandırma alanlarını doldurup cihaza kaydedin. `/api/config` isteği de yalnız cihaz network’ü üzerinden gider.
8. `SAVED` alındığında ESP bağlantısı otomatik bırakılır; cihaz yeniden başlar ve normal Wi-Fi/telemetri moduna geçer.

## Alt navigasyon
- Ana — sistem sağlığı, bina/oda/cihaz/sensör/alarm sayıları, son alarmlar, çevrimdışı cihazlar ve hızlı erişim
- Detay — bina/kat/oda/dolap seçimi, canlı sensör kartları, grafikler, alarmlar ve cihazlar
- Binalar — bina/kat/oda/dolap ekleme, düzenleme ve silme
- Cihazlar — cihaz ekleme, düzenleme, silme ve sensör yönetimi
- Yapılandır — OIM3 Wi-Fi SoftAP provisioning
- Profil — hesap/firma bilgileri ve çıkış

## Yönetim
Firma yöneticisi mobil uygulamadan bina, kat, oda, dolap, cihaz ve sensör oluşturabilir/düzenleyebilir/silebilir. Sensörler veri modelinde **cihaza bağlıdır**; cihaz oda veya dolaba atanır. İzleme personeli salt okunur erişim kullanır.

## Grafik
Sensöre dokunulduğunda 1 saat, 6 saat, 24 saat, 7 gün, 30 gün ve 90 gün aralıkları açılır. Grafik X ekseninde zamanı, Y ekseninde sensör birimini gösterir. Güncel, minimum ve maksimum ayrı gösterilir.

## Web API
`https://www.vsias.com/wp-json/oim/v1/mobile/*`

Mobil CRUD uçları yalnız HTTPS + geçerli Bearer token + manager rolünde çalışır. OIM3 provisioning API ise yalnız cihazın geçici yerel SoftAP ağı içindeki `192.168.4.1` adresinde HTTP kullanır; bulut/sunucu URL doğrulaması HTTPS zorunludur.

## Android build
Kaynak pakette Android platformunu üretmek ve v1.6.4 provisioning köprüsünü kurmak için:

```bash
bash tool/bootstrap_android_v164.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
