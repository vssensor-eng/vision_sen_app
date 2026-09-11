# VisionSen Mobil — v1.4.2

VisionSen Mobil, **Ortam İzleme 2.5.50 no-cron + Mobil API** ile çalışır. BLE cihaz yapılandırma akışı yalnız login sonrasında **Yapılandır > BAŞLAYALIM** ile açılır.

## v1.4.2 düzeltmeleri
- v1.4.1'de eklenen yerel sesli Android alarm bildirimi, bildirim izni ve 20 saniyelik alarm notification watcher kaldırıldı. Alarmlar uygulamanın ekranlarında görüntülenmeye devam eder.
- Konum/harita özelliği yoktur; `ACCESS_FINE_LOCATION` ve `ACCESS_COARSE_LOCATION` kullanılmaz. BLE yalnız `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` ister.
- İlk BLE bağlantısında Android eşleştirmesi tamamlanmadan şifreli GATT okumaya geçilmez. `flutter_blue_plus` 1.35.8 kullanılır, bond durumu beklenir ve ilk encrypted INFO okuması gerektiğinde kısa aralıklarla yeniden denenir.
- Tarama listesinde Android'in önbellekte tutabildiği `platformName` yerine güncel advertisement adı önceliklidir.
- Mobil provisioning paketi artık `device_name` alanını da gönderir.
- Kalıcı özel BLE cihaz adı için **VS-ESP firmware 1.3.9+** gerekir. Firmware adı NVS'te saklar ve sonraki gerçek güç açılışındaki BLE reklamında kullanır. Eski firmware sürümleri özel adı kalıcı saklamaz.

## Alt navigasyon
- Ana — sistem sağlığı, bina/oda/cihaz/sensör/alarm sayıları, son alarmlar, çevrimdışı cihazlar ve hızlı erişim
- Detay — bina/oda/dolap seçimi, canlı sensör kartları, ikonlar, 24 saat trend, alarmlar ve cihazlar
- Binalar — bina/oda/dolap ekleme, düzenleme ve silme
- Cihazlar — cihaz ekleme, düzenleme, silme ve sensör yönetimi
- Yapılandır — BLE provisioning akışı
- Profil — hesap/firma bilgileri ve çıkış

## Yönetim
Firma yöneticisi mobil uygulamadan bina, oda, dolap, cihaz ve sensör oluşturabilir/düzenleyebilir/silebilir. Sensörler veri modelinde **cihaza bağlıdır**; cihaz oda veya dolaba atanır. İzleme personeli salt okunur erişim kullanır.

## Grafik
Sensöre dokunulduğunda 1 saat, 6 saat, 24 saat, 7 gün, 30 gün ve 90 gün aralıkları açılır. Grafik X ekseninde zamanı, Y ekseninde sensör birimini gösterir. Güncel, minimum ve maksimum ayrı gösterilir; ortalama kartı yoktur.

## Web API
`https://www.vsias.com/wp-json/oim/v1/mobile/*`

Mobil CRUD uçları yalnız HTTPS + geçerli Bearer token + manager rolünde çalışır. Web tarafındaki bağlı kayıt/silme güvenlik kuralları aynen korunur. WP-Cron veya harici cron bağımlılığı yoktur.
