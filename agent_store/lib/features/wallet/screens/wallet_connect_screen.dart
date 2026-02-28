import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/services/api_service.dart';

class WalletConnectScreen extends StatefulWidget {
  const WalletConnectScreen({super.key});
  @override
  State<WalletConnectScreen> createState() => _WalletConnectScreenState();
}

class _WalletConnectScreenState extends State<WalletConnectScreen> {
  bool _connecting = false;
  bool _loadingCredits = false;
  bool _buyingCredits = false;
  String? _error;
  int _credits = 0;

  // Profile state
  String _username = '';
  String _bio = '';

  bool get _connected => WalletService.instance.isConnected;
  String? get _wallet => WalletService.instance.connectedWallet;

  @override
  void initState() {
    super.initState();
    if (_connected) _loadCredits();
  }

  Future<void> _loadCredits() async {
    setState(() => _loadingCredits = true);
    final results = await Future.wait([
      ApiService.instance.getCredits(),
      ApiService.instance.getUserProfile(),
    ]);
    final c = results[0] as int;
    final profile = results[1] as Map<String, dynamic>?;
    setState(() {
      _credits = c;
      _username = profile?['username'] as String? ?? '';
      _bio = profile?['bio'] as String? ?? '';
      _loadingCredits = false;
    });
  }

  Future<void> _connect() async {
    setState(() { _connecting = true; _error = null; });

    final wallet = await WalletService.instance.connectWallet();
    if (wallet == null) {
      setState(() { _connecting = false; _error = 'Connection failed. Install MetaMask.'; });
      return;
    }

    final nonce = await ApiService.instance.getNonce(wallet);
    if (nonce == null) {
      setState(() { _connecting = false; _error = 'Server error: could not get nonce.'; });
      return;
    }

    final message = 'Sign in to Agent Store\n\nNonce: $nonce';
    final sig = await WalletService.instance.signMessage(message);
    if (sig == null) {
      setState(() { _connecting = false; _error = 'Signature rejected.'; });
      return;
    }

    final result = await ApiService.instance.verifySignature(
      wallet: wallet, nonce: nonce, signature: sig,
    );
    if (result == null) {
      setState(() { _connecting = false; _error = 'Authentication failed.'; });
      return;
    }

    final token = result['token'] as String?;
    if (token == null) {
      setState(() { _connecting = false; _error = 'Invalid server response.'; });
      return;
    }
    ApiService.instance.setToken(token);
    setState(() => _connecting = false);
    await _loadCredits();
  }

  void _disconnect() {
    WalletService.instance.disconnect();
    ApiService.instance.clearToken();
    setState(() { _credits = 0; _username = ''; _bio = ''; });
  }

