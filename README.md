# VisionSen Mobil — v1.4.1

VisionSen Mobil, **Ortam İzleme 2.5.50 no-cron + Mobil API** ile çalışır. Mevcut BLE cihaz yapılandırma akışı değiştirilmemiştir; BLE yalnız login sonrasında **Yapılandır > BAŞLAYALIM** ile açılır.

## Alt navigasyon
- Ana — zengin sistem özeti: bina/oda/cihaz/sensör/alarm sayıları, sistem sağlığı, son alarmlar, çevrimdışı cihazlar ve hızlı erişim
- Detay — web panelindeki Detay Görünüm mantığı: bina/oda/dolap seçimi, canlı sensör kartları, ikonlar, 24 saat trend, alarmlar ve cihazlar
- Binalar — bina/oda/dolap ekleme, düzenleme ve silme
- Cihazlar — cihaz ekleme, düzenleme, silme ve sensör yönetimi
- Yapılandır — mevcut BLE provisioning akışı
- Profil — hesap/firma bilgileri ve çıkış

## Konum izni
Uygulama konum/harita özelliği kullanmaz. Android manifestinden `ACCESS_FINE_LOCATION` ve `ACCESS_COARSE_LOCATION` kaldırılır. BLE taraması Android 12+ tarafında `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` ve `neverForLocation` ile çalışır.

## Alarm bildirimi
Login sonrasında uygulama açık alarm listesini 20 saniyede bir kontrol eder. Yeni bir alarm ilk kez açıldığında Android sistem bildirimi oluşturulur, yüksek öncelikli alarm sesi ve titreşim kullanılır. Aynı açık alarm her sorguda tekrar çalmaz; alarm kapanıp daha sonra yeni kayıt olarak açılırsa yeniden bildirim gelir.

Android 13+ cihazlarda yalnızca **Bildirimlere izin ver** izni istenir. Konum izni istenmez.

Bu sürümde bildirim takibi uygulama süreci çalıştığı sürece REST alarm sorgusu ile yapılır. Uygulama işletim sistemi tarafından tamamen kapatıldığında/killed durumda anlık teslimat için sonraki adım FCM push entegrasyonudur; bunun için Firebase `google-services.json` ve sunucu gönderim kimlik bilgileri gerekir.

## Yönetim
Firma yöneticisi mobil uygulamadan bina, oda, dolap, cihaz ve sensör oluşturabilir/düzenleyebilir/silebilir. Sensörler veri modelinde **cihaza bağlıdır**; cihaz oda veya dolaba atanır. İzleme personeli salt okunur erişim kullanır.

## Grafik
Sensöre dokunulduğunda 1 saat, 6 saat, 24 saat, 7 gün, 30 gün ve 90 gün aralıkları açılır. Grafik X ekseninde zamanı, Y ekseninde sensör birimini gösterir. Güncel, minimum ve maksimum ayrı gösterilir; ortalama kartı yoktur.

## Web API
`https://www.vsias.com/wp-json/oim/v1/mobile/*`

Mobil CRUD uçları yalnız HTTPS + geçerli Bearer token + manager rolünde çalışır. Web tarafındaki bağlı kayıt/silme güvenlik kuralları aynen korunur. WP-Cron veya harici cron bağımlılığı yoktur.
