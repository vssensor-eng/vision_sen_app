# VISION­SEN Device Setup — Flutter Frontend

Koyu VISION­SEN tasarımı, form ekranları, doğrulama, özet, güvenli ayar gönderimi ve tamamlandı akışının yanı sıra
`lib/services/ble_service.dart` içinde **gerçek** BLE kurulum istemcisi bulunur. Bu, `VS-ESP-BLE`
ESP32 firmware'inin (v1.2.6+) BLE kurulum modülüyle (BLE_SERVICE_UUID / BLE_CONFIG_CHAR_UUID /
BLE_STATUS_CHAR_UUID / BLE_INFO_CHAR_UUID) birebir eşleşecek şekilde yazılmıştır.

## Firmware ile eşleşme
- Cihaz gerçek enerji verilişinden sonra **60 saniye** `VISIONSEN-ESP-XXXX` adıyla BLE yayını yapar. Normal deep-sleep/timer ölçüm uyanışlarında BLE açılmaz. Yapılandırılmamış cihaz, kurulum tamamlanana kadar 60 saniyelik pencereleri yeniden açar. Tarama paketindeki durum biti gerçek `configured` bilgisini gösterir.
- INFO ve CONFIG erişimi BLE bonding + şifreli GATT üzerinden yapılır. Ayarlar CONFIG karakteristiğine parça parça (chunk) JSON olarak yazılır; cihaz STATUS karakteristiğinden `SAVED` veya `ERROR:<KOD>` bildirimi döner.
- Daha önce kurulmuş cihazın 60 saniyelik güç-açılış penceresinde ayar değişikliği yalnızca cihazda kayıtlı **mevcut firma anahtarı** eşleşirse kabul edilir. Fiziksel düğme kullanılmaz. Firma anahtarı **6-128 karakter** olmalıdır. Kurulu cihazda mevcut anahtar yetkilendirme için girilir; "Firma anahtarını değiştir" seçeneği kapalıysa aynı anahtar korunur, açıkken ayrıca yeni anahtar istenir.
- INFO karakteristiği `{"device_type","protocol_version","serial","fw","mac","configured"}` alanlarını içeren bir JSON döner.
- Uygulama uyumluluğu **firmware sürümüne göre değil**, `device_type + protocol_version` ikilisine göre belirler. `fw` yalnızca ekranda bilgi amaçlı gösterilir. Desteklenmeyen protokol veya cihaz tipi yapılandırılmaz.
- **Geriye dönük uyumluluk yoktur.** `device_type` veya `protocol_version` alanlarından biri eksikse uygulama kurulumu durdurur. Bu nedenle v1.2.2 ve önceki kimlik şemasına sahip firmware sürümleri desteklenmez.
- Sunucu adresi hem `http://` hem `https://` olabilir; şema firmware tarafında adresin
  önekinden çalışma anında belirlenir.

## Akış
1. Ana ekran
2. BLE cihaz tarama
3. Cihaz seçme
4. Cihaz doğrulama
5. Wi-Fi bilgileri
6. Cihaz bilgileri
7. Sunucu bilgileri
8. Ayar özeti
9. Ayarların cihaza gönderilmesi ve `SAVED` yanıtının beklenmesi
10. Tamamlandı (Wi-Fi/sunucu erişimi yönetim panelinden doğrulanır)

## Çalıştırma

```bash
flutter pub get
flutter run
```

BLE için Android'de konum/Bluetooth çalışma-anı izinleri istenir (`permission_handler`).
Cihaz bulunamıyorsa enerji verildikten sonraki 60 saniyelik BLE penceresinin açık olduğundan
ve telefonun cihazın yakınında olduğundan emin olun.

## CI / Android release signing

Workflow `flutter analyze` ve `flutter test` çalıştırır. Doğrudan bağımlılık sürümleri
`pubspec.yaml` içinde sabitlenmiştir. Kalıcı production imzası için GitHub repository
secrets altında şu dört değer tanımlanmalıdır:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

Bu secrets yoksa workflow yalnızca CI amaçlı APK üretir; onu production güncelleme
imzası olarak kullanmayın. Secrets varsa aynı anahtarla imzalanmış APK ve AAB üretilir.

## Yerel Android derleme

Kaynak paket `android/` klasörünü taşımak yerine Flutter 3.24.0 ile aynı platform
iskeletini üretir. İlk yerel derlemede proje kökünde:

```bash
bash tool/bootstrap_android.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Doğrudan bağımlılıklar `pubspec.yaml` içinde tam sürüme sabitlenmiştir. CI da aynı
Flutter 3.24.0 sürümünü kullanır.
