# Agent Store - Ultra Detailed Guide

Bu dokuman, README'den bagimsiz ve daha derin bir teknik/urunsel referanstir.
Hedefi, projeye yeni gelen bir ekibin su uc soruyu net cevaplamasidir:

1. Sistem ne yapiyor ve hangi ozellikleri sunuyor?
2. Kod ve servis mimarisi nasil calisiyor?
3. Gelistirme, test, deploy ve sorun giderme adimlari nasil yonetiliyor?

Bu dosya hem product-level feature katalogu hem de engineering runbook olarak
kullanilabilir.

---

## 1. Kisa Ozet

Agent Store, AI agent promptlarini bir marketplace + workflow + gamification
deneyiminde birlestiren platformdur.

Ana fikir:

- Kullanici wallet ile giris yapar.
- Agent kesfeder, olusturur, kaydeder, fork eder, satin alir.
- Guild olusturur ve Team AI etkilesimi yapar.
- Mission ve Legend ile tekrar kullanilabilir workflow tasarlar ve calistirir.
- Card Editor ile agent metadata'sini split-view edit eder.

Teknoloji omurgasi:

- Frontend: Flutter Web
- Backend: Go microservices + API Gateway
- Data: PostgreSQL + Redis
- AI: Internal AI pipeline + opsiyonel Claude execution
- Blockchain: Solidity contracts (Monad Testnet)

---

## 2. Kapsam ve Roller

## 2.1 Kullanici Roller

- Ziyaretci: Public listeleme/detay goruntuleme
- Auth kullanici: Library, profile, mission, legend, guild aksiyonlari
- Creator: Kendi agentini olusturan ve yoneten kullanici
- Buyer: Agent satin alan kullanici

## 2.2 Teknik Roller

- Frontend gelistirici: Flutter ekran, state, UX akislar
- Backend gelistirici: Service router, handler, business logic, DB
- AI pipeline gelistirici: Analyze/profile/score/chat/avatar endpointleri
- Blockchain gelistirici: Contract deploy, address/env senkronu

---

## 3. Tum Ozellik Envanteri

Asagidaki tablo projedeki canli ozellikleri route + backend baglantisi ile
esler.

