# VisionSen Factory PC Tool v0.6.5

- UI iki ana akışa ayrıldı: ÜRETİM ve SERVİS.
- COM seçimi, Yenile, Bağlan ve Bağlantıyı Kes ortak üst alanda korunur.
- Üretim adımları sıralı kilitlenir: Firmware -> Kimlik/Donanım -> Test -> QR.
- Servis adımları sıralı kilitlenir: Cihazı Oku -> Servis Güncellemesi (değişiklik varsa) -> Test -> QR.
- Serviste sensör seti değişirse manifest/donanım revizyonu otomatik artırılır.
- Firmware servisi isteğe bağlıdır ve cihaz okunduktan sonra etkinleşir.
- Teknik log varsayılan kapalı/açılır yapıdadır.
- OIM3 2.2.1 exact-SHA firmware zinciri ve VS-OIM3-STRICT-1 sözleşmesi korunur.
- Fiziksel donanım seçimleri model bazlı gösterilir: SHT45 -> Sıcaklık/Nem/Çiğ Noktası, Battery ADC -> Batarya Gerilimi.
- PT1000 katalog yapısına eklendi; firmware 2.2.1 sürücüsü olmadığı için yanlışlıkla seçilemez. Gelecekte PT1000 etkinleştiğinde yalnız Sıcaklık kanalı üretir.
- Manifest iç anahtarları teknik uyumluluk için değişmeden kalır; operatör özetleri fiziksel sensör model adlarını gösterir.
- Test ekranındaki Çiğ Noktası anahtarı düzeltildi.
