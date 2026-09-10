# VisionSen Mobil — v1.4.0

VisionSen Mobil, **Ortam İzleme 2.5.50 no-cron + Mobil API** ile çalışır. Mevcut BLE cihaz yapılandırma akışı değiştirilmemiştir; BLE yalnız login sonrasında **Yapılandır > BAŞLAYALIM** ile açılır.

## Alt navigasyon
- Ana — bina/oda/cihaz/sensör/alarm sayıları ve sistem özeti
- Detay — web panelindeki Detay Görünüm mantığı: bina/oda/dolap seçimi, canlı sensör kartları, ikonlar, 24 saat trend, alarmlar ve cihazlar
- Binalar — bina/oda/dolap ekleme, düzenleme ve silme
- Cihazlar — cihaz ekleme, düzenleme, silme ve sensör yönetimi
- Yapılandır — mevcut BLE provisioning akışı
- Profil — hesap/firma bilgileri ve çıkış

## Yönetim
Firma yöneticisi mobil uygulamadan bina, oda, dolap, cihaz ve sensör oluşturabilir/düzenleyebilir/silebilir. Sensörler veri modelinde **cihaza bağlıdır**; cihaz oda veya dolaba atanır. İzleme personeli salt okunur erişim kullanır.

## Grafik
Sensöre dokunulduğunda 1 saat, 6 saat, 24 saat, 7 gün, 30 gün ve 90 gün aralıkları açılır. Grafik X ekseninde zamanı, Y ekseninde sensör birimini gösterir. Güncel, minimum ve maksimum ayrı gösterilir; ortalama kartı yoktur.

## Web API
`https://www.vsias.com/wp-json/oim/v1/mobile/*`

Mobil CRUD uçları yalnız HTTPS + geçerli Bearer token + manager rolünde çalışır. Web tarafındaki bağlı kayıt/silme güvenlik kuralları aynen korunur. WP-Cron veya harici cron bağımlılığı yoktur.
