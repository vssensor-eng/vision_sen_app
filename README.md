# VisionSen Mobil — v1.6.1

VisionSen Mobil, **Ortam İzleme 2.5.81 + Mobil API** ile çalışır. ESP32 OIM3 cihaz yapılandırması yalnız login sonrasında **Yapılandır** sekmesinden ve cihazın geçici yerel Wi-Fi ağı üzerinden yapılır.

## v1.6.1 — Uygulama içi Wi-Fi provisioning
- ESP32 yapılandırma taşıması BLE/NimBLE yerine **Wi-Fi SoftAP Provisioning Protocol v2** kullanır.
- Cihaz kurulum sırasında `VISIONSEN-OIM3-XXXX` isimli WPA2 ağı açar; mobil uygulama cihazı `http://192.168.4.1` adresindeki yerel API üzerinden yapılandırır.
- Mobil uygulamada Bluetooth tarama, bonding, GATT ve MTU/chunk yönetimi yoktur.
- Android 10+ cihazlarda `WifiNetworkSpecifier` ile VisionSen ağı uygulamadan çıkmadan seçilir; sistem Wi-Fi Ayarları ekranı açılmaz.
- Android 13+ için `NEARBY_WIFI_DEVICES`, Android 10-12 için yalnız provisioning sırasında `ACCESS_FINE_LOCATION` çalışma zamanı izni kullanılır.
- Uygulama process’i ESP ağına global olarak bind edilmez. Yalnız `192.168.4.1` yerel provisioning istekleri Android `Network.openConnection()` üzerinden cihaz ağına yönlendirilir; VSİAS cloud/login trafiği normal internet bağlantısında kalır.
- Kurulum alanları: hedef SSID/şifre, cihaz adı, seri numarası, HTTPS sunucu URL, firma anahtarı ve 1/5/15 dakika gönderim aralığı.
- Daha önce yapılandırılmış cihazlarda mevcut firma anahtarı yeniden doğrulanır; firma anahtarı isteğe bağlı değiştirilebilir.
- Mobil sürüm: **1.6.1+19**. Uyumlu OIM3 firmware: **v2.1.3 / Provisioning Protocol v2**.

## Alt navigasyon
- Ana — sistem sağlığı, bina/oda/cihaz/sensör/alarm sayıları, son alarmlar, çevrimdışı cihazlar ve hızlı erişim
- Detay — bina/kat/oda/dolap seçimi, canlı sensör kartları, grafikler, alarmlar ve cihazlar
- Binalar — bina/kat/oda/dolap ekleme, düzenleme ve silme
- Cihazlar — cihaz ekleme, düzenleme, silme ve sensör yönetimi
- Yapılandır — OIM3 Wi-Fi SoftAP provisioning
- Profil — hesap/firma bilgileri ve çıkış

## OIM3 Wi-Fi kurulum akışı
1. ESP32 cihazı kapatıp açın.
2. Uygulamadaki **Cihaza Bağlan** düğmesine dokunun.
3. Android sistem bağlantı penceresinde `VISIONSEN-OIM3-XXXX` ağını seçip onaylayın. Uygulama Wi-Fi Ayarları ekranına geçmez.
4. Uygulama `/api/info` isteğini yalnız seçilen local-only network üzerinden gönderir ve cihaz bilgilerini doğrular.
5. Yapılandırma alanlarını doldurup cihaza kaydedin. `/api/config` isteği de yalnız cihaz network’ü üzerinden gider.
6. `SAVED` alındığında ESP bağlantısı otomatik bırakılır; cihaz yeniden başlar ve normal Wi-Fi/telemetri moduna geçer.
7. Provisioning aktifken geri tuşuna basılırsa ilk geri basışı uygulamayı kapatmaz; önce cihaz bağlantısını sonlandırır. Yapılandır sekmesinden başka sekmeye geçildiğinde de bağlantı otomatik bırakılır.

## Yönetim
Firma yöneticisi mobil uygulamadan bina, kat, oda, dolap, cihaz ve sensör oluşturabilir/düzenleyebilir/silebilir. Sensörler veri modelinde **cihaza bağlıdır**; cihaz oda veya dolaba atanır. İzleme personeli salt okunur erişim kullanır.

## Grafik
Sensöre dokunulduğunda 1 saat, 6 saat, 24 saat, 7 gün, 30 gün ve 90 gün aralıkları açılır. Grafik X ekseninde zamanı, Y ekseninde sensör birimini gösterir. Güncel, minimum ve maksimum ayrı gösterilir.

## Web API
`https://www.vsias.com/wp-json/oim/v1/mobile/*`

Mobil CRUD uçları yalnız HTTPS + geçerli Bearer token + manager rolünde çalışır. OIM3 provisioning API ise yalnız cihazın geçici yerel SoftAP ağı içindeki `192.168.4.1` adresinde HTTP kullanır; bulut/sunucu URL doğrulaması HTTPS zorunludur.

## Android build
Kaynak pakette Android platformunu üretmek ve local-only provisioning köprüsünü kurmak için `bash tool/bootstrap_android_localonly.sh` çalıştırın. Bu script önce standart Android bootstrap'ını oluşturur, ardından `WifiNetworkSpecifier` ve cihaz ağına özel `Network.openConnection()` köprüsünü uygular.
