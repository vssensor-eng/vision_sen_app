# VisionSen Factory PC Tool v0.6.8

- Üretim akışı `Yazılım -> Kimlik -> Fiziksel Donanım -> Test -> QR` olarak ayrıldı.
- Üretimde `Kimliği Cihaza Yaz` ve `Donanımı Cihaza Yaz` ayrı, sıralı işlemler oldu; `Cihazdan Oku` kaldırıldı.
- Yeni üretimde donanım revizyonu v1 otomatik tutulur; servis sensör değişiminde mevcut revizyon otomatik +1 yapılır.
- Servis `Cihazı Oku` artık `factory_data` (0x12000/0x6000) bölümünü doğrudan okuyup NVS kimlik ve donanım kaydını doğrular.
- Servis ekranında Seri No, HW ID, Şema, HW Rev ve Üretim Tarihi ayrı alanlarda gösterilir.
- Üretim testi manifest/donanım doğrulaması, Tool'un yazma/readback sonucu ile zenginleştirilir; firmware boot logunda manifest satırı olmamasından kaynaklanan sahte FAIL giderildi.
- Test kolonları Türkçeleştirildi ve Şarj kolonu kaldırıldı.
- Yazılım/Firmware operatör metinleri Türkçeleştirildi.
- Üretim ve Servis içerikleri dikey kaydırılabilir hale getirildi.
- Teknik Log alanı büyütüldü ve sürüklenebilir dikey ayırıcı ile operatör tarafından manuel yeniden boyutlandırılabilir hale getirildi.
- QR/etiket otomatik yazma sırasında üretilmez; yalnız test PASS sonrasında operatör tarafından oluşturulur.
- OIM3 firmware 2.2.1 ve VS-OIM3-STRICT-1 sözleşmesi değişmedi.
