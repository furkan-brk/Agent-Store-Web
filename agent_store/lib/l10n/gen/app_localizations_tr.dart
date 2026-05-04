// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsSubtitle => 'Deneyiminizi özelleştirin';

  @override
  String get profileSection => 'Profil';

  @override
  String get notificationsSection => 'Bildirimler';

  @override
  String get appearanceSection => 'Görünüm';

  @override
  String get developerSection => 'Geliştirici';

  @override
  String get themeMode => 'Tema Modu';

  @override
  String get themeDark => 'Koyu';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeSystem => 'Sistem Varsayılanı';

  @override
  String get language => 'Dil';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get createApiKey => 'API Anahtarı Oluştur';

  @override
  String get name => 'İsim';

  @override
  String get scopes => 'Yetkiler';

  @override
  String get revoke => 'İptal Et';

  @override
  String get revokeApiKeyTitle => 'API Anahtarını İptal Et';

  @override
  String get revokeApiKeyMessage =>
      'Bu anahtar kalıcı olarak iptal edilecek. Kullanan tüm uygulamalar çalışmayı durduracak.';

  @override
  String get saveKeyWarning =>
      'Bu anahtarı şimdi kaydedin — bir daha göremezsiniz.';

  @override
  String get copy => 'Kopyala';

  @override
  String get done => 'Tamam';

  @override
  String get lastUsed => 'Son kullanım';

  @override
  String get neverUsed => 'Hiç kullanılmadı';

  @override
  String get noApiKeys => 'Henüz API anahtarı yok';

  @override
  String get noApiKeysSubtitle =>
      'Harici araçlardan kimlik doğrulamak için bir tane oluşturun.';

  @override
  String get scopeReadAgents => 'Ajanları Oku';

  @override
  String get scopeWriteAgents => 'Ajanlara Yaz';

  @override
  String get scopeExecuteLegend => 'Legend Çalıştır';

  @override
  String get notificationPreferences => 'Tercihler';

  @override
  String get notificationInbox => 'Gelen Kutusu';

  @override
  String get markAllAsRead => 'Tümünü okundu işaretle';

  @override
  String get noNotifications => 'Henüz bildirim yok';

  @override
  String get noNotificationsSubtitle =>
      'Ajanlarınızdan ve loncalarınızdan gelen güncellemeleri burada göreceksiniz.';

  @override
  String get channelWeb => 'Web';

  @override
  String get channelEmail => 'E-posta';

  @override
  String get typeSocial => 'Sosyal';

  @override
  String get typeSystem => 'Sistem';

  @override
  String get typeCredit => 'Kredi';
}
