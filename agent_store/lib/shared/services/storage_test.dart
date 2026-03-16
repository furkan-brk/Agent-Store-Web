import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class StorageTest {
  static Future<void> testLocalStorage() async {
    developer.log('[StorageTest] Starting storage test...');
    
    try {
      // Test 1: Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();
      developer.log('[StorageTest] ✓ SharedPreferences.getInstance() succeeded');

      // Test 2: Write a test value
      const testKey = '__test_storage_key__';
      const testValue = 'test_value_12345';
      
      await prefs.setString(testKey, testValue);
      developer.log('[StorageTest] ✓ prefs.setString() succeeded');

      // Test 3: Read it back immediately
      final retrieved = prefs.getString(testKey);
      if (retrieved == testValue) {
        developer.log('[StorageTest] ✓ Value read back correctly: $retrieved');
      } else {
        developer.log('[StorageTest] ✗ Value mismatch. Expected: $testValue, Got: $retrieved');
      }

      // Test 4: List all keys
      final allKeys = prefs.getKeys();
      developer.log('[StorageTest] ✓ Available keys: ${allKeys.length}. Sample keys: ${allKeys.take(5).toList()}');

      // Test 5: Clean up
      await prefs.remove(testKey);
      developer.log('[StorageTest] ✓ Cleanup succeeded');

    } catch (e, st) {
      developer.log('[StorageTest] ✗ ERROR: $e\nStackTrace: $st', error: e, stackTrace: st);
    }
  }
}
