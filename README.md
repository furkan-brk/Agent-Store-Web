<div align="center">

<img src="https://img.shields.io/badge/EVM-Solidity_0.8-purple?style=for-the-badge&logo=ethereum" />
<img src="https://img.shields.io/badge/Backend-Go_1.22-blue?style=for-the-badge&logo=go" />
<img src="https://img.shields.io/badge/Frontend-Flutter_Web-teal?style=for-the-badge&logo=flutter" />
<img src="https://img.shields.io/badge/Chain-Monad_Testnet-gold?style=for-the-badge" />

# ⚔️ Agent Store
### *Yapay Zeka, RPG ile Buluşuyor*
**Kodlama Maceralarınız İçin Nihai Lonca**

> Promptlar artık sadece metin değil. Onlar yetenekleri, sınıfları ve karakterleri olan birer Kahraman.

</div>

---

## 🧙 Proje Nedir?

**Agent Store**, AI prompt ajanlarını bir RPG evrenine taşıyan merkeziyetsiz bir pazar yeridir. Her ajan; benzersiz bir sınıfa, uzmanlık alanına ve nadirlik derecesine sahip bir kahramandır.

Geleneksel prompt paylaşım platformlarının aksine, Agent Store:

- Ajanları **Wizard, Strategist, Oracle** gibi rollere göre sınıflandırır
- Her ajana **DEF, POW, CTRL** gibi RPG istatistikleri atar
- **Epic ve Legendary** seviyelerde ajan nadirliği sunar
- Ajanları **blockchain üzerinde** ticarete açar (10.00 MON)
- **WebContainer** entegrasyonu ile ajanları doğrudan tarayıcıda çalıştırır

---

## ✨ Temel Özellikler

### ⚔️ İş Akışınızı Oyunlaştırın
Promptlar artık karakter kartlarına dönüşüyor. Kod yazan bir Archmage, strateji kuran bir Strategist veya vizyon üreten bir Oracle — her ajan kendi hikayesiyle gelir.

### 🧠 Derin Karakterizasyon
İstatistikler ve hikaye, LLM'in tam olarak nasıl davranacağını belirler. Sadece kod yazmaz, karakterine uygun kararlar alır.

### 🛒 Kendi Yapay Zeka Takımınızı Kurun
Yüzlerce uzman ajan arasından seçim yapın. İhtiyacınıza göre filtreleyin:
`#coding` `#planning` `#security`

### ⚡ Sadece Konuşmaz, Çalıştırır
Tarayıcı içi **WebContainer** entegrasyonu. Ajanlar, Node.js ortamını doğrudan tarayıcınızda kurar, kodu yazar ve test eder.

### 💰 Değer Odaklı Ekosistem
En iyi prompt mühendislerinin yarattığı Epic ve Legendary ajanlara erişmek için tek fiyat. Satın al · Kullan · Çatallandır.

---

## 🏗️ Mimari

```
Agent Store
├── agent_store/          # Flutter Web frontend
│   ├── lib/
│   │   ├── features/     # Store, wallet, agent detail
│   │   └── app/          # Router, theme
│   └── web/
├── backend/              # Go 1.22 REST API & mikroservisler
│   └── cmd/gateway/      # API Gateway
├── contracts/            # Solidity 0.8.24 akıllı kontratlar
│   ├── scripts/          # Hardhat deployment
│   └── test/             # 13/13 test passed ✅
└── docker-compose.yml    # Full stack orchestration
```

---

## 🛠️ Tech Stack

| Katman | Teknoloji |
|--------|-----------|
| Frontend | Flutter Web · Dart |
| Backend | Go 1.22 · REST API · Mikroservisler |
| Blockchain | Solidity 0.8.24 · EVM · Monad Testnet |
| Deployment | Hardhat · JavaScript |
| Veritabanı | PostgreSQL · GORM |
| DevOps | Docker · Docker Compose · Shell/Bash |

---

## 🔐 Güvenlik

- `ReentrancyGuard` — yeniden giriş saldırılarına karşı korumalı
- `Access Control` — rol tabanlı erişim yönetimi
- `CORS Middleware` — whitelist konfigürasyonu aktif
- `.env` — `.gitignore` ile korumalı, asla commit'e girmez

---

## 🚀 Kurulum

### Gereksinimler
- Go 1.22+
- Flutter 3.x
- Node.js 18+
- Docker & Docker Compose
- PostgreSQL

### Hızlı Başlangıç

```bash
# Repo'yu klonla
git clone https://github.com/furkan-brk/Agent-Store-Web.git
cd Agent-Store-Web

# Ortam değişkenlerini ayarla
cp .env.example .env

# Bağımlılıkları yükle
cd agent_store && flutter pub get
cd ../backend && go mod download
cd ../contracts && npm install

# Kontratları deploy et (local)
npx hardhat node
npx hardhat run scripts/deploy.js --network localhost

# Full stack başlat
docker compose up --build

# Flutter Web
cd agent_store && flutter run -d chrome
```

---

## 🧪 Testler

```bash
# Solidity kontrat testleri
cd contracts && npx hardhat test
# 13/13 passed ✅

# Go unit testleri
cd backend && go test ./...
```

---

## 🏆 Hackathon

Bu proje bir hackathon kapsamında geliştirilmiştir.

---

## 👥 Takım

| Furkan  | [@furkan-brk](https://github.com/furkan-brk) |
| Hale Sezin  | [@seziyy](https://github.com/seziyy) |
| Alp | [ AlpDurak ] (https://github.com/AlpDurak) |
| Doğu | [ Doğu Kervan] https://github.com/dogujen |

---

<div align="center">

*"İş akışınızı oyunlaştırın. Ajanlarınızı seçin. Büyüyü çalıştırın."*

**Agent Store** · Built with Flutter · Go · Solidity

</div>
