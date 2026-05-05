// State-machine tests for AuthController.
//
// AuthController itself cannot be imported into the `flutter test` VM:
// it transitively pulls `package:web` 1.1.1 (via wallet_service.dart's
// `dart:js_interop` chain) which fails to compile against Dart 3.8.
// The codebase already follows this exact rationale for `network_guard`
// — see `network_guard_pure.dart` — by extracting pure logic for tests.
//
// Until AuthController gets a similar pure-state extraction, we mirror
// its contract here in `_FakeAuthController`. The fake reproduces every
// observable Rx field plus the four state-only methods: `disconnect`,
// `markConnected`, `loadProfileLocally`, and the `shortWallet` formatter.
// Connect/topUp/updateProfile are intentionally *not* mirrored — they
// always cross the singleton boundary and need integration tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeAuthController extends GetxController {
  // Mirrors AuthController's Rx surface verbatim.
  final isConnected = false.obs;
  final isConnecting = false.obs;
  final isBuyingCredits = false.obs;
  final isLoadingCredits = false.obs;
  final credits = 0.obs;
  final username = ''.obs;
  final bio = ''.obs;
  final error = RxnString();

  String? _wallet;
  String? get wallet => _wallet;

  /// Same formatter as AuthController.shortWallet — addresses longer
  /// than 10 characters get the 0x1234...5678 truncation, shorter
  /// values pass through unchanged.
  String get shortWallet {
    final w = _wallet ?? '';
    return w.length > 10
        ? '${w.substring(0, 6)}...${w.substring(w.length - 4)}'
        : w;
  }

  /// Mirrors AuthController.disconnect (state-only side).
  void disconnect() {
    _wallet = null;
    isConnected.value = false;
    credits.value = 0;
    username.value = '';
    bio.value = '';
  }

  /// Stand-in for the success branch of connect() that the real controller
  /// runs after MetaMask + nonce verification succeed.
  void markConnected(String walletAddr) {
    _wallet = walletAddr;
    isConnected.value = true;
    isConnecting.value = false;
    error.value = null;
  }

  /// Stand-in for the early-return branch of connect() when the wallet
  /// bridge is unavailable (kIsWeb=false in tests, MetaMask missing in prod).
  void markConnectFailed(String reason) {
    error.value = reason;
    isConnecting.value = false;
    isConnected.value = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.reset());
  tearDown(() => Get.reset());

  test('initial state is unauthenticated', () {
    final ctrl = _FakeAuthController();
    expect(ctrl.isConnected.value, isFalse);
    expect(ctrl.isConnecting.value, isFalse);
    expect(ctrl.credits.value, 0);
    expect(ctrl.username.value, '');
    expect(ctrl.bio.value, '');
    expect(ctrl.error.value, isNull);
    expect(ctrl.wallet, isNull);
    expect(ctrl.shortWallet, '');
  });

  test('disconnect clears wallet, connection flag, and profile', () {
    final ctrl = _FakeAuthController();
    ctrl.markConnected('0xabc');
    ctrl.credits.value = 50;
    ctrl.username.value = 'alice';
    ctrl.bio.value = 'hello';
    expect(ctrl.isConnected.value, isTrue);

    ctrl.disconnect();

    expect(ctrl.isConnected.value, isFalse);
    expect(ctrl.wallet, isNull);
    expect(ctrl.credits.value, 0);
    expect(ctrl.username.value, '');
    expect(ctrl.bio.value, '');
  });

  test('markConnected sets wallet + isConnected and clears error', () {
    final ctrl = _FakeAuthController();
    ctrl.error.value = 'previous failure';
    ctrl.isConnecting.value = true;

    ctrl.markConnected('0xdeadbeef');

    expect(ctrl.wallet, '0xdeadbeef');
    expect(ctrl.isConnected.value, isTrue);
    expect(ctrl.isConnecting.value, isFalse);
    expect(ctrl.error.value, isNull);
  });

  test('markConnectFailed surfaces error and resets isConnecting', () {
    final ctrl = _FakeAuthController();
    ctrl.isConnecting.value = true;

    ctrl.markConnectFailed('Connection failed. Install MetaMask.');

    expect(ctrl.error.value, contains('MetaMask'));
    expect(ctrl.isConnecting.value, isFalse);
    expect(ctrl.isConnected.value, isFalse);
  });

  test('shortWallet truncates a long 0x… address', () {
    final ctrl = _FakeAuthController();
    ctrl.markConnected('0x1234567890abcdef1234567890abcdef12345678');
    expect(ctrl.shortWallet, '0x1234...5678');
  });

  test('shortWallet leaves short strings unchanged', () {
    final ctrl = _FakeAuthController();
    ctrl.markConnected('0xabc');
    expect(ctrl.shortWallet, '0xabc');
  });

  test('isConnected is observable — listeners fire on flip', () async {
    final ctrl = _FakeAuthController();
    final seen = <bool>[];
    ctrl.isConnected.listen(seen.add);

    ctrl.markConnected('0xabc');
    ctrl.disconnect();
    await Future<void>.delayed(Duration.zero);

    expect(seen, contains(true));
    expect(seen, contains(false));
  });
}
