# VisionSen Factory PC Tool v0.6.7

- Bağlantı/auto-read sırasında geçici boş manifest seçimi artık GUI exception veya popup üretmez.
- `_service_hardware_changed()` manifest UI senkronizasyonu ve henüz yüklenmemiş manifest durumunda fail-safe çalışır.
- Servis manifest özeti cihaz okunurken "Cihaz donanım bilgisi okunuyor..." durumunu gösterir.
- Cihaz Bağlantısı alanı iki işlevsel satıra ayrıldı: üstte yalnız COM kontrolleri; altta progress bar/yüzde ve ayrı durum satırı.
- Uzun COM/ESP32 doğrulama durum metni artık Yenile/Bağlan/Bağlantıyı Kes butonlarının üzerine binmez.
- PT1000 yok; SHT45 ve Battery ADC fiziksel sensör modeli korunur.
- Manifest revizyonu üretimde v1, serviste fiziksel sensör değişiminde otomatik v+1 davranışını korur.
- OIM3 2.2.1 onaylı firmware seti değişmedi.
