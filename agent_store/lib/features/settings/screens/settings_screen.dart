// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ── helpers ────────────────────────────────────────────────────────────────

  static const _bg = Color(0xFF181910);
  static const _cardBg = Color(0xFF2A2B1E);
  static const _accent = Color(0xFF81231E);

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: _accent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _card(List<Widget> children) => Card(
        color: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
        child: Column(children: children),
      );

  Widget _infoTile(String title, String subtitle, {IconData? leading}) =>
      ListTile(
        leading: leading != null
            ? Icon(leading, color: const Color(0xFF9E8F72), size: 20)
            : null,
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        trailing: Text(subtitle,
            style:
                const TextStyle(color: Color(0xFF9E8F72), fontSize: 13)),
        dense: true,
      );

  Widget _iconTile(String title, IconData icon) => ListTile(
        leading: Icon(icon, color: const Color(0xFF9E8F72), size: 20),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        dense: true,
      );

  Future<void> _clearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Clear All Data',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear all locally stored preferences and cached data. '
          'Your on-chain data will not be affected.',
          style: TextStyle(color: Color(0xFF9E8F72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF9E8F72))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear',
                style: TextStyle(color: Color(0xFF81231E))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Clear localStorage via dart:html
    html.window.localStorage.clear();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All data cleared'),
        backgroundColor: Color(0xFF81231E),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // ── App Info ──────────────────────────────────────────────────────
          _sectionHeader('APP INFO'),
          _card([
            _infoTile('App Name', 'Agent Store'),
            const Divider(color: Color(0xFF3D3E2A), height: 1, indent: 16),
            _infoTile('Version', '1.0.0'),
            const Divider(color: Color(0xFF3D3E2A), height: 1, indent: 16),
            _infoTile('Network', 'Monad Testnet (ChainID: 10143)',
                leading: Icons.wifi_outlined),
          ]),

          // ── Appearance ────────────────────────────────────────────────────
          _sectionHeader('APPEARANCE'),
          _card([
            const SwitchListTile(
              value: true,
              onChanged: null, // coming soon — always dark
              activeThumbColor: _accent,
              title: Text('Dark Mode',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text('Coming soon',
                  style:
                      TextStyle(color: Color(0xFF9E8F72), fontSize: 12)),
              dense: true,
            ),
          ]),

          // ── About ─────────────────────────────────────────────────────────
          _sectionHeader('ABOUT'),
          _card([
            _iconTile('Built with Flutter & Go', Icons.code),
            const Divider(color: Color(0xFF3D3E2A), height: 1, indent: 16),
            _iconTile('Powered by Claude AI & Gemini', Icons.auto_awesome),
            const Divider(color: Color(0xFF3D3E2A), height: 1, indent: 16),
            _iconTile('Blockchain: Monad Testnet', Icons.link),
          ]),

          // ── Danger Zone ───────────────────────────────────────────────────
          _sectionHeader('DANGER ZONE'),
          _card([
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFF81231E), size: 20),
              title: TextButton(
                onPressed: () => _clearAllData(context),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Clear All Data',
                  style: TextStyle(
                      color: Color(0xFF81231E),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
              dense: true,
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
