// Pure network-guard logic — extracted from network_guard.dart so unit tests
// can verify chain-ID decisions without pulling wallet_service.dart, which
// transitively imports `package:web` + `dart:js_interop` (incompatible with
// the `flutter test` VM target).
//
// network_guard.dart re-exports these via a typedef alias so consumer code
// keeps importing one file. Tests (test/unit/network_guard_test.dart) import
// THIS file directly to skip the JS-interop chain.

const int kExpectedChainId = 10143; // Monad testnet (0x279F)

/// Snapshot returned by [computeNetworkState]. Decouples the pure decision
/// from the GetX-based controller so tests can assert without GetX.
class NetworkState {
  final int? currentChainId;
  final bool onCorrectNetwork;
  const NetworkState({
    required this.currentChainId,
    required this.onCorrectNetwork,
  });
}

/// Given an observed chain ID (or null when MetaMask hasn't reported yet),
/// produces the corresponding [NetworkState]. Optimistic on null so the
/// guard banner doesn't flash before MetaMask has replied.
NetworkState computeNetworkState(int? chainId) {
  if (chainId == null) {
    return const NetworkState(currentChainId: null, onCorrectNetwork: true);
  }
  return NetworkState(
    currentChainId: chainId,
    onCorrectNetwork: chainId == kExpectedChainId,
  );
}

/// Parses MetaMask's chainId payload — either a hex string ('0x279F') or
/// a decimal string ('10143'). Returns null on malformed input.
int? parseChainId(String raw) {
  if (raw.isEmpty) return null;
  final trimmed = raw.trim();
  if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
    return int.tryParse(trimmed.substring(2), radix: 16);
  }
  return int.tryParse(trimmed);
}

/// End-to-end pure helper used by both [NetworkGuard.updateFromChainChanged]
/// and unit tests: parse the raw payload, then map to a [NetworkState].
/// Public so tests can exercise the contract without instantiating the
/// GetX-based controller (which transitively imports JS-interop code).
NetworkState applyChainIdUpdate(String rawChainId) {
  return computeNetworkState(parseChainId(rawChainId));
}
