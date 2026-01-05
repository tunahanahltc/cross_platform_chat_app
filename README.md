# Cross Platform Chat App 💬

Bir **Matrix sunucusu** tarafından desteklenen ve **Dart** ile **Flutter** kullanılarak geliştirilmiş, WhatsApp, Telegram, Instagram, Twitter ve Bluesky gibi popüler platform ile sorunsuz gerçek zamanlı mesajlaşma sağlayan modern, çok platformlu sohbet uygulaması.

## 🌉 Matrix Bridges Entegrasyonu

Bu uygulama **Matrix Protocol** üzerinden aşağıdaki platformlarla tam entegrasyonu destekler:

- **WhatsApp** 📱 - WhatsApp Web bridge via mautrix-whatsapp
- **Telegram** ✈️ - Telegram Bot integration via mautrix-telegram
- **Instagram** 📷 - Instagram DM bridge via mautrix-instagram
- **Twitter/X** 🐦 - Twitter DM bridge via mautrix-twitter
- **Bluesky** 🦋 - Bluesky DM bridge via mautrix-bluesky

Tüm bu platformları tek bir arayüzden yönetin ve gerçek zamanlı mesajlaşma yapın! 

## Features ✨

- **Çoklu Platform Destek**: WhatsApp, Telegram, Instagram, Twitter/X, Bluesky ile sorunsuz entegrasyon
- **Gerçek Zamanlı Mesajlaşma**: Anında mesaj teslimi ve güncellemeler
- **Matrix Protokolü**: Merkezi olmayan ve açık kaynaklı iletişim altyapısı
- **Birleşik Sohbet**: Tüm platformlardan mesajları tek yerde yönetin
- **Kullanıcı Kimlik Doğrulama**: Güvenli giriş ve kayıt sistemi
- **Çevrimiçi Durum**: Kullanıcıların çevrimiçi/çevrimdışı durumunu görün
- **Mesaj Bildirimleri**: Yeni mesajlar için push bildirimleri
- **Kullanıcı Profilleri**: Özelleştirilebilir profiller ve avatarlar
- **Sohbet Odaları**: Bireysel ve grup sohbetleri destekler
- **Medya Paylaşımı**: Görüntü, dosya ve medya paylaşımı
- **Arama İşlevi**: Mesaj ve sohbetlerde arama yapın
- **Koyu Mod**: Yerleşik koyu tema desteği
- **Mesaj Geçmişi**: Kalıcı mesaj depolaması ve erişimi

## Getting Started 🚀

### Ön Koşullar

