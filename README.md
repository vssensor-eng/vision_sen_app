# VisionSen Mobil — v1.3.0

Bu sürüm mevcut BLE cihaz yapılandırma akışını korur ancak **login zorunlu** hale getirir. Uygulama açıldığında kullanıcı önce Ortam İzleme hesabıyla giriş yapar; başarılı girişten sonra izleme ve cihaz yapılandırma modülleri açılır.

## Ana navigasyon
- Ana Sayfa — firma/bina/oda/cihaz/sensör özeti
- Binalar — web panelinde oluşturulmuş bina ve odalar
- Cihazlar — web hesabındaki cihazlar, canlı durum ve yeni cihaz ekleme
- Yapılandır — mevcut BLE kurulum akışı; Bluetooth yalnız `BAŞLAYALIM` denince kontrol edilir
- Profil — hesap/firma bilgileri ve çıkış

## Web entegrasyonu
Mobil uygulama `https://www.vsias.com/wp-json/oim/v1/mobile/*` endpointlerini kullanır. Farklı kurulumda `lib/config_app.dart` içindeki `mobileApiBase` değerini değiştirin.

Oturum tokenı `flutter_secure_storage` içinde tutulur. BLE ekranlarına login olmadan rota açılmaz; ana uygulama yalnız doğrulanmış mobil oturumdan sonra oluşturulur.

## Cihaz ekleme
`Cihazlar > +` üzerinden web panelinde bulunmayan cihaz eklenebilir. Kullanıcı oda/dolap, seri numarası ve sensör türlerini seçer. Varsayılan sensörler sıcaklık, nem ve çiğ noktasıdır.

## BLE akışı
Mevcut BLE servis UUID'leri, cihaz tarama, doğrulama, Wi-Fi, cihaz anahtarı, sunucu, özet ve kurulum ekranları değiştirilmemiştir. Değişen tek erişim davranışı: Bluetooth kontrolü uygulama açılışında değil, login sonrasında `Yapılandır > BAŞLAYALIM` ile başlar.

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
