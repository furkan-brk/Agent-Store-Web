# Development Workflow

Bu doküman Agent Store üzerinde lokal geliştirme için iki çalışma modunu anlatır:
**tam Docker** (prod-benzeri) ve **hybrid** (backend Docker + Flutter `flutter run`
hot reload). Birlikte çalışan ama birbirinden bağımsız iki yaklaşımdır — ihtiyaca
göre birini seçin.

---

## 1. Tam Docker Modu (prod-benzeri)

Tüm servisler (PostgreSQL, Redis, tüm Go mikroservisleri ve Flutter Web statik
build) container içinde çalışır. En tutarlı mod: CI/CD ve prod ile aynı
davranış.

```bash
docker compose up -d
```

- Frontend: http://localhost (nginx, port 80)
- Gateway API: http://localhost:8080
- Değişiklik yaptığınızda Flutter tarafı için:
  `docker compose build frontend && docker compose up -d frontend`
  (backend değişiklikleri için ilgili service adını verin).

### Ne zaman kullanılmalı?
- Deploy öncesi son smoke test
- CORS / Nginx / routing sorunlarını repro ederken
- E2E test

---

## 2. Hybrid Dev Modu (hot reload)

Backend ve DB Docker'da çalışır, Flutter Web ise lokal `flutter run -d chrome`
ile hot reload modunda. En hızlı iterasyon modu.

### Kurulum

```bash
# Terminal 1 — sadece backend + DB + Redis container'ları
docker compose up -d postgres redis gateway authsvc agentsvc aipipelinesvc guildsvc workspacesvc

# Opsiyonel: 80 portunu Flutter debug server için serbest bırakın
docker compose stop frontend
```

```bash
# Terminal 2 — Flutter hot reload (cwd = agent_store)
cd agent_store
flutter run -d chrome
```

Flutter `r` → hot reload, `R` → hot restart, `q` → çık.

### API URL Konfigürasyonu

`agent_store/lib/core/constants/api_constants.dart` satır 2-5:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);
```

Default değer zaten `http://localhost:8080` olduğundan `--dart-define` **gerekmez**.
Farklı backend'e (staging, prod) bağlanmak isterseniz:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://staging-gateway.example.com
```

### CORS Notu

`backend/pkg/middleware/cors.go` satır 35-39:

```go
if os.Getenv("RAILWAY_ENVIRONMENT") != "production" {
    if strings.HasPrefix(origin, "http://localhost:") ||
       strings.HasPrefix(origin, "http://127.0.0.1:") {
        return true
    }
}
```

Non-production ortamda `localhost:*` wildcard olarak whitelist'te. Flutter debug
server rastgele yüksek port kullanır (`http://localhost:12345`) — sorunsuz
çalışır. Prod deploy'da bu kural devre dışı (`RAILWAY_ENVIRONMENT=production`).

---

## 3. Production Build & Live Refresh

Flutter Web production build üretmek ve Docker frontend container'ında live'a
çıkarmak:

```bash
cd agent_store
flutter build web --release --dart-define=API_BASE_URL=http://localhost:8080
cd ..
docker compose restart frontend
```

`build/web/` dizininin içeriği `agent_store/Dockerfile` tarafından nginx image'ına
kopyalanır. **Not:** Dockerfile hâlâ kendi içinde `flutter build` çalıştırıyorsa
`docker compose build frontend` yeterlidir; üstteki manuel build sadece lokal
testler için.

---

## 4. Debug İpuçları

### Flutter Web
- **DevTools Console (F12):** Flutter uygulamasının çıktısı ve `print` logları
  burada görünür. Null-check / render hataları için ilk bakılacak yer.
- **Flutter DevTools:** `flutter run` çıktısında verilen URL üzerinden widget
  inspector, timeline, memory profili.
- **Pixel-art rendering:** `filterQuality: FilterQuality.none` zorunlu —
  bulanıklaşma yaşıyorsanız kontrol edin.

### Backend
```bash
# Canlı log stream
docker compose logs -f gateway
docker compose logs -f authsvc

# Tüm servisler tek stream
docker compose logs -f

# Son 200 satır
docker compose logs --tail 200 gateway

# Container içinde shell
docker compose exec gateway sh
```

### Veritabanı
```bash
# psql ile bağlan
docker compose exec postgres psql -U postgres -d agent_store

# Tüm tabloları listele
docker compose exec postgres psql -U postgres -d agent_store -c "\dt"
```

### CORS / Auth Debug
- 401 alıyorsanız `Authorization: Bearer <jwt>` header'ını DevTools Network
  tab'ında kontrol edin.
- 502 Bad Gateway → `docker compose logs gateway` bakın, `depends_on` zinciri
  yüklü mü kontrol edin.
- CORS preflight fail → `cors.go` whitelist'ine origin'i ekleyin.

---

## 5. Sık Kullanılan Komutlar

| İşlem | Komut |
|---|---|
| Tam stack başlat | `docker compose up -d` |
| Stack'i durdur | `docker compose down` |
| Container loglarını takip | `docker compose logs -f <service>` |
| Bir servisi yeniden başlat | `docker compose restart <service>` |
| Image'ları yeniden derle | `docker compose build --no-cache` |
| Flutter analyze | `cd agent_store && flutter analyze` |
| Flutter testleri | `cd agent_store && flutter test` |
| Flutter temiz build | `cd agent_store && flutter clean && flutter pub get` |
| Go testleri | `cd backend && go test ./...` |
| Go lint | `cd backend && go vet ./...` |

---

## 6. Ortak Sorunlar & Çözümler

| Belirti | Olası Sebep | Çözüm |
|---|---|---|
| Frontend 502 | Gateway yukarı değil / depends_on eksik | `docker compose logs gateway`, stack'i yeniden başlat |
| Flutter "Null check on null" | Canvas/state stale reference | DevTools Console, ilgili feature state reset'ini kontrol et |
| CORS hatası | Non-prod wildcard devre dışı | `RAILWAY_ENVIRONMENT` unset olmalı, origin `localhost:*` olmalı |
| `flutter run` port çakışması | 80 port dolu | `docker compose stop frontend` |
| Pixel karakter bulanık | `FilterQuality.high` | `FilterQuality.none` kullan |
| Hot reload uygulamıyor | `const` widget değişmedi | Hot restart (`R`) veya widget'taki `const` kaldır |

---

## 7. Önerilen Workflow

1. **Günlük geliştirme:** Hybrid mod (bölüm 2).
2. **PR öncesi:** Tam Docker modunda smoke test (bölüm 1).
3. **Deploy öncesi:** `flutter analyze` sıfır hata + `flutter build web --release` başarılı.
4. **Live test:** `docker compose restart frontend` ile production build'i localhost'ta doğrula.
