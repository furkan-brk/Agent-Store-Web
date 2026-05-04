// Unit tests for the wallet error dictionary.
//
// The dictionary is hit on every MetaMask / RPC failure path, so the
// mapping has to be code-stable. These tests pin down the most common
// MetaMask codes (4001 user-rejected, -32603 internal, 4902 unknown
// chain) plus the fallback path.

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_store/shared/services/wallet_errors.dart';

void main() {
  group('friendlyError', () {
    test('maps 4001 to "rejected" copy', () {
      final msg = friendlyError(Exception('User rejected the request: 4001'));
      expect(msg, contains('rejected'));
    });

    test('maps -32603 to "rejected the request"-style retry hint', () {
      final msg = friendlyError(Exception('Internal JSON-RPC error: -32603'));
      // The crucial bit isn't the verbatim wording — it's that the user
      // sees an actionable, NON-raw message.
      expect(msg, isNot(contains('JSON-RPC')));
      expect(msg, isNot(contains('-32603')));
    });

    test('maps 4902 to chain-switch suggestion + carries the action key', () {
      final err = classifyWalletError(
        Exception('Unrecognized chain: 4902'),
      );
      expect(err.userMessage.toLowerCase(), contains('monad'));
      expect(err.action, 'switch_chain');
    });

    test('unknown code falls back to "Wallet error: ..." envelope', () {
      final msg = friendlyError(Exception('Some bizarre new failure'));
      expect(msg.startsWith('Wallet error:'), isTrue);
      expect(msg, contains('Some bizarre new failure'));
    });

    test('null error returns a stable, non-empty fallback', () {
      final msg = friendlyError(null);
      expect(msg, isNotEmpty);
      expect(msg.toLowerCase(), contains('wallet'));
    });
  });

  group('classifyWalletError', () {
    test('insufficient_funds carries the open_faucet action key', () {
      final err = classifyWalletError(
        'transfer failed: insufficient_funds for gas * price',
      );
      expect(err.action, 'open_faucet');
      expect(err.userMessage.toLowerCase(), contains('mon'));
    });
  });
}
