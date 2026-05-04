// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Customize your experience';

  @override
  String get profileSection => 'Profile';

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get developerSection => 'Developer';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System Default';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get createApiKey => 'Create API Key';

  @override
  String get name => 'Name';

  @override
  String get scopes => 'Scopes';

  @override
  String get revoke => 'Revoke';

  @override
  String get revokeApiKeyTitle => 'Revoke API Key';

  @override
  String get revokeApiKeyMessage =>
      'This will permanently invalidate this key. Any application using it will stop working.';

  @override
  String get saveKeyWarning => 'Save this key now — you won\'t see it again.';

  @override
  String get copy => 'Copy';

  @override
  String get done => 'Done';

  @override
  String get lastUsed => 'Last used';

  @override
  String get neverUsed => 'Never used';

  @override
  String get noApiKeys => 'No API keys yet';

  @override
  String get noApiKeysSubtitle =>
      'Create one to authenticate from external tools.';

  @override
  String get scopeReadAgents => 'Read Agents';

  @override
  String get scopeWriteAgents => 'Write Agents';

  @override
  String get scopeExecuteLegend => 'Execute Legend';

  @override
  String get notificationPreferences => 'Preferences';

  @override
  String get notificationInbox => 'Inbox';

  @override
  String get markAllAsRead => 'Mark all as read';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get noNotificationsSubtitle =>
      'You\'ll see updates from your agents and guilds here.';

  @override
  String get channelWeb => 'Web';

  @override
  String get channelEmail => 'Email';

  @override
  String get typeSocial => 'Social';

  @override
  String get typeSystem => 'System';

  @override
  String get typeCredit => 'Credit';
}
