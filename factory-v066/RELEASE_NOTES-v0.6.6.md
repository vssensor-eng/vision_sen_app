# VisionSen Factory PC Tool v0.6.6

- Üretim / Servis tab yapısı ve işlem sıralı buton kapıları korunur.
- COM Port seçimi, Yenile, Bağlan ve Bağlantıyı Kes ortak üst alanda korunur.
- Yüzde ilerleme çubuğu Üretim firmware alanından alınarak ortak Cihaz Bağlantısı alanına taşındı; Servis dahil tüm işlemlerde görünür.
- Bağlan sırasında ESP32 doğrulama ve otomatik kimlik okuma durumu üst bağlantı alanında görünür.
- Geçici sensörsüz UI durumu artık beklenmeyen uygulama hatası üretmez; strict "en az bir fiziksel sensör" doğrulaması yalnız yazma/QR gibi gerçek işlem kapılarında uygulanır.
- Sensör seçimi boşsa Kimlik + Donanım Yaz / Servis Güncellemesini Yaz gibi kritik butonlar fail-closed kilitli kalır.
- PT1000 örnek/gösterim girdileri tamamen kaldırıldı; mevcut firmware 2.2.1 sensör sözleşmesi yalnız SHT45 ve Battery ADC olarak kalır.
- SHT45 operatör ekranında fiziksel model olarak kalır; alt açıklama Sıcaklık / Nem / Çiğ Noktasıdır.
- Yeni cihaz varsayılanı SHT45'tir; Battery ADC yalnız fiziksel kartta varsa operatör tarafından seçilir.
- Manifest revizyonu normal operatör akışında elle artırılmaz: yeni cihaz v1, mevcut cihazda sensör seti değişince servis akışı otomatik v+1 yapar.
- Üretim > Cihaz Kimliği girişleri tek satıra alındı; Yeni Kod, Kopyala, Cihazdan Oku, Kimlik + Donanım Yaz butonları alt satırda sağa hizalıdır.
- Teknik Log her zaman açık, başlangıçta daha yüksek ve ana pencere köşeden büyütüldükçe genişleyip yükselir; göster/gizle butonu kaldırıldı.
- Test sonucu alanındaki Sensör anahtar uyumsuzluğu düzeltildi.
- Serviste başarılı otomatik bağlantı/kimlik okuması sonrası servis akışı otomatik hazır duruma geçer; Cihazı Oku butonu manuel yenileme için kalır.
- Gömülü onaylı firmware değişmedi: OIM3 2.2.1 exact-SHA seti kullanılır.
