# Q&A Hazırlık — Olası Sorular ve Hazır Cevaplar

> Sunum sonrası 3-5 dk Q&A bekleniyor. Bu listeyi **bir gün önce sesli prova et**.
> Her cevap 30-60 sn hedefiyle yazıldı.
> **Anlatı bağlamı:** Agent Store, OpenClaw'ın **üstüne** kurulan ürün katmanı (rakip değil, tamamlayıcı). Bugün standalone, bridge plugin v2 milestone.

---

## 🎯 Kategori 1: Anlatı / Felsefe

### Q1.1 — "Niye Clawcon'da bu sunumu yaptın? Agent Store OpenClaw'ı kullanmıyor."

> *"Bugünkü kod kullanmıyor — standalone. Ama anlatının özü mimari ve yön: Agent Store, OpenClaw multi-agent'ın çözmediği son-kullanıcı UX boşluğunu doldurmak için var. VISION zaten 'core'a koymayacağız' diyor. Ben tam o boşluğa ürün katmanı olarak geldim. Bridge plugin v2 ile dispatch zincirini OpenClaw'a yönelteceğim — bu sunum o yola davet ediyor."*

### Q1.2 — "VISION'ı çiğnemiyor musun?"

> *"Tam tersi — yaşatıyorum. VISION ***'as a default architecture'*** diyor. Yani: core'a koymayın, ayrı katman olarak yazın. Ben tam o yolu seçtim. Agent Store opt-in bir ürün, OpenClaw'a zorunlu değil. Felsefenin söylediği şey bu: capability izole, core lean."*

### Q1.3 — "Niye standalone yazdın, plugin yazsaydın?"

> *"Plugin form yetersizdi. On-chain economy, Postgres schema, Flutter Web build pipeline — bunlar plugin'in taşıyabileceği yük değil. Standalone başlayıp v2'de bridge plugin'le OpenClaw'a bağlanacağım. Bu hibrit yaklaşım Agent Store'un kendi backend'ini koruyup OpenClaw'ın orchestration'ını delege etmesini sağlıyor."*

### Q1.4 — "Bridge plugin'siz Agent Store ne işe yarıyor?"

> *"Bugün standalone bir multi-agent ürün — kullanıcı agent oluşturur, takım kurar, workflow çalıştırır. Çalışıyor, satıyor, gelir üretiyor. Bridge plugin **enterprise** kullanıcılar için ekstra: 'Bizim OpenClaw deployment'ımıza bağlansın, kendi izolasyon kurallarımız geçerli olsun' diyenler için. v2'nin değer önerisi bu."*

### Q1.5 — "5 saniyede özetle ne yaptın."

> *"OpenClaw'ın multi-agent zeminin üstüne son-kullanıcı için web ürün katmanı: Agent Store. Marketplace + UX + economy. OpenClaw'ın eksik bıraktığını doldurmak için, OpenClaw'la birlikte düşünülmesi için."*

---

## 🛠 Kategori 2: Teknik mimari

### Q2.1 — "Bridge plugin nasıl çalışacak somut olarak?"

> *"İki yön. Yön 1 (Agent Store → OpenClaw): Guild Master'ın seçtiği takım, plugin tarafından OpenClaw bindings JSON5'ine çevrilir. Bridge `team-pipeline://` custom channel olarak kayıt edilir. Bindings precedence ile her takım üyesi OpenClaw agent'ına dispatch olur. Yön 2 (OpenClaw → Agent Store): OpenClaw agent'ı Agent Store'un library'sine 'register' olur, kullanıcı tarayıcıdan onu görür. v2 birinci yön, v3 çift yönlü."*

### Q2.2 — "Guild Master'ın LLM-driven seçimi OpenClaw'ın deterministik bindings'iyle nasıl uyuşur?"

> *"Çelişmiyor — LLM seçim **dispatch öncesi**. Guild Master takımı seçtikten sonra bindings DETERMINISTIK çalışır. Yani: kullanıcı 'login akışı' der, LLM 'Wizard + Artisan + Guardian' der. O üç agent ID'si OpenClaw'a deterministik bindings ile yönlenir. LLM sadece routing **input'unu** seçer, routing'in kendisini değil."*

### Q2.3 — "Per-node model seçimi (haiku/sonnet/opus) OpenClaw'a nasıl map oluyor?"