- [Flutter](https://flutter.dev/docs/get-started/install) (son kararlı sürüm)
- [Dart](https://dart.dev/get-dart) (Flutter ile birlikte gelir)
- [Matrix Homeserver](https://matrix.org/) (Synapse veya başka bir implementation)
- Yapılandırılmış Matrix Bridges (mautrix-whatsapp, mautrix-telegram, vb.)
- Git

### Kurulum

1. **Deposunu klonla**
   ```bash
   git clone https://github.com/tunahanahltc/cross_platform_chat_app.git
   cd cross_platform_chat_app
   ```

2. **Bağımlılıkları yükle**
   ```bash
   flutter pub get
   ```

3. **Matrix Sunucusunu Yapılandır**
   - Matrix Homeserver adresini (ör. https://matrix.example.com)
   - Kullanıcı kimliğini ve erişim tokenini ayarla
   - Bridge konfigürasyonlarını `.env` veya config dosyasında belirt

4. **Uygulamayı Çalıştır**
   ```bash
   # Geliştirme için
   flutter run

   # Belirli platform için
   flutter run -d ios      # iOS
   flutter run -d android  # Android
   flutter run -d chrome   # Web
   flutter run -d macos    # macOS
   flutter run -d windows  # Windows
   flutter run -d linux    # Linux
   ```

## Proje Yapısı 📁

```
cross_platform_chat_app/
├── lib/
│   ├── main.dart                 # Giriş noktası
│   ├── screens/                  # UI ekranları
│   │   ├── login_screen.dart
│   │   ├── chat_screen.dart
│   │   ├── home_screen.dart
│   │   ├── bridges_screen.dart   # Matrix bridges yönetimi
│   │   └── profile_screen.dart
│   ├── models/                   # Veri modelleri
│   │   ├── user.dart
│   │   ├── message.dart
│   │   ├── chat_room.dart
│   │   └── bridge.dart           # Bridge modeli
│   ├── services/                 # İş mantığı
│   │   ├── auth_service.dart
│   │   ├── message_service.dart
│   │   ├── matrix_service.dart   # Matrix protokol servisi
│   │   ├── bridge_service.dart   # Bridge yönetimi
│   │   └── platform_service.dart # Platform entegrasyonu
│   ├── widgets/                  # Yeniden kullanılabilir widget'lar
│   │   ├── message_bubble.dart
│   │   ├── chat_input.dart
│   │   ├── user_tile.dart
│   │   └── bridge_indicator.dart # Bridge durumu göstergesi
│   └── utils/                    # Yardımcı sınıflar
│       ├── constants.dart
│       ├── theme.dart
│       └── matrix_config.dart    # Matrix yapılandırması
├── test/                         # Birim ve widget testleri
├── pubspec.yaml                  # Bağımlılıklar
├── .env.example                  # Ortam değişkenleri örneği
└── README.md                      # Bu dosya
```

## Kullanılan Teknolojiler 🛠️

- **Framework**: [Flutter](https://flutter.dev/)
- **Dil**: [Dart](https://dart.dev/)
- **İletişim Protokolü**: [Matrix (Element)](https://matrix.org/)
- **Matrix Bridges**: 
  - mautrix-whatsapp
  - mautrix-telegram
  - mautrix-instagram
  - mautrix-twitter
  - mautrix-bluesky
- **Durum Yönetimi**: Provider / Riverpod / GetX
- **Yerel Depolama**: SQLite / Hive
- **WebSocket**: Gerçek zamanlı güncellemeler için

## Matrix Bridge Yapılandırması 🔧

### WhatsApp Bridge
```yaml
bridges:
  whatsapp:
    enabled: true
    connection_string: "postgresql://user:pass@localhost/mautrix_whatsapp"
```

### Telegram Bridge
```yaml
bridges:
  telegram: 
    enabled: true
    bot_token: "YOUR_TELEGRAM_BOT_TOKEN"
```

### Instagram Bridge
```yaml
bridges:
  instagram:
    enabled: true
    username: "your_instagram_username"
```

### Twitter Bridge
```yaml
bridges:
  twitter:
    enabled: true
    api_key: "YOUR_TWITTER_API_KEY"
    api_secret: "YOUR_TWITTER_API_SECRET"
```

### Bluesky Bridge
```yaml
bridges:
  bluesky:
    enabled: true
    handle: "your.bsky.social"
```

## API Referansı 📚

### Kimlik Doğrulama
- `AuthService.register()` - Yeni kullanıcı kayıt
- `AuthService.login()` - Mevcut kullanıcı girişi
- `AuthService.logout()` - Geçerli kullanıcının çıkışı

### Mesajlaşma
- `MessageService.sendMessage()` - Yeni mesaj gönder
- `MessageService.getMessages()` - Sohbet mesajlarını al
- `MessageService.deleteMessage()` - Mesajı sil

### Bridge Yönetimi
- `BridgeService.connectBridge()` - Bridge bağlantısını kur
- `BridgeService.getBridgeStatus()` - Bridge durumunu kontrol et
- `BridgeService.syncMessages()` - Mesajları senkronize et
- `BridgeService.getAvailableBridges()` - Mevcut bridge'leri listele

### Kullanıcı Yönetimi
- `UserService.getUserProfile()` - Kullanıcı profili bilgisini al
- `UserService.updateProfile()` - Profili güncelle
- `UserService.getOnlineUsers()` - Çevrimiçi kullanıcıları al

## Katkıda Bulunma 🤝

Katkılarınızı bekliyoruz! Katkı sağlamak için:

1. Depoyu fork edin
2. Bir feature branch'i oluşturun (`git checkout -b feature/harika-ozellik`)
3. Değişikliklerinizi commit edin (`git commit -m 'Harika özellik ekle'`)
4. Branch'e push yapın (`git push origin feature/harika-ozellik`)
5. Bir Pull Request açın

Lütfen kodunuzun standartlarımıza uyduğundan ve test'ler içerdiğinden emin olun. 

## Testler 🧪

Testleri şu komutla çalıştırın: 

```bash
flutter test

# Kapsam raporu için
flutter pub global activate coverage
flutter pub global run coverage:format_coverage
```

## Sorun Giderme 🔧

### Yaygın Sorunlar

**Sorun**: Flutter doctor hata gösteriyor
```bash
flutter doctor -v
flutter pub get
```

**Sorun**: Matrix sunucusu bağlantısı başarısız
- Matrix homeserver adresinin doğru olduğundan emin olun
- İnternet bağlantısını kontrol edin
- Sunucu güncellemelerini kontrol edin

**Sorun**: Bridge senkronizasyonu çalışmıyor
- Bridge konfigürasyonlarını kontrol edin
- Bridge servislerin çalışıp çalışmadığını doğrulayın
- Günlükleri inceyin

**Sorun**: Hot reload çalışmıyor
- Hot restart'ı deneyin: terminalde `r` yazın
- Ya da yeniden oluşturun: `flutter run --no-fast-start`

## Performans Optimizasyonu ⚡

- Sohbet mesajlarının lazy yüklenmesi
- Görüntü önbelleği hızlı yükleme için
- Konuşma listeleri için pagination
- Verimli state management
- Hızlı sorgular için veritabanı indeksleme
- Bridge mesaj senkronizasyonu optimizasyonu

## Yol Haritası 🗺️

- [x] Matrix bridge desteği
- [x] WhatsApp entegrasyonu
- [x] Telegram entegrasyonu
- [x] Instagram entegrasyonu
- [x] Twitter entegrasyonu
- [x] Bluesky entegrasyonu
- [x] Sesli ve video çağrı
- [x] Uçtan uca şifreleme
- [x] Mesaj reaksiyonları ve emoji'ler
- [ ] Yazma göstergeleri
- [ ] Mesaj okuma bildirimleri
- [ ] Kullanıcı varlık göstergeleri
- [x] Filtreleri ile mesaj arama
- [ ] Yönetici paneli

## Lisans 📄

Bu proje MIT Lisansı altında lisanslanmıştır - detaylar için [LICENSE](LICENSE) dosyasına bakın.

## Yazarlar ✍️

- **tunahanahltc** - *İlk çalışma* - [GitHub](https://github.com/tunahanahltc)

## Destek 💪

Destek için [GitHub Issues](https://github.com/tunahanahltc/cross_platform_chat_app/issues) üzerinde bir issue açın veya depo aracılığıyla bizimle iletişime geçin.

## Teşekkürler 🙏

- Flutter ve Dart toplulukları
- Matrix protokolü ve ecosystem'u
- mautrix bridges geliştiricileri
- Tüm katkıda bulunanlar ve kullanıcılar

---

**❤️ ile Cross Platform Chat App Takımı tarafından yapılmıştır
