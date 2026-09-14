# VisionSen Factory PC Tool v0.2.0 – Windows Masaüstü

Windows için tek EXE masaüstü üretim/kalite kontrol uygulaması.

## Özellikler
- COM port seçimi ve otomatik listeleme
- ESP-IDF ile firmware build + flash veya yalnız flash
- Factory Identity schema v2 yazma/güncelleme
- Seri no, HW revision ve üretim tarihi yönetimi
- Cihaza özel 16-32 karakter provisioning secret üretme/kopyalama
- Identity re-issue sırasında yalnız storage/queue temizliği
- ESP v2.1.6 `VSFACT1` üretim self-test satırını okuma
- SHT45, sıcaklık, nem, çiy noktası, battery durumu ve charge GPIO gösterimi
- PASS / FAIL / BATTERY WARNING sonucu
- Üretim kayıtlarını CSV’ye yazma

## Çalıştırma
`VisionSen-Factory-PC-Tool-v0.2.0.exe` doğrudan çalışır; Python kurulumu gerekmez.

Firmware build/flash ve Factory Identity yazma işlemleri için bilgisayarda ESP-IDF v6.1 kurulu olmalıdır. Varsayılan yollar Ayarlar ekranından değiştirilebilir.

## Güvenlik
Uygulamada full-flash erase bulunmaz. Provisioning secret üretim kaydıdır; firmware `/api/info` üzerinden bu değeri geri vermez.