> *"Bugün Agent Store backend Claude API'yi doğrudan çağırıyor. v2 bridge'de: her Legend node bir OpenClaw `agentId`'sine, her node'un model seçimi de o agentId'nin `model` config'ine map oluyor. Yani Wizard node'u sonnet'le yapılandırılmış OpenClaw agent'ına dispatch ediliyor. Per-agent model OpenClaw'ın kendi feature'ı."*

### Q2.4 — "Wallet auth ve OpenClaw auth-profile arasındaki köprü?"

> *"Bridge plugin'de wallet adresi → OpenClaw `agentId` mapping tablosu. JWT'de `wallet_address` claim'i var, plugin bunu örnek `agent_user_0xABC` formatına çeviriyor. Her wallet için OpenClaw'da ayrı bir `agentDir` oluşturuluyor — auth profilleri orada. Wallet kullanıcı kimliği, agentDir o kimliğin OpenClaw runtime izolasyonu."*

### Q2.5 — "Postgres + Redis + Solidity + OpenClaw — overkill değil mi?"

> *"Net rolleri var: Postgres durumsal veri (agents, library, executions), Redis cache + rate limit, Solidity kredi + agent registry on-chain, OpenClaw orchestration runtime. Hiçbiri başkasının yerine geçmiyor. Eğer ekonomi ve marketplace yoksa Solidity gereksiz, evet — ama Agent Store'un değer önerisi tam bu."*

### Q2.6 — "Aipipelinesvc'i niye OpenClaw'a taşımıyorsun?"

> *"Aipipelinesvc Agent Store'un domain-specific AI mantığı — prompt analyze, character type detection, profile scoring, avatar generation. Bunlar gamification için, OpenClaw için değil. Generic LLM call'larını OpenClaw'a delege edebilirim ama bu boutique mantığı kalmalı."*

---

## 🎮 Kategori 3: Gamification + UX

### Q3.1 — "Pixel-art karakter sistemi neden? Cosmetic mi?"

> *"Fonksiyonel. 8 karakter tipi prompt domain'ini görselleştiriyor — Wizard backend, Artisan frontend, Guardian security, vb. Store ekranında kategoriden önce renkten tanıyorsun. Rarity sistemi prompt skoruna ve kullanım istatistiklerine bağlı — daha çok kullanılan agent zamanla 'Epic' olabiliyor. Sosyal sinyal."*

### Q3.2 — "Karakter tipini AI mı belirliyor?"

> *"Hibrit: keyword scoring (agentsvc) + Claude semantic analysis (aipipelinesvc), fallback chain. Manuel override YOK — kasıtlı. Manuel override eklersem herkes 'Legendary Wizard' yapar, sistem değer kaybeder. 'Re-detect from prompt' butonu var — prompt değiştirip yeniden analiz tetikliyorsun."*

### Q3.3 — "Mobil destek?"

> *"v3.6 sprint'inde 'Mobile Pass' var — şu an in-progress. ResponsiveLayout widget'ı + AppBreakpoints (768px) hazır, 8 ekran mobile batch 1'de. Clawcon sonrası tamamlanacak."*

---

## 🚀 Kategori 4: Geleceğe yönelik

### Q4.1 — "Bridge plugin RFC ne zaman açılıyor?"

> *"Q4 2026 hedefim. Önce bu sunum sonrası community feedback'ini topluyorum. RFC `clawhub.ai/rfc/agent-store-bridge` adresinde olacak. Katkı isteyen developerlar için entry point. v1 spesifikasyon ~2 hafta sonra hazır."*

### Q4.2 — "Mainnet ne zaman?"

> *"Mainnet için kalan: contract audit, KYC/AML compliance review, multi-chain deploy, scalability test. Realist hedef: 6 ay. Şu an testnet, hızlı iteration."*

### Q4.3 — "Plugin marketplace olacak mı?"

> *"Agent Store **kendisi** marketplace — agent prompt'ları için. ClawHub plugin'ler için, ayrı kullanım. İki marketplace de bağımsız ekosistemler."*

### Q4.4 — "Self-host edilebilir mi?"

> *"Repo açılınca evet. MIT lisans. docker-compose ile self-host, .env minimum: JWT_SECRET + Claude/Gemini API key. On-chain özellikleri kullanmadan da çalışıyor — kredileri off-chain dev-grant ile dağıtabilirsin. Bridge plugin v2 sonrası kendi OpenClaw deployment'ına bağlayabilirsin."*