| Feature                  | Frontend Route                    | Ana Ekran                     | Ana Backend Baglantisi                        |
| ------------------------ | --------------------------------- | ----------------------------- | --------------------------------------------- |
| Store / Discovery        | /                                 | store_screen.dart             | GET /api/v1/agents, /categories, /trending    |
| Agent Detail             | /agent/:id                        | agent_detail_screen.dart      | GET /agents/:id, POST /chat, /fork, /purchase |
| Create Agent             | /create                           | create_agent_screen.dart      | POST /api/v1/agents                           |
| Library                  | /library                          | library_screen.dart           | GET/POST/DELETE /api/v1/user/library          |
| Wallet Connect           | /wallet                           | wallet_connect_screen.dart    | GET /auth/nonce/:wallet, POST /auth/verify    |
| Credit History           | /credits/history                  | credit_history_screen.dart    | GET /api/v1/user/credits/history              |
| Leaderboard              | /leaderboard                      | leaderboard_screen.dart       | GET /api/v1/leaderboard                       |
| Public Profile           | /profile/:wallet                  | public_profile_screen.dart    | GET /api/v1/users/:wallet                     |
| Creator Dashboard        | /creator                          | creator_dashboard_screen.dart | GET /agents?creator_wallet=... + update/fork  |
| Settings                 | /settings                         | settings_screen.dart          | GET/PATCH /api/v1/user/profile                |
| Guild List/Detail/Create | /guild, /guild/:id, /guild/create | guild screens                 | /api/v1/guilds*                               |
| Guild Master             | /guild-master                     | guild_master_screen.dart      | POST /api/v1/guild-master/suggest/chat        |
| Missions                 | /missions                         | missions_screen.dart          | /api/v1/user/missions*                        |
| Legend Workflow          | /legend                           | legend_screen.dart            | /api/v1/user/legend/*                         |
| Card Editor              | /agent/:id/edit                   | card_editor_screen.dart       | PUT /api/v1/agents/:id                        |

Not: `agent_store/lib/features/explore/` klasoru mevcut ancak aktif ekran
icermiyor (placeholder).

## 3.1 Merkezi Kabiliyet Matrisi (Rating)

Bu bolum, platformun ana kabiliyetlerini tek noktada toplar ve rating verir.
Skorlar 5 uzerinden verilmistir.

Skor metodolojisi:

- Kapsam (40%): Ozelligin sundugu fonksiyon setinin genisligi
- Stabilite (40%): Uretim kosullarinda tutarlilik ve hata toleransi
- UX (20%): Akisin kullanici tarafindaki anlasilabilirligi ve hizliligi

| Kabiliyet Alani         | Rating (5) | Durum     | Kisa Not                                                     |
| ----------------------- | ---------- | --------- | ------------------------------------------------------------ |
| Store / Discovery       | 4.6        | Guclu     | Arama, filtre, trend, kategori ve kaydetme akislari olgun    |
| Agent Detail            | 4.7        | Guclu     | Chat, fork, trial, rating, purchase gibi zengin aksiyon seti |
| Create Agent            | 4.5        | Guclu     | Multi-step create + AI pipeline entegrasyonu stabil          |
| Library                 | 4.7        | Guclu     | Save/remove + owned/create ayrimi net ve kullanimli          |
| Wallet + Credits        | 4.3        | Iyi       | Nonce-signature auth ve credit history mevcut                |
| Leaderboard             | 4.1        | Iyi       | Temel metrikler var, ileri segmentasyon alani acik           |
| Public Profile          | 4.0        | Iyi       | Profil ve creator listing guvenli sekilde sunuluyor          |
| Creator Dashboard       | 4.4        | Guclu     | Yonetim odakli akislar ve hizli edit entrypoint'leri var     |
| Guild                   | 4.1        | Iyi       | Team kurma, member yonetimi ve uyumluluk analizi mevcut      |
| Guild Master            | 4.2        | Iyi       | Suggest + team chat akisi dogru capta calisiyor              |
| Missions                | 4.5        | Guclu     | CRUD, sync ve expand destekli tekrar kullanilabilir yapi     |
| Legend Workflow         | 4.8        | Cok Guclu | DAG editor, execute, history, rerun ve template seti olgun   |
| Card Editor             | 4.7        | Guclu     | Split-view live edit, autosave, undo/redo, export guclu      |
| Settings / User Profile | 3.9        | Orta-Iyi  | Temel profil guncelleme var, ileri preference alani acik     |

Toplam platform kabiliyet ortalamasi: **4.4 / 5.0**

Not:

- Bu rating tablosu urunsel ve teknik olgunlugu birlikte olcer.
- Sprint sonunda tablo guncellenerek trend takibi yapilmasi onerilir.

## 3.2 Puan Kirilim Gerekcesi (Tum Kabiliyetler)

Bu bolum, neden 5.0 yerine daha dusuk puan verildigini aciklar ve
iyilestirme backlog'unu listeler.

### 3.2.1 Store / Discovery (4.6/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Arama ve filtre guclu olsa da semantic search, niyet bazli
  kesif ve kisisel oneri katmani tam degil.
- Stabilite acigi: Cache/trending verisinin invalidation stratejisi her
  senaryoda deterministik degil; yuksek trafikte stale sonuc riski var.
- UX acigi: Filtre durumunun URL ile paylasilabilir/kalici olmamasi ve
  yeni kullanici icin kesif adimlarinin yonlendirmesinin sinirli olmasi.

Yapilabilecekler (onceliklendirilmis):

1. Query-state persistence: filtre/sort/search durumunu URL query param ile
   sakla ve geri yukle.
2. Search kalite artisi: title+tag+description uzerine agirlikli skorlama ve
   typo tolerant fuzzy match ekle.
3. Oneri katmani: kullanicinin save/fork/gecmis etkilesimine gore
   "For You" siralamasi ekle.
4. Cache invalidation politikasi: kategori/trending cache'ine event-temelli
   invalidation ve kisa TTL fallback uygula.
5. Kesif analitigi: search to save, impression to open, open to save
   donusum metriklerini olc ve haftalik iyilestirme dongusu kur.

### 3.2.2 Guild Master (4.2/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Suggest + chat var, fakat gorev dagitimi, rol atama,
  ciktinin otomatik eyleme donusmesi (task creation) gibi adimlar eksik.
- Stabilite acigi: Uzun sohbetlerde baglam surekliligi ve yanit kalitesinin
  tutarliligi daha da guclendirilmeli.
- UX acigi: "Neden bu agent onerildi" aciklamasi ve confidence gorunurlugu
  yetersiz; karar alinabilirlik azaliyor.

Yapilabilecekler (onceliklendirilmis):

1. Explainable suggest: her onerilen agent icin reason, confidence,
   beklenen katki alanlarini goster.
2. Structured output modu: chat cevabini Goal, Plan, Owners, Risks, Next Step
   bloklarina ayirarak standartlastir.
3. Context memory penceresi: mission, library, workflow gecmisi ile
   baglam birlestirip multi-turn performansi sabitle.
4. Action bridge: tek tikla Mission veya Legend workflow olusturma
   aksiyonlari ekle.
5. Kalite olcumu: suggestion acceptance rate, chat to action conversion,
   rerun oranini KPI olarak takip et.

### 3.2.3 Legend Workflow (4.8/5.0)

Puan kirilan noktalar:

- Kapsam acigi: DAG, template, execute, history guclu; ancak paylasilabilir
  alt-workflow kutuphanesi ve versiyonlar arasi migration yardimi sinirli.
- Stabilite acigi: Uzun ve cok adimli calismalarda node-bazli resume/retry
  ve idempotent yeniden calistirma kapsami daha da guclendirilebilir.
- UX acigi: Buyuk graph'lerde node hata nedeninin okunabilirligi ve
  debug-trace netligi her kullanici segmenti icin yeterince hizli degil.

Yapilabilecekler (onceliklendirilmis):

1. Checkpoint tabanli node resume/retry: basarisiz node'dan devam etme
  yetenegini standartlastir.
2. Workflow versioning + diff: kaydedilen surumler arasi degisimi gorunur
  yapip geri donusleri kolaylastir.
3. Preflight validator: eksik baglanti, cycle, role uyumsuzlugu ve tahmini
  kredi tuketimini execution oncesi raporla.
4. Execution observability paneli: node bazli sure, girdi/cikti ozeti,
  hata kodu ve kredi tuketimi timeline'i ekle.
5. Template kalite sistemi: template kullanim ve basari metriklerini izleyip
  top template setini one cikar.

### 3.2.4 Agent Card / Card Editor (4.7/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Canli split-view edit guclu; ancak toplu guncelleme,
  preset paketleri ve card varyant yonetimi sinirli.
- Stabilite acigi: Coklu sekme/cihaz senaryolarinda autosave conflict
  cozumleme katmani daha belirgin hale getirilebilir.
- UX acigi: Ileri alanlar yogun oldugunda yeni kullanici icin form
  kesfedilebilirligi ve karar hizi dusuyor.

Yapilabilecekler (onceliklendirilmis):

1. Prompt yardimli alan onerisi: title/traits/profile icin akilli oneri
  butonlariyla form doldurmayi hizlandir.
2. Revision hash + conflict modal: autosave cakismalarinda birlestirme,
  onceki surume donus ve guvenli kaydetme akisi sun.
3. Preset paketleri: kategori/subclass bazli stat/trait preset'lerini tek
  tikla uygulat.
4. Before/after karsilastirma: kaydetmeden once kart farkini yan yana goster.
5. Creator dashboard toplu aksiyon: secili agentlar icin tag/kategori benzeri
  alanlarda batch update akisi ekle.

### 3.2.5 Agent Detail (4.7/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Chat, fork, trial, rating ve purchase aksiyonlari mevcut;
  ancak benzer agent onerisi, prompt versiyon karsilastirmasi ve cok dilli
  aciklama destegi sinirli.
- Stabilite acigi: On-chain purchase ile backend record arasindaki finality
  penceresinde tx pending/failed durumu icin retry+reconcile akisi
  guclendirilmeli.
- UX acigi: Uzun promptlarda preview/redaction toggle, rating gerekce alani
  ve trial sonrasi "satin al" yonlendirmesi yeterince belirgin degil.

Yapilabilecekler (onceliklendirilmis):

1. Tx state machine: pending/confirmed/failed durumlarini izle ve UI'da
   net statu rozeti goster.
2. Rating moderasyonu: spam/abuse algilama, dogrulanmis kullanici filtresi
   ve helpfulness sinyali ekle.
3. Benzer agent ribbon: ayni karakter tipi ve nadir derecesinden 3-5 oneri
   sunan satir.
4. Prompt redaction + length toggle: uzun promptlar icin truncated/full
   goster, kopyalama analitigi olc.
5. Trial->purchase funnel: trial sonu CTA, conversion oranini KPI olarak
   takip et.

### 3.2.6 Create Agent (4.5/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Multi-step form ve AI pipeline calisiyor; ancak draft
  kaydet/devam, prompt template kutuphanesi ve duplicate-from-existing
  akislari eksik.
- Stabilite acigi: AI pipeline anahtarlari yoksa veya kismi basarisiz
  oldugunda (analyze ok, profile fail) deterministik fallback akisi
  yeterince belirgin degil; timeout/retry semantigi soyutlanabilir.
- UX acigi: Credit yetersizligi son adimda ortaya cikiyor; karakter
  onizlemesi prompt degisikliklerine gore yavas yenileniyor; alan
  yardim/gerekce metinleri sinirli.

Yapilabilecekler (onceliklendirilmis):

1. Draft persistence: form state'i lokal+remote kaydet, kullanici
   donduginde devam ettir.
2. Pipeline resilience: per-stage timeout/retry, kismi basari halinde
   "tekrar dene"yi sadece eksik stage icin kosturma.
3. Credit on-ramp early check: ilk adimda gerekli kredi tahminini ve
   yetersizlikte topup akisini goster.
4. Prompt template galerisi: kategori bazli baslangic templateleri ve
   "kendiminkini olustur" havuzu.
5. Pre-publish quality skor: prompt skoru, tag yogunlugu ve karakter
   eslesme guvenini gosteren validator.

### 3.2.7 Library (4.7/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Saved/Created sekmesi ve owned edit entrypoint'i guclu;
  cogul secim, etiket/koleksiyon paylasimi ve dis import-export akislari
  sinirli.
- Stabilite acigi: save_count senkronu agent service cache'i ile
  yarisabilir; hizli ekle/cikar dongusunde gecici stale sayim olusabilir.
- UX acigi: Filtre/sort durumu URL'e yansimadigi icin paylasilamiyor; bos
  durum mesaji yeni kullanici icin kesif yonlendirmesi yapmiyor.

Yapilabilecekler (onceliklendirilmis):

1. URL-persisted filter/sort: paylasilabilir kutuphane goruntusu icin
   query state.
2. Batch operations: cogul secim ile remove, koleksiyona tasi, etiket
   atama.
3. Custom collections: kullanicinin manuel klasor/grup olusturup
   paylasabilmesi.
4. save_count idempotency: agent cache invalidation event'ini library
   tarafindan da dinle.
5. Empty-state nudges: yeni kullanicilar icin onerilen 3-5 agent'i empty
   state'te goster.

### 3.2.8 Wallet + Credits (4.3/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Nonce-signature auth, history, topup ve dev-grant uclari
  mevcut; multi-wallet, network switch UX, gas/treasury saglik panosu ve
  off-ramp akislari sinirli.
- Stabilite acigi: Imza reddi sonrasi nonce her zaman explicit invalidate
  edilmedigi icin tekrar denemelerde yarismaya yatkin; on-chain confirm
  gecikmelerinde optimistic UI ile reconcile farki belirsiz.
- UX acigi: "Bu islem icin kac kredi kesildi" gerekcesi action bazli
  degil; cuzdan baglama hatalarinda kullanici dilinde aciklama yetersiz.

Yapilabilecekler (onceliklendirilmis):

1. Per-action credit breakdown: history kayitlarina node/aksiyon etiketi
   ve maliyet aciklamasi ekle.
2. Nonce reuse korumasi: signature reject/timeout senaryosunda nonce'u
   explicit invalidate et.
3. Network guard: yanlis chainID'de uyari + tek tikla switch.
4. Confirmation timeline: pending/confirmed/finality kademelerini gorsel
   timeline ile sun.
5. Cuzdan hata sozlugu: yaygin MetaMask/Monad hatalarini insanca aciklayan
   inline rehber.

### 3.2.9 Leaderboard (4.1/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Top by saves/uses/creators var; zaman penceresi
  (haftalik/aylik), kategori bazli alt liste ve kullanici "rank takip" gibi
  segmentasyonlar yok.
- Stabilite acigi: use_count manipulasyonuna karsi rate-limit + bot
  heuristik katmani sinirli; sira degisikliklerinin invalidation politikasi
  netlestirilebilir.
- UX acigi: Listeye girip ne kazanildigi belirsiz; "neden buradayim"
  aciklamasi ve kisisel rank rozeti yok.

Yapilabilecekler (onceliklendirilmis):

1. Time window selector: 7g/30g/all-time gecisleri ve sira degisim oklari.
2. Anti-abuse: ayni cuzdan/IP icin use_count cooldown, sosyal sinyal
   agirligi.
3. Kategori bazli liderler: her kategori icin top-10 paneli.
4. "Sen buradasin" rozeti: kullanicinin kendi rankini ust segmente
   highlight et.
5. Lider odul mekanizmasi: haftalik kredi bonusu veya rozet KPI'sini izle.

### 3.2.10 Public Profile (4.0/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Public creator listing ve share var; takip sistemi,
  activity feed, basari rozetleri ve creator istatistik ozetleri eksik.
- Stabilite acigi: Username/wallet collision durumlari ve username
  degisikligi sonrasi eski URL davranisi netlestirilebilir.
- UX acigi: Mobil paylasim icin OG/Twitter card metadata yetersiz; profil
  disindaki ekranlardan profile derin link kullanim orani dusuk.

Yapilabilecekler (onceliklendirilmis):

1. Follow/Unfollow: takip iliskisi modeli, takip sayilari ve takip
   edilenlerin etkinlik akisi.
2. Activity feed: yeni agent, fork, kazanim olaylarini kronolojik goster.
3. Achievement rozetleri: ilk agent, ilk satis, top creator ve benzeri
   kilometre taslari.
4. OG/social metadata: paylasimda zengin onizleme, dinamik banner.
5. Username/identity guvenligi: collision policy ve rezerve kelime
   listesi.

### 3.2.11 Creator Dashboard (4.4/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Yonetim ve quick edit/full editor gecisleri var; ancak
  revenue/use insight grafikleri, A/B fiyat testi ve kohort retention
  dashboard'u yok.
- Stabilite acigi: Bulk regenerate-image kullaniminda quota/credit tuketim
  guvencesi belirsiz; fork sonrasi parent-child data tutarliligi izleme
  katmani zayif.
- UX acigi: Edit -> preview -> publish dongusunde context kaybi
  yasanabiliyor; secili agent uzerinde "neyi guncelledim" diff gorunur
  degil.

Yapilabilecekler (onceliklendirilmis):

1. Insight panosu: save/use/revenue trend grafikleri, kategori
   karsilastirmasi.
2. Bulk action quota: regenerate-image vb. islemler icin kalan kontenjan
   ve maliyet ozeti.
3. Diff preview: kaydetmeden once mevcut kart vs guncel hali yan yana
   goster.
4. Versioning + rollback: agent'in onceki surumune tek tikla donus.
5. Funnel KPI: edit-to-publish, publish-to-first-save donusum metriklerini
   takip et.

### 3.2.12 Guild (4.1/5.0)

Puan kirilan noktalar:

- Kapsam acigi: CRUD, member yonetimi ve compatibility analizi var; ancak
  detayli rol-permission matrisi, davet linki ile katilim ve guild-bazli
  workflow sablonlari sinirli.
- Stabilite acigi: Compatibility cache invalidation member ekle/cikar
  yarismasi altinda her zaman deterministik degil; rarity hesaplamasi
  degisken member setlerinde guncel kalmali.
- UX acigi: Compatibility skoru ham puan olarak goruluyor; "neden bu
  skor" aciklamasi ve oneri (eksik rol, dusuk sinerji) yok.

Yapilabilecekler (onceliklendirilmis):

1. Role-permission matrisi: member gorevleri, izin seviyeleri ve sahip
   aksiyonlari net ayrim.
2. Davet linki: tek kullanimlik veya zaman-sinirli katilim baglantilari.
3. Compatibility explainability: skoru olusturan unsurlari kirip
   kullaniciya goster.
4. Guild template: Guild Master suggest ciktisindan dogrudan onerilen
   kompozisyon sablonu.
5. Member event log: katilim/ayrilma/guncelleme olaylarinin guild
   detayinda tutulmasi.

### 3.2.13 Missions (4.5/5.0)

Puan kirilan noktalar:

- Kapsam acigi: CRUD, sync, expand ve mention destegi guclu; mission
  paylasimi/marketplace, scheduling ve mission template galerisi yok.
- Stabilite acigi: Batch sync sirasinda offline edit conflict cozumlemesi
  (last-write-wins disinda) eksik; expand endpoint'inde uzun yanitlarda
  timeout dayanikliligi zayif.
- UX acigi: Mention preview ve mission'in Legend node'una donusturulmesi
  gorsel olarak yeterince akisi yonlendirmiyor.

Yapilabilecekler (onceliklendirilmis):

1. Conflict-aware sync: revision id ile cakisma tespiti + birlestirme
   veya onceki surume donus modali.
2. Mission marketplace/import: paylasilabilir mission ID'leri ve kategori
   bazli kesif.
3. Scheduling: belirli aralik veya tetikleyiciye baglanan mission tekrar
   calismasi.
4. "Legend'e ekle" CTA: mission detayindan tek tikla node uretme bridge'i.
5. Mention preview kart: secilen agent/mission ozetini overlay olarak
   goster.

### 3.2.14 Settings / User Profile (3.9/5.0)

Puan kirilan noktalar:

- Kapsam acigi: Sadece temel profile patch var; bildirim tercihleri,
  gizlilik (profile gorunurlugu), tema, dil, developer mode ve API key
  ekrani yok.
- Stabilite acigi: PATCH sonrasi UI cache stale kalabiliyor; eszamanli
  ikinci sekmede yapilan degisikligin yansimasi belirgin degil.
- UX acigi: Tum alanlar tek bir liste seklinde; gruplandirma, arama ve
  gerekce metni eksik oldugu icin kullanicinin yapacagini bulmasi yavas.

Yapilabilecekler (onceliklendirilmis):

1. Bolumlendirme: Profile, Notifications, Privacy, Appearance, Developer
   ana baslik gruplari.
2. Bildirim merkezi: kanal/tip bazli ayar matrisi (e-posta/web/cuzdan
   event).
3. Tema/dil tercihi: light/dark/system + i18n iskeletinin
   etkinlestirilmesi.
4. PATCH sonrasi cache invalidation: kullanici profili ve store kart
   isimlerinde anlik yansima.
5. Developer/API key ekrani: read-only token, scope ve revoke aksiyonu.

### 3.2.15 Legend + Guild Master Uyumlu Kullanim Onerileri

Onerilen ortak kullanim akisi:

1. Problem tanimi Guild Master'da acilir ve hedef/cikti formati net yazilir.
2. Guild Master suggest sonucu, roller ve sorumluluklarla birlikte tek tikla
  Legend taslagina aktarilir.
3. Legend tarafinda node baglantilari ve mission adimlari kontrol edilip
  preflight validator'dan gecirilir.
4. Workflow execute edilir; node sonuclari ve kredi tuketimi history'ye yazilir.
5. Calisma ozeti tekrar Guild Master'a geri beslenir ve ikinci iterasyon
  iyilestirmesi otomatik onerilir.

Urun ve teknik oneriler:

1. "Legend'e Aktar" aksiyonu: Guild Master sonucunu dogrudan workflow node
  setine mapleyen bridge butonu ekle.
2. Ortak JSON sozlesmesi: Suggest ciktilarini `goal`, `roles`, `steps`,
  `risks`, `success_criteria` alanlariyla normalize et.
3. Role -> node tip esleme tablosu: Guild rol tanimlarini Legend node
  turlerine deterministik map et.
4. Post-run reflection: Legend execution ozetiyle Guild Master'da otomatik
  "neyi degistirelim" degerlendirme turu baslat.
5. Ortak KPI paneli: suggest-to-execute, first-run success,
  execute-to-rerun ve credit-per-success metriklerini birlikte izle.

Skor guncelleme kriteri:

- Store icin 4.8+ hedefi: query-state + fuzzy search + cache invalidation
  tamamlanip conversion metrikleri iyilesirse.
- Guild Master icin 4.6+ hedefi: explainability + structured output +
  action bridge canliya alinip acceptance metricleri yukselirse.
- Legend icin 4.9+ hedefi: resume/retry + preflight + observability paneli
  ile ilk denemede basari oranlari yukselirse.
- Agent Card icin 4.8+ hedefi: conflict-safe autosave + preset + compare
  akislarinin benimsenmesi artarsa.

---

## 4. Frontend Mimarisi Detaylari

## 4.1 Router ve App Shell

Temel route kaynagi: `agent_store/lib/app/router.dart`

Onemli noktalar:

- Tum ana ekranlar ShellRoute altinda cagrilir.
- Invalid route param durumunda guvenli fallback (`ctx.go('/')`).
- Uygulama capinda klavye kisayollari tanimlidir:
  - Alt+S, Alt+L, Alt+C, Alt+G, Alt+W
  - / ile store search focus
  - Escape ve Alt+Backspace navigation

## 4.2 State Yonetimi

Genel pattern:

- GetX controller + singleton servisler
- Screen tarafinda ince bir StatefulWidget shell
- Data state controller'da, lifecycle state (focus, tab controller) ekranda

## 4.3 API Erisim Katmani

Temel dosya: `agent_store/lib/shared/services/api_service.dart`

Ozellikler:

- JWT saklama (`LocalKvStore`)
- In-memory TTL cache
- Retry helper (exponential backoff)
- Feature bazli typed helper fonksiyonlari

## 4.4 Responsive ve UX Patternleri

- Ortak breakpoint stratejisi (`AppBreakpoints`)
- Desktop/tablet/mobile ayri layout path'leri
- Skeleton loading, empty state, error state komponentleri
- Shared page header, confirm dialog, badge patternleri

---

## 5. Feature Bazli Derin Inceleme

Bu bolumde her ozellik icin kullanici akis, backend etkisi ve kritik notlar
verilir.

## 5.1 Store / Discovery

Frontend:

- `store_screen.dart`
- `agent_card.dart`, `category_sidebar.dart`, `filter_panel.dart`, `trending_row.dart`

Kabiliyetler:

- Arama, kategori, sort, sayfalama
- Discovery section + trending satiri
- Recent searches
- Agent kaydetme (library)

Backend baglantilar:

- GET `/api/v1/agents`
- GET `/api/v1/agents/categories`
- GET `/api/v1/agents/trending`
- POST `/api/v1/user/library/:id`

## 5.2 Agent Detail

Frontend:

- `agent_detail_screen.dart`
- mini chat, radar chart, export, rating widgetleri

Kabiliyetler:

- Agent metadata + character sunumu
- Library toggle
- Fork
- Trial token ureterek one-time script denemesi
- Rating gonderme/gorme
- On-chain satin alma (wallet transaction + backend record)

Backend baglantilar:

- GET `/api/v1/agents/:id`
- POST `/api/v1/agents/:id/chat`
- POST `/api/v1/agents/:id/fork`
- POST `/api/v1/agents/:id/trial`
- GET `/api/v1/trial/:token/script`
- POST `/api/v1/agents/:id/rate`
- GET `/api/v1/agents/:id/ratings`
- POST `/api/v1/agents/:id/purchase`
- GET `/api/v1/agents/:id/purchase-status`

## 5.3 Create Agent

Frontend:

- `create_agent_screen.dart`

Kabiliyetler:

- Multi-step form (basic info -> prompt -> review)
- Prompt uzunluk/validasyon
- Character preview
- Credit kontrolu

Backend baglantisi:

- POST `/api/v1/agents`

Arka planda olanlar:

- Analyze/profile/score/avatar pipeline cagrilari
- DB kaydi + image data alanlari

## 5.4 Library

Frontend:

- `library_screen.dart`

Kabiliyetler:

- Saved / Created sekmeleri
- Search, sort, category filter
- Collection mantigi
- Owned card icin edit entrypoint

Backend baglantilar:

- GET `/api/v1/user/library`
- POST `/api/v1/user/library/:id`
- DELETE `/api/v1/user/library/:id`

## 5.5 Wallet + Credits

Frontend:

- `wallet_connect_screen.dart`
- `credit_history_screen.dart`

Kabiliyetler:

- Wallet connect ve nonce-signature auth
- Credit bakiye/transaction goruntuleme
- Credit topup/dev-grant endpoint entegrasyonu

Backend baglantilar:

- GET `/api/v1/auth/nonce/:wallet`
- POST `/api/v1/auth/verify`
- GET `/api/v1/user/credits`
- GET `/api/v1/user/credits/history`
- POST `/api/v1/user/credits/topup`
- POST `/api/v1/user/credits/dev-grant`

## 5.6 Leaderboard

Frontend:

- `leaderboard_screen.dart`

Kabiliyetler:

- Top by saves
- Top by uses
- Top creators

Backend:

- GET `/api/v1/leaderboard`

## 5.7 Public Profile

Frontend:

- `public_profile_screen.dart`

Kabiliyetler:

- Public creator verisi
- Created agents listesi
- Search/sort
- Share profile

Backend:

- GET `/api/v1/users/:wallet`

## 5.8 Creator Dashboard

Frontend:

- `creator_dashboard_screen.dart`

Kabiliyetler:

- Creator odakli agent yonetimi
- Search + istatistik paneli
- Quick edit + full card editor gecisi

Backend etkisi:

- Agent listing/filter
- Update/fork/regenerate-image aksiyonlari

## 5.9 Guild

Frontend:

- `guild_screen.dart`
- `guild_create_screen.dart`
- `guild_detail_screen.dart`

Kabiliyetler:

- Guild olusturma
- Member ekleme/cikarma
- Join/leave
- Compatibility analizi

Backend:

- GET `/api/v1/guilds`
- GET `/api/v1/guilds/:id`
- POST `/api/v1/guilds`
- POST `/api/v1/guilds/:id/members`
- DELETE `/api/v1/guilds/:id/members/:agentId`
- POST `/api/v1/guilds/:id/join`
- DELETE `/api/v1/guilds/:id/join`
- GET `/api/v1/guilds/:id/compatibility`

## 5.10 Guild Master

Frontend:

- `guild_master_screen.dart`
- mention composer tabanli team-chat

Kabiliyetler:

- Problem statement'ten team suggest
- Multi-agent team chat
- Mention sectioning (library/store ayrimi)

Backend:

- POST `/api/v1/guild-master/suggest`
- POST `/api/v1/guild-master/chat`

## 5.11 Missions

Frontend:

- `missions_screen.dart`

Kabiliyetler:

- Mission CRUD
- Kategori/search
- Duplicate/edit/delete
- Mention ile diger ekranlarda kullanilabilir prompt snippetleri

Backend:

- GET `/api/v1/user/missions`
- POST `/api/v1/user/missions`
- DELETE `/api/v1/user/missions/:id`
- POST `/api/v1/user/missions/sync`
- POST `/api/v1/user/missions/expand`

## 5.12 Legend Workflow

Frontend:

- `legend_screen.dart`
- export dialog, onboarding, templates

Kabiliyetler:

- Canvas tabanli DAG workflow editor
- Node tipleri: start, end, mission, agent, guild
- Undo/redo
- Template secimi
- Execution history, rerun
- Export: JSON, CLAUDE.md, agent md vb.

Backend:

- GET `/api/v1/user/legend/workflows`
- POST `/api/v1/user/legend/workflows`
- DELETE `/api/v1/user/legend/workflows/:id`
- POST `/api/v1/user/legend/workflows/sync`
- POST `/api/v1/user/legend/workflows/:id/execute`
- GET `/api/v1/user/legend/executions`
- GET `/api/v1/user/legend/executions/:execId`

Kritik teknik not:

- Execute tarafi DAG validasyonu + topological sort yapar.
- Credit maliyeti node bazli hesaplanir.
- Claude engine secilirse model bazli credit cost uygulanir:
  - haiku: 1
  - sonnet: 3
  - opus: 10

## 5.13 Card Editor

Frontend:

- `card_editor_screen.dart`
- `card_editor_controller.dart`
- `editor_toolbar.dart`, `editor_preview_panel.dart`

Kabiliyetler:

- Split-view canli edit + canli kart preview
- Debounced autosave
- Undo/redo history
- JSON/PNG export
- Clone ve save-kisa yollari (Ctrl+S/Z/Y)

Backend:

- PUT `/api/v1/agents/:id`

Whitelist patch alanlari:

- title, description, prompt, category, subclass, tags
- price, card_version, service_description
- profile_mood, profile_role_purpose, traits

Not:

- Stats manuel patch edilmez; analysis pipeline sahipligindedir.

## 5.14 Settings

Frontend:

- `settings_screen.dart`

Kabiliyetler:

- Kullanici profilini guncelleme

Backend:

- GET/PATCH `/api/v1/user/profile`

---

## 6. Backend Servis Mimarisi Derin Dalis

## 6.1 Gateway

Ana dosyalar:

- `backend/cmd/gateway/main.go`
- `backend/services/gateway/proxy.go`

Gorevler:

- CORS middleware uygulama
- JWT extractor (opsiyonel)
- `X-Wallet-Address` propagation
- Prefix tabanli reverse proxy
- `/health` ve `/health/full`

Routing onceligi (`proxy.go`):

- `/api/v1/auth` -> authsvc
- `/api/v1/user/missions`, `/api/v1/user/legend` -> workspacesvc
- `/api/v1/guilds`, `/api/v1/guild-master` -> guildsvc
- Diger `/api/v1/user`, `/agents`, `/trial`, `/users`, `/leaderboard`, `/images` -> agentsvc

Ek not:

- Gateway icinde dev fallback mock auth endpointleri mevcut.

## 6.2 Auth Service

Ana dosyalar:

- `backend/services/auth/router.go`
- `backend/services/auth/service.go`

Akis:

- Nonce uret
- Wallet signature verify
- JWT generate
- Basarili verify sonrasi nonce rotate (replay engeli)

Rate limit:

- Auth endpointlerinde 20 req / dakika

## 6.3 Agent Service

Ana dosyalar:

- `backend/services/agent/router.go`
- `backend/services/agent/service.go`
- `backend/services/agent/handler.go`

Kabiliyetler:

- Agent listeleme (filter + sort + pagination)
- Agent create/update/regenerate/fork/chat
- Trial token + script
- Purchase + purchase status + price update
- Rating
- Library ve profile endpointleri
- Credit endpointleri
- Leaderboard/public profile

Rate limit:

- Create / regenerate: 10/saat (wallet)
- Fork: 10/saat (wallet)
- Chat: 30/dakika (wallet)

Performans notlari:

- Kategori/liste gibi endpointlerde cache kullanimi
- Image endpointte disk fast-path + DB fallback lazy hydrate

Guvenlik notlari:

- `images/*` endpointte path traversal kontrolu
- Request body limit 2MB

## 6.4 Guild Service

Ana dosyalar:

- `backend/services/guild/router.go`
- `backend/services/guild/service.go`
- `backend/services/guild/handler.go`

Kabiliyetler:

- Guild CRUD benzeri akislar
- Member role belirleme
- Guild rarity hesaplama
- Compatibility check
- Guild master suggest + team chat

Rate limit:

- Guild master endpointlerinde 20/dakika (wallet)

## 6.5 Workspace Service

Ana dosyalar:

- `backend/services/workspace/router.go`
- `backend/services/workspace/legend_service.go`

Kabiliyetler:

- Mission persistence + batch sync
- Legend workflow persistence + batch sync
- DAG execution + execution history

Rate limit:

- Workflow execute endpointinde 20/dakika (wallet)

## 6.6 AI Pipeline Service

Ana dosya:

- `backend/services/aipipeline/router.go`

Internal endpoint seti:

- POST `/internal/analyze`
- POST `/internal/profile`
- POST `/internal/score`
- POST `/internal/avatar`
- POST `/internal/chat`
- POST `/internal/compatibility`
- POST `/internal/character`

Bu servis frontend'e dogrudan expose edilmez.

---

## 7. Veri Modeli ve Semasi

Model dosyalari: `backend/pkg/models/*.go`

## 7.1 Ana Tablolar

| Tablo                 | Aciklama                                   |
| --------------------- | ------------------------------------------ |
| users                 | Wallet identity + nonce + credits + profil |
| agents                | Ana agent kaydi                            |
| library_entries       | Kullanici saved agent iliskisi             |
| purchased_agents      | On-chain satin alma kaydi                  |
| credit_transactions   | Kredi hareket kaydi                        |
| agent_ratings         | Agent puan/yorum                           |
| guilds                | Guild kaydi                                |
| guild_members         | Guild-agent iliskisi                       |
| user_missions         | Kullanici mission kayitlari                |
| user_legend_workflows | Kullanici workflow kayitlari               |
| workflow_executions   | Workflow run history                       |
| trial_uses            | One-time trial kullanim kaydi              |
| trial_tokens          | Trial script token kaydi                   |

## 7.2 Onemli Alanlar

`agents`:

- prompt (text)
- character_data (jsonb)
- rarity
- tags (text[])
- generated_image / image_url
- save_count / use_count
- price / prompt_score / service_description / card_version

`users`:

- wallet_address (PK)
- nonce
- credits
- username / bio

`workflow_executions`:

- status
- input_message / final_output
- node_results (jsonb)
- total_nodes / completed_nodes / credits_used

---

## 8. API Referansi (Tam)

Base URL: `http://localhost:8080/api/v1`

## 8.1 Auth

- GET `/auth/nonce/:wallet`
- POST `/auth/verify`

## 8.2 Agents

- GET `/agents`
- GET `/agents/trending`
- GET `/agents/categories`
- POST `/agents/batch`
- GET `/agents/:id`
- POST `/agents`
- PUT `/agents/:id`
- POST `/agents/:id/regenerate-image`
- POST `/agents/:id/fork`
- POST `/agents/:id/chat`
- POST `/agents/:id/trial`
- POST `/agents/:id/purchase`
- GET `/agents/:id/purchase-status`
- PUT `/agents/:id/price`
- POST `/agents/:id/rate`
- GET `/agents/:id/ratings`

## 8.3 User

- GET `/user/library`
- POST `/user/library/:id`
- DELETE `/user/library/:id`
- GET `/user/credits`
- GET `/user/credits/history`
- POST `/user/credits/topup`
- POST `/user/credits/dev-grant`
- GET `/user/profile`
- PATCH `/user/profile`
- GET `/user/missions`
- POST `/user/missions`
- DELETE `/user/missions/:id`
- POST `/user/missions/sync`
- POST `/user/missions/expand`
- GET `/user/legend/workflows`
- POST `/user/legend/workflows`
- DELETE `/user/legend/workflows/:id`
- POST `/user/legend/workflows/sync`
- POST `/user/legend/workflows/:id/execute`
- GET `/user/legend/executions`
- GET `/user/legend/executions/:execId`

## 8.4 Guild

- GET `/guilds`
- GET `/guilds/:id`
- POST `/guilds`
- POST `/guilds/:id/members`
- DELETE `/guilds/:id/members/:agentId`
- POST `/guilds/:id/join`
- DELETE `/guilds/:id/join`
- GET `/guilds/:id/compatibility`
- POST `/guild-master/suggest`
- POST `/guild-master/chat`

## 8.5 Public

- GET `/trial/:token/script`
- GET `/users/:wallet`
- GET `/leaderboard`
- GET `/images/*filepath`

---

## 9. Environment ve Config Detaylari

Ana config kaynagi: `backend/pkg/config/config.go`

## 9.1 Core Env Variables

- `PORT`
- `JWT_SECRET`
- `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_SSLMODE`
- `DATABASE_URL` (ve alternateleri)
- `ALLOWED_ORIGINS`

## 9.2 AI ve Blockchain

- `CLAUDE_API_KEY`
- `GEMINI_API_KEY`
- `CLIPDROP_API_KEY`
- `MONAD_RPC_URL`
- `CREDITS_CONTRACT_ADDRESS`
- `TREASURY_WALLET`

## 9.3 Inter-Service URL Overrides

- `AUTH_SERVICE_URL`
- `AGENT_SERVICE_URL`
- `AIPIPELINE_SERVICE_URL`
- `GUILD_SERVICE_URL`
- `WORKSPACE_SERVICE_URL`

## 9.4 Production Guard

- Production ortamda `JWT_SECRET` default degerdeyse servis fail-fast ile acilmaz.

---

## 10. Calistirma Modlari ve Komutlar

## 10.1 Full Docker (Prod-benzeri)

```bash
docker compose up -d --build
```

Kontrol:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/health/full
```

## 10.2 Hybrid (backend docker + flutter hot reload)

```bash
docker compose up -d postgres redis gateway authsvc agentsvc aipipelinesvc guildsvc workspacesvc
docker compose stop frontend

cd agent_store
flutter run -d chrome
```

## 10.3 Monolith backend (opsiyonel)

Root `Dockerfile`, `backend/cmd/monolith` binary'sini build eder.

---

## 11. Test ve Kalite Kapisi

## 11.1 CI Pipeline

Dosya: `.github/workflows/ci.yml`

Calisan isler:

- Backend: `go vet`, `go test -race -coverprofile=coverage.out`
- Frontend: `flutter analyze --no-fatal-infos`, `flutter test`

## 11.2 Lokal Test Komutlari

Backend:

```bash
cd backend
go vet ./...
go test ./... -race -coverprofile=coverage.out -covermode=atomic
```

Frontend:

```bash
cd agent_store
flutter pub get
flutter analyze --no-fatal-infos
flutter test --reporter expanded
```

Contracts:

```bash
cd contracts
npm install
npm run compile
npm run test
```

## 11.3 Mevcut Quality Snapshot (v3.6)

- Backend test: 40
- Flutter test: 43
- Toplam: 83

---

## 12. Guvenlik Kontrolleri

Bu bolum mevcut kodda aktif olan guvenlik bariyerlerini listeler.

## 12.1 Auth ve Session

- Nonce + personal_sign tabanli wallet dogrulama
- Basarili verify sonrasi nonce rotate
- JWT expiration claim

## 12.2 Gateway ve Internal Trust Boundary

- JWT extractor gateway seviyesinde
- Internal servis auth'u `X-Wallet-Address` header'i ile
- Bu header dis dunyaya expose edilmeden gateway tarafinda set edilir

## 12.3 API Surface Guards

- Request body max 2MB (gateway ve servislerde)
- DB readiness middleware (hazir degilse 503)
- CORS allowlist + dev localhost wildcard kontrolu
- Rate limiter (auth, create, fork, chat, guild-master, execute)

## 12.4 Input/Path Guvenligi

- Image endpointte `..` traversal bloklanir
- Handler seviyesinde alan validasyonlari (title, prompt length vb.)

## 12.5 Secret Hygiene

- `.env` dosyasi commit edilmemelidir
- Production'da default DB/JWT degerleri kullanilmamalidir

---

## 13. Blockchain ve Ekonomi Akislari

## 13.1 Contracts

- `AgentStoreCredits.sol`
- `AgentRegistry.sol`

## 13.2 Hardhat Konfig

- Solidity: 0.8.24
- Network:
  - localhost (31337)
  - monad_testnet (10143)

## 13.3 Deploy Komutlari

```bash
cd contracts
npm run compile
npm run test
npm run deploy:local
npm run deploy
```

Deploy script ciktisi:

- `deployments.json` guncellenir
- `.env` icin gerekli contract address degerleri terminale yazdirilir

## 13.4 Satin Alma ve Kredi Mantigi

- On-chain transaction wallet tarafinda yapilir
- Backend tx hash'i kaydeder ve `purchased_agents` tablosuna isler
- Credit hareketleri `credit_transactions` tablosunda izlenir

---

## 14. Deploy Topolojileri

## 14.1 Lokal

- docker-compose ile tum servisler

## 14.2 Frontend Production

- Flutter web build artefakti: `agent_store/build/web`
- Vercel rewrite/headers: `vercel.json`

## 14.3 Backend Production

Iki model:

1. Microservice deploy
2. Monolith deploy (`Dockerfile` -> `cmd/monolith`)

`railway.toml` healthcheck path: `/health`

---

## 15. Sorun Giderme Playbook

| Belirti                  | Muhtemel Sebep                     | Kontrol / Cozum                                        |
| ------------------------ | ---------------------------------- | ------------------------------------------------------ |
| 401 Unauthorized         | JWT yok/expired                    | Authorization header + auth verify akisi               |
| 502 Bad Gateway          | Downstream servis ulasilamiyor     | `docker compose logs -f gateway`, `depends_on` zinciri |
| CORS preflight fail      | Origin allowlist disinda           | `ALLOWED_ORIGINS` + env mode kontrolu                  |
| Missions/Legend 502      | workspace service down             | `workspacesvc` health + gateway route                  |
| Agent image 404          | Diskte dosya yok                   | DB fallback kontrolu, lazy hydrate loglari             |
| Legend execute fail      | DAG invalid/cycle/credits yetersiz | Workflow validasyonu, credits kontrolu                 |
| Flutter stale/null error | State mismatch/hot reload limiti   | Browser console + hot restart                          |

---

## 16. Gelistirici Rehberi - Yeni Ozellik Ekleme

## 16.1 Frontend yeni feature adimlari

1. `agent_store/lib/features/<feature>/` altinda ekran ve widgetlari olustur.
2. Gerekirse controller ekle.
3. Router'a route bagla.
4. API call gerekiyorsa `ApiService`e typed helper ekle.
5. Empty/loading/error state patternini uygula.
6. Responsive davranisi desktop+mobile test et.

## 16.2 Backend yeni endpoint adimlari

1. Uygun serviste handler + service metodu ekle.
2. Router'a endpointi bagla.
3. Gateway prefix routing kurallarina gerekiyorsa yeni path ekle.
4. Input validation + auth + rate-limit gereksinimlerini belirle.
5. Test ekle (unit/service seviyesinde).

## 16.3 Data migration yaklasimi

- GORM AutoMigrate kullanimina uygun model degisikligi yap.
- Backward compatible JSON alan merge stratejisi izle.

---

## 17. Bilinen Kisitlar / Dikkat Noktalari

- `features/explore` su an bos placeholder.
- AI pipeline key'leri yoksa ilgili endpointler beklenen kaliteyi vermez.
- Blockchain akislarinda dogru network/chain baglantisi zorunludur.
- Gateway icindeki mock auth fallback sadece dev rahatligi icindir.

---

## 18. Release Checklist

Pre-merge:

- Frontend analyze + test temiz
- Backend vet + race test temiz
- Yeni endpoint icin auth/rate-limit kontrolu
- Dokuman guncellemesi (README/GUIDE/DEVELOPMENT gerekiyorsa)

Pre-deploy:

- Env degerleri production-safe
- JWT_SECRET guclu ve benzersiz
- Contract addressler dogru
- Health endpointleri yesil
- CORS origin listesi dogru

Post-deploy:

- `/health` ve `/health/full` kontrolu
- Kritik akis smoke test:
  - wallet login
  - list/create/fork agent
  - library save/remove
  - mission save + legend execute
  - guild suggest/chat

---

## 19. Hizli Dosya Haritasi

Frontend kritik:

- `agent_store/lib/app/router.dart`
- `agent_store/lib/shared/services/api_service.dart`
- `agent_store/lib/features/...`

Backend kritik:

- `backend/cmd/gateway/main.go`
- `backend/services/gateway/proxy.go`
- `backend/services/auth/*`
- `backend/services/agent/*`
- `backend/services/guild/*`
- `backend/services/workspace/*`
- `backend/services/aipipeline/*`
- `backend/pkg/models/*`
- `backend/pkg/config/config.go`

Ops/Dev kritik:

- `docker-compose.yml`
- `.env.example`
- `.github/workflows/ci.yml`
- `DEVELOPMENT.md`
- `README.md`
- `CLAUDE.md`

---

Bu guide, proje buyudukce canli tutulmalidir. Ozellikle yeni endpoint,
yeni ekran, schema degisikligi veya deploy topolojisi degisikliklerinde bu
dosya ayni PR icinde guncellenmelidir.
