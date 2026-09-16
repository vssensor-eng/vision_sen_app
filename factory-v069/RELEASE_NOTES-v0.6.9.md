# VisionSen Factory PC Tool v0.6.9

## Operatör arayüzü
- Teknik Log alt panelden sağ tarafta sürekli görünür panele taşındı.
- Sol Üretim/Servis alanı ile sağ Teknik Log arasında sürüklenebilir dikey ayırıcı eklendi.
- Başlangıç yerleşimi yaklaşık %68 iş akışı / %32 log olarak ayarlandı.
- Üretim ve Servis sekmelerinin mevcut bağımsız dikey kaydırması korunur.
- Teknik Log kendi dikey ve yatay kaydırma çubuklarına sahiptir ve hiçbir zaman gizlenmez.
- Teknik Log araçları: Temizle, Kopyala, Kaydet, Otomatik Kaydır.
- Otomatik Kaydır kapatıldığında operatör geçmiş log satırlarını incelerken ekran zorla alta dönmez.
- Pencere varsayılan genişliği sağ log takibine uygun olarak artırıldı; minimum genişlikte de paneller sürüklenebilir.

## Üretim / servis davranışı
- v0.6.8'deki ayrı Kimliği Cihaza Yaz / Donanımı Cihaza Yaz akışı korunur.
- Servis factory_data doğrudan flash okuma, otomatik donanım revizyonu, manifest doğrulama ve QR test kapıları değişmeden korunur.
- Firmware OIM3 v2.2.1 exact-SHA seti değişmemiştir.
- Sistem sözleşmesi VS-OIM3-STRICT-1 değişmemiştir.
