// Tests for the pure network-guard logic. Imports network_guard_pure.dart
// directly so the test target doesn't compile through wallet_service.dart's
// dart:js_interop chain (which `flutter test` rejects on the VM target).
//
// Coverage:
//   * computeNetworkState: null / Monad / wrong-chain inputs
//   * parseChainId: hex (0x279F), decimal (10143), invalid
//   * applyChainIdUpdate: end-to-end raw-payload → NetworkState transitions

import 'package:agent_store/shared/services/network_guard_pure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeNetworkState', () {
    test('null chainId stays optimistically on-network', () {
      final s = computeNetworkState(null);
      expect(s.currentChainId, isNull);
      expect(s.onCorrectNetwork, isTrue, reason: 'no flash before MetaMask reports');
    });

    test('Monad testnet (10143) is on-network', () {
      final s = computeNetworkState(10143);
      expect(s.currentChainId, 10143);
      expect(s.onCorrectNetwork, isTrue);
    });

    test('Ethereum mainnet (1) is off-network', () {
      final s = computeNetworkState(1);
      expect(s.currentChainId, 1);
      expect(s.onCorrectNetwork, isFalse);
    });

    test('Polygon (137) is off-network', () {
      final s = computeNetworkState(137);
      expect(s.onCorrectNetwork, isFalse);
    });

    test('expectedChainId constant is 10143', () {
      expect(kExpectedChainId, 10143);
    });
  });

  group('parseChainId', () {
    test('hex with 0x prefix', () {
      expect(parseChainId('0x279F'), 10143);
    });

    test('hex with capital 0X', () {
      expect(parseChainId('0X279f'), 10143);
    });

    test('decimal string', () {
      expect(parseChainId('10143'), 10143);
    });

    test('whitespace is trimmed', () {
      expect(parseChainId('  10143  '), 10143);
    });

    test('empty string returns null', () {
      expect(parseChainId(''), isNull);
    });

    test('garbage returns null', () {
      expect(parseChainId('not-a-number'), isNull);
      expect(parseChainId('0xZZZ'), isNull);
    });
  });

  group('applyChainIdUpdate', () {
    test('hex Monad chainId resolves to on-network', () {
      final s = applyChainIdUpdate('0x279F');
      expect(s.currentChainId, 10143);
      expect(s.onCorrectNetwork, isTrue);
    });

    test('decimal Monad chainId resolves to on-network', () {
      final s = applyChainIdUpdate('10143');
      expect(s.currentChainId, 10143);
      expect(s.onCorrectNetwork, isTrue);
    });

    test('Ethereum mainnet hex resolves to off-network', () {
      final s = applyChainIdUpdate('0x1');
      expect(s.currentChainId, 1);
      expect(s.onCorrectNetwork, isFalse);
    });

    test('malformed payload returns optimistic default', () {
      final s = applyChainIdUpdate('garbage');
      expect(s.currentChainId, isNull);
      expect(s.onCorrectNetwork, isTrue, reason: 'unknown chain → no banner flash');
    });
  });
}
