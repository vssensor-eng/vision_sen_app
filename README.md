# VisionSen Mobil — v1.3.1

Bu sürüm mevcut BLE cihaz yapılandırma akışını korur ve uygulamayı **Ortam İzleme 2.5.48 no-cron + Mobil API** sürümüyle uyumlu hale getirir. Kullanıcı önce Ortam İzleme hesabıyla giriş yapar; başarılı girişten sonra izleme ve cihaz yapılandırma modülleri açılır.

## Ana navigasyon
- Ana Sayfa — firma/bina/oda/cihaz/sensör özeti
- Binalar — web panelinde oluşturulmuş bina ve odalar
- Cihazlar — web hesabındaki cihazlar, canlı durum ve yetkili kullanıcıda yeni cihaz ekleme
- Yapılandır — mevcut BLE kurulum akışı; Bluetooth yalnız `BAŞLAYALIM` denince kontrol edilir
- Profil — hesap/firma bilgileri ve çıkış

## Web entegrasyonu
Mobil uygulama `https://www.vsias.com/wp-json/oim/v1/mobile/*` endpointlerini kullanır. Web tarafında Ortam İzleme 2.5.48 no-cron + Mobil API sürümü kurulu olmalıdır.

Oturum tokenı `flutter_secure_storage` içinde tutulur. BLE ekranlarına login olmadan rota açılmaz; ana uygulama yalnız doğrulanmış mobil oturumdan sonra oluşturulur.

## 2.5.48 uyumu
- Sensör adları ve birimleri web tarafındaki `metrics` kataloğundan dinamik alınır.
- Yeni cihaz ekranındaki sensör seçenekleri web kataloğundan üretilir; `selectable=false` kayıtlar gösterilmez.
- History ekranı 1 saat, 6 saat, 24 saat, 7 gün, 30 gün ve 90 gün aralıklarını destekler.
- Cihaz ekleme yalnız firma yöneticisi rolünde gösterilir ve sunucu tarafında da ayrıca doğrulanır.
- Web tarafındaki WP-Cron/harici cron bağımsız 2.5.47+ bakım modeli değiştirilmez.

## BLE akışı
Mevcut BLE servis UUID'leri, cihaz tarama, doğrulama, Wi-Fi, cihaz anahtarı, sunucu, özet ve kurulum ekranları değiştirilmemiştir. Bluetooth kontrolü uygulama açılışında değil, login sonrasında `Yapılandır > BAŞLAYALIM` ile başlar.

## Bağımlılıklar
- flutter_blue_plus
- permission_handler
- http
- flutter_secure_storage

## Çalıştırma
```bash
bash tool/bootstrap_android.sh
flutter pub get
flutter analyze
flutter test
flutter run
```
