// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class LocalKvStore {
  LocalKvStore._();

  static final LocalKvStore instance = LocalKvStore._();

  Future<String?> getString(String key) async => html.window.localStorage[key];

  Future<void> setString(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  Future<void> remove(String key) async {
    html.window.localStorage.remove(key);
  }

  Future<void> clear() async {
    html.window.localStorage.clear();
  }
}
