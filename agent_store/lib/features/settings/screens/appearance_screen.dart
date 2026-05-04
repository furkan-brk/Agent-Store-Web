// lib/features/settings/screens/appearance_screen.dart
//
// Settings → Appearance: theme mode (dark / light / system) + language
// (English / Türkçe). Both controls bind directly to the GetX
// controllers registered in main.dart, so changes are persisted via
// SharedPreferences and applied to MaterialApp on the next frame.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../../../controllers/locale_controller.dart';
import '../../../controllers/theme_controller.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/settings_sidebar.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final themeCtrl = Get.find<ThemeController>();
    final localeCtrl = Get.find<LocaleController>();

    return SettingsLayout(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.palette_outlined,
            title: l.appearanceSection,
            subtitle: l.settingsSubtitle,
          ),
          const SizedBox(height: 28),

          // ── Theme card ────────────────────────────────────────────────
          _SectionCard(
            title: l.themeMode,
            child: Obx(() => Column(children: [
              _ThemeRadio(
                label: l.themeDark,
                icon: Icons.dark_mode_outlined,
                value: ThemeMode.dark,
                groupValue: themeCtrl.mode.value,
                onChanged: themeCtrl.setMode,
              ),
              _ThemeRadio(
                label: l.themeLight,
                icon: Icons.light_mode_outlined,
                value: ThemeMode.light,
                groupValue: themeCtrl.mode.value,
                onChanged: themeCtrl.setMode,
              ),
              _ThemeRadio(
                label: l.themeSystem,
                icon: Icons.brightness_auto_outlined,
                value: ThemeMode.system,
                groupValue: themeCtrl.mode.value,
                onChanged: themeCtrl.setMode,
              ),
            ])),
          ),

          const SizedBox(height: 16),

          // ── Language card ─────────────────────────────────────────────
          _SectionCard(
            title: l.language,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Obx(() {
                final code = localeCtrl.current.value.languageCode;
                return Row(children: [
                  const Icon(Icons.translate, color: AppTheme.textM, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.language,
                      style: const TextStyle(
                        color: AppTheme.textH,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.card2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: code,
                        dropdownColor: AppTheme.card2,
                        style: const TextStyle(
                          color: AppTheme.textH,
                          fontSize: 13,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppTheme.textM,
                          size: 20,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(l.languageEnglish),
                          ),
                          DropdownMenuItem(
                            value: 'tr',
                            child: Text(l.languageTurkish),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) localeCtrl.setLocale(Locale(v));
                        },
                      ),
                    ),
                  ),
                ]);
              }),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textM,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Divider(color: AppTheme.border, height: 1),
          child,
        ],
      ),
    );
  }
}

class _ThemeRadio extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeRadio({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(icon, color: selected ? AppTheme.primary : AppTheme.textM, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.textH : AppTheme.textB,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Radio<ThemeMode>(
            value: value,
            groupValue: groupValue,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            activeColor: AppTheme.primary,
          ),
        ]),
      ),
    );
  }
}
