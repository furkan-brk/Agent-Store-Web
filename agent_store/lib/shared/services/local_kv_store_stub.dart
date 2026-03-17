class LocalKvStore {
  LocalKvStore._();

  static final LocalKvStore instance = LocalKvStore._();

  Future<String?> getString(String key) async => null;

  Future<void> setString(String key, String value) async {}

  Future<void> remove(String key) async {}

  Future<void> clear() async {}
}
