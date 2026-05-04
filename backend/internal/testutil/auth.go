package testutil

import (
	"crypto/ecdsa"
	"encoding/hex"
	"fmt"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/crypto"
)

// SignNonce produces a hex-encoded signature for the auth service's
// nonce-signing message format (`Sign in to Agent Store\n\nNonce: <nonce>`).
// The returned signature includes the 0x prefix expected by the service.
func SignNonce(t *testing.T, priv *ecdsa.PrivateKey, nonce string) string {
	t.Helper()
	signable := fmt.Sprintf("Sign in to Agent Store\n\nNonce: %s", nonce)
	prefixed := fmt.Sprintf("\x19Ethereum Signed Message:\n%d%s", len(signable), signable)
	hash := crypto.Keccak256Hash([]byte(prefixed))

	sig, err := crypto.Sign(hash.Bytes(), priv)
	if err != nil {
		t.Fatalf("testutil: sign: %v", err)
	}
	if len(sig) != 65 {
		t.Fatalf("testutil: unexpected sig length %d", len(sig))
	}
	// crypto.Sign returns recovery id in the [0, 1] range; the auth service
	// accepts both that and the [27, 28] range so we leave it as-is.
	return "0x" + strings.ToLower(hex.EncodeToString(sig))
}