### Q4.5 — "Multi-tenant SaaS olarak deploy?"

> *"Şu an single-tenant. Multi-tenant için workspace isolation (tenant başına ayrı schema) ve JWT'ye tenant_id claim eklemek lazım. 1-2 hafta. Bridge plugin sonrası: her tenant kendi OpenClaw deployment'ına bağlanabilir."*

---

## 🔥 Kategori 5: Zor sorular

### Q5.1 — "Bu sadece UI demosu, gerçek ürün değil."

> *"v3.6, 83 test geçiyor (40 backend + 43 frontend), CI gate, Vercel + Railway production deploy var, Monad testnet kontratları çalışıyor. Şu an evet — kullanıcı tabanı küçük, mainnet öncesi. Ama 'gerçek ürün' kriteri kullanıcı sayısı mı, kod kalitesi mi, deploy stabilitesi mi? İlk kriterse henüz değil; diğer ikisi için evet."*

### Q5.2 — "OpenClaw'a bağımlı olmadan da çalışıyor — niye OpenClaw'a bağlayasım?"

> *"Şu kullanım senaryolarında: 1) Kendi enterprise OpenClaw deployment'ın varsa — Agent Store'u oraya bağlayıp izolasyon kurallarını miras al. 2) Multi-agent OpenClaw plugin'lerini Agent Store kullanıcısına açmak istiyorsan. 3) ClawHub'da mevcut plugin'lerle composability lazımsa. Standalone yeterli olan kullanıcı bağlamak zorunda değil — hibrit tasarım."*

### Q5.3 — "Niye standalone başladın da OpenClaw entegrasyonunu sonradan ekledin? Plansız mıydı?"

> *"Planlı bir hibrit yaklaşım. Önce ürün katmanını valide ettim (kullanıcı agent kart'ları seviyor mu, Guild Master gerçekten faydalı mı, on-chain credit ekonomi anlamlı mı). Foundation iyi olduktan sonra OpenClaw bridge geldi. 'Önce ürünü doğrula, sonra altyapı genişlet' — startup pattern. Tersini yapsaydım plugin yazıp kullanıcı bulamayabilirdim."*

### Q5.4 — "Demoda halüsinasyon görürsek ne olacak?"

> *"Üç katman koruma: 1) 'Suggest again' butonu — yeni prompt'la dene. 2) Manual override — kullanıcı agent'ları kendisi seçebiliyor (Legend DAG'i sıfırdan kurma). 3) Onay adımı — Add to Legend tıklamadıkça hiçbir şey kaydedilmiyor. Halüsinasyon olursa user kontrolü kaybetmiyor."*

### Q5.5 — "Eğer Agent Store hiç tutmazsa OpenClaw'la entegrasyonun anlamı kalır mı?"

> *"Brutally honest cevap: hayır. Bridge plugin Agent Store başarılıysa anlamlı. Değilse OpenClaw camiası vakit harcamasın diyorum. Ama Agent Store şu an 4.4/5 platform avg ratings'le ilerliyor — başarılı olmaması düşük ihtimal. Eğer öyleyse plugin RFC bekleyebilir."*

---

## Q&A teknik notları

### Eğer cevabı bilmiyorsan
> *"Şu an net cevabım yok ama [iletişim bilgisi] üzerinden konuşalım, detaylı incelemek isterim."*

### Eğer saldırgan tonlu gelirse
- Sakin kal, savunmaya geçme
- "Geçerli endişe — şöyle düşündüm: ..."
- 60 sn'yi aşıyorsa "Bu konuyu sunum sonrası ayrıntılı konuşalım"

### Eğer hiç soru gelmezse
> *"Sorularınız için iletişim bilgilerim slaytta. Multi-agent stack'inizdeki UX katmanlarını duymak isterim — özellikle hangi noktada custom çözümler ürettiğinizi."*

---

## Prova kontrol listesi

- [ ] Q1.1, Q1.2, Q1.4 — anlatı sorularını sesli prova et (en sık gelir)
- [ ] Q2.1 — bridge plugin somut nasıl çalışacak — net açıklayabiliyorum
- [ ] Q5.1, Q5.2 — zor soruları cevap ezberle
- [ ] Q1.5 — 5 saniyelik özet hazır olsun
- [ ] "Cevabını bilmiyorum" cümlesini doğal söyleyebiliyor musun?
- [ ] Saldırgan ton senaryosu en az 1 kez prova