  void _showEditProfileDialog() {
    final usernameCtrl = TextEditingController(text: _username);
    final bioCtrl = TextEditingController(text: _bio);
    showDialog<void>(
      context: context,
      builder: (_) => _EditProfileDialog(
        usernameCtrl: usernameCtrl,
        bioCtrl: bioCtrl,
        onSave: (username, bio) async {
          final ok = await ApiService.instance.updateProfile(username: username, bio: bio);
          if (ok && mounted) {
            setState(() { _username = username; _bio = bio; });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profile updated!'),
                  backgroundColor: const Color(0xFF5A8A48),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _topUp(double amountMon) async {
    // treasury wallet'a MON gönder
    const treasuryWallet = '0x0000000000000000000000000000000000000001'; // placeholder
    setState(() => _buyingCredits = true);
    try {
      final txHash = await WalletService.instance.sendTransaction(treasuryWallet, amountMon);
      if (txHash == null) { setState(() => _buyingCredits = false); return; }
      final result = await ApiService.instance.topUpCredits(txHash, amountMon);
      if (result != null && mounted) {
        setState(() {
          _credits = result['new_balance'] as int? ?? _credits;
          _buyingCredits = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${(amountMon * 100).toInt()} credits added!')));
      } else if (mounted) {
        setState(() => _buyingCredits = false);
      }
    } catch (_) {
      if (mounted) setState(() => _buyingCredits = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF181910),
    body: Center(child: SingleChildScrollView(child: Container(
      width: 480,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: const Color(0xFF22231A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3D3E2A)),
      ),
      child: _connected ? _connectedView() : _connectView(),
    ))),
  );

  Widget _connectView() => Column(mainAxisSize: MainAxisSize.min, children: [
    _iconCircle(Icons.account_balance_wallet_outlined, const Color(0xFF81231E)),
    const SizedBox(height: 22),
    const Text('Connect Wallet',
      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('Connect your MetaMask wallet to browse and create agents.',
      style: TextStyle(color: Color(0xFF9E8F72), height: 1.5), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF282918), borderRadius: BorderRadius.circular(8)),
      child: const Text('Monad Testnet · ChainID 10143',
        style: TextStyle(color: Color(0xFF81231E), fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    const SizedBox(height: 20),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2B1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3D3E2A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('New users start with 100 free credits',
          style: TextStyle(color: Color(0xFF9E8F72), fontSize: 12)),
        const SizedBox(height: 10),
        _costRow(Icons.add_box_outlined, 'Create Agent', 10, const Color(0xFF81231E)),
        const SizedBox(height: 6),
        _costRow(Icons.fork_right, 'Fork Agent', 5, const Color(0xFF81231E)),
      ]),
    ),
    const SizedBox(height: 24),
    if (_error != null) ...[
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF81231E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF81231E).withValues(alpha: 0.4))),
        child: Text(_error!, style: const TextStyle(color: Color(0xFFCAB891), fontSize: 12)),
      ),
    ],
    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: _connecting ? null : _connect,
      icon: _connecting
          ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.account_balance_wallet),
      label: Text(_connecting ? 'Connecting...' : 'Connect MetaMask'),
    )),
  ]);

  Widget _connectedView() {
    final w = _wallet ?? '';
    final short = w.length > 10 ? '${w.substring(0, 6)}...${w.substring(w.length - 4)}' : w;
    final isLow = _credits < 20;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      _iconCircle(Icons.check_circle_outline, const Color(0xFF4A6A28)),
      const SizedBox(height: 16),
      const Text('Connected',
        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(color: Color(0xFF4A6A28), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(short, style: const TextStyle(color: Color(0xFF9E8F72), fontSize: 13)),
      ]),
      const SizedBox(height: 24),
      // Credits balance card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLow
                ? [const Color(0xFF81231E), const Color(0xFF2A2B1E)]
                : [const Color(0xFF1E1F14), const Color(0xFF2A2B1E)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLow
                ? const Color(0xFF81231E).withValues(alpha: 0.5)
                : const Color(0xFF81231E).withValues(alpha: 0.3),
          ),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('CREDITS BALANCE',
              style: TextStyle(color: Color(0xFF9E8F72), fontSize: 11, letterSpacing: 1.2)),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: _loadingCredits
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF81231E)))
                  : const Icon(Icons.refresh, color: Color(0xFF7A6E52), size: 18),
              onPressed: _loadingCredits ? null : _loadCredits,
            ),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.bolt, color: Color(0xFF9B7B1A), size: 32),
            const SizedBox(width: 8),
            Text('$_credits',
              style: const TextStyle(color: Colors.white, fontSize: 42,
                fontWeight: FontWeight.bold, letterSpacing: -1)),
          ]),
          if (isLow) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF81231E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFCAB891), size: 14),
                SizedBox(width: 5),
                Text('Low credits — some actions may be unavailable',
                  style: TextStyle(color: Color(0xFFCAB891), fontSize: 11)),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      // Profile card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2B1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3D3E2A)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Profile',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: () => _showEditProfileDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF81231E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF81231E).withValues(alpha: 0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_outlined, color: Color(0xFF81231E), size: 13),
                  SizedBox(width: 4),
                  Text('Edit', style: TextStyle(color: Color(0xFF81231E), fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_username.isNotEmpty) ...[
            Row(children: [
              const Icon(Icons.person_outline, color: Color(0xFF9E8F72), size: 14),
              const SizedBox(width: 6),
              Text(_username, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
          ],
          if (_bio.isNotEmpty)
            Text(_bio, style: const TextStyle(color: Color(0xFF9E8F72), fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)
          else
            const Text('No bio set.', style: TextStyle(color: Color(0xFF5A5038), fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 16),
      // Credit costs
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2B1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3D3E2A)),
        ),
        child: Column(children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Credit Costs',
              style: TextStyle(color: Color(0xFF9E8F72), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          _costRow(Icons.add_box_outlined, 'Create Agent', 10, const Color(0xFF81231E)),
          const SizedBox(height: 6),
          _costRow(Icons.fork_right, 'Fork Agent', 5, const Color(0xFF81231E)),
        ]),
      ),
      const SizedBox(height: 14),
      // Buy Credits card
      Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1F14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3D3E2A)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Buy Credits',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('1 MON = 100 credits',
            style: TextStyle(color: Color(0xFF9E8F72), fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [0.1, 0.5, 1.0, 5.0].map((amt) =>
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF81231E),
                  side: const BorderSide(color: Color(0xFF81231E)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _buyingCredits ? null : () => _topUp(amt),
                child: _buyingCredits
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF81231E)))
                  : Text('$amt MON\n${(amt * 100).toInt()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11)),
              ),
            ).toList(),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => context.go('/credits/history'),
          icon: const Icon(Icons.history, size: 16),
          label: const Text('View Credit History'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF9E8F72),
            side: const BorderSide(color: Color(0xFF3D3E2A)),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: OutlinedButton(
        onPressed: _disconnect,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF81231E),
          side: const BorderSide(color: Color(0xFF81231E)),
        ),
        child: const Text('Disconnect'),
      )),
    ]);
  }

  Widget _costRow(IconData icon, String label, int cost, Color color) =>
    Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
        style: const TextStyle(color: Color(0xFF9E8F72), fontSize: 12))),
      Row(children: [
        const Icon(Icons.bolt, color: Color(0xFF9B7B1A), size: 13),
        const SizedBox(width: 2),
        Text('$cost', style: const TextStyle(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    ]);

  Widget _iconCircle(IconData icon, Color color) => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
    child: Icon(icon, color: color, size: 30),
  );
}

// ── Edit Profile Dialog ───────────────────────────────────────────────────────

class _EditProfileDialog extends StatefulWidget {
  final TextEditingController usernameCtrl;
  final TextEditingController bioCtrl;
  final Future<void> Function(String username, String bio) onSave;
  const _EditProfileDialog({
    required this.usernameCtrl,
    required this.bioCtrl,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1F14),
      title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: widget.usernameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Username',
            labelStyle: const TextStyle(color: Color(0xFF9E8F72)),
            filled: true,
            fillColor: const Color(0xFF22231A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4A4A33)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4A4A33)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF81231E)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.bioCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Bio',
            labelStyle: const TextStyle(color: Color(0xFF9E8F72)),
            filled: true,
            fillColor: const Color(0xFF22231A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4A4A33)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4A4A33)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF81231E)),
            ),
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF9E8F72))),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF81231E)),
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await widget.onSave(
                    widget.usernameCtrl.text.trim(),
                    widget.bioCtrl.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
