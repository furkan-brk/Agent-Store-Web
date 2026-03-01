// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../controllers/agent_detail_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../widgets/compare_modal.dart';
import '../widgets/mini_chat_widget.dart';
import '../widgets/radar_chart_widget.dart';
import '../widgets/rating_widget.dart';

/// Outer StatelessWidget — registers the controller keyed by agentId.
class AgentDetailScreen extends StatelessWidget {
  final int agentId;
  const AgentDetailScreen({super.key, required this.agentId});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AgentDetailController(agentId), tag: '$agentId');
    return _AgentDetailView(ctrl: ctrl);
  }
}

/// Thin StatefulWidget shell — ONLY for TabController (requires TickerProvider).
/// All data state lives in AgentDetailController.
class _AgentDetailView extends StatefulWidget {
  final AgentDetailController ctrl;
  const _AgentDetailView({required this.ctrl});

  @override
  State<_AgentDetailView> createState() => _AgentDetailViewState();
}

class _AgentDetailViewState extends State<_AgentDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  AgentDetailController get _ctrl => widget.ctrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleLibrary() async {
    if (!_ctrl.isLibraryAvailable) {
      await _showWalletDialog('Connect Wallet', 'Connect wallet to save agents?');
      return;
    }
    await _ctrl.toggleLibrary();
    if (mounted && !_ctrl.inLibrary.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from library'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _forkAgent() async {
    if (!_ctrl.isLibraryAvailable) {
      await _showWalletDialog('Connect Wallet', 'Connect your wallet to fork agents.');
      return;
    }
    if (_ctrl.isForkLoading.value || !_ctrl.canFork) return;
    final forked = await _ctrl.forkAgent();
    if (mounted) {
      if (forked != null) {
        context.go('/agent/${forked.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fork agent. Try again.')),
        );
      }
    }
  }

  Future<void> _buyAgent() async {
    final agent = _ctrl.agent.value;
    if (agent == null || _ctrl.isPurchaseLoading.value) return;
    if (!_ctrl.isLibraryAvailable) {
      await _showWalletDialog('Connect Wallet', 'Connect wallet to purchase.');
      return;
    }
    if (_ctrl.isPurchased.value) return;

    try {
      final txHash = await WalletService.instance.sendTransaction(
        agent.creatorWallet, agent.price,
      );
      if (txHash == null) return;
      final ok = await _ctrl.purchaseAgent(txHash, agent.price);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Agent purchased!' : 'Purchase failed. Try again.')),
        );
      }
    } catch (_) {}
  }

  void _shareAgent(AgentModel agent) {
    final url = '${html.window.location.origin}/agent/${agent.id}';
    final text = '${agent.title} — ${agent.characterType.displayName} on AgentStore\n$url';
    html.window.navigator.clipboard?.writeText(text).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text('Link copied to clipboard!'),
          ]),
          duration: Duration(seconds: 2),
        ));
      }
    }).catchError((_) {});
  }

  Future<void> _showWalletDialog(String title, String content) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282918),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Color(0xFF6B5A40))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.of(ctx).pop(); context.go('/wallet'); },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_ctrl.isLoading.value) {
        return const Scaffold(
          backgroundColor: AppTheme.bg,
          body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        );
      }
      final a = _ctrl.agent.value;
      if (a == null) {
        return const Scaffold(
          backgroundColor: AppTheme.bg,
          body: Center(child: Text('Agent not found', style: TextStyle(color: AppTheme.textH))),
        );
      }

      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Row(children: [
          // ── Left panel — character ──────────────────────────────────────
          Container(
            width: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [a.characterType.primaryColor.withValues(alpha: 0.15), AppTheme.surface],
              ),
              border: const Border(right: BorderSide(color: AppTheme.border)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const SizedBox(height: 28),
                PixelCharacterWidget(
                  characterType: a.characterType, rarity: a.rarity,
                  size: 148, showName: true, showRarity: true,
                  showStats: false, stats: a.stats, agentId: a.id,
                  generatedImage: a.generatedImage,
                ),
                const SizedBox(height: 14),
                if (a.stats.isNotEmpty) ...[
                  RadarChartWidget(stats: a.stats, color: a.characterType.primaryColor),
                  const SizedBox(height: 8),
                ],
                Text(
                  a.characterType.description,
                  style: const TextStyle(color: AppTheme.textM, fontSize: 12, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 6, runSpacing: 6, children: a.traits.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: a.characterType.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: a.characterType.primaryColor.withValues(alpha: 0.3))),
                  child: Text(t, style: TextStyle(color: a.characterType.primaryColor, fontSize: 11)),
                )).toList()),
                const SizedBox(height: 20),

                // Buy button
                if (a.creatorWallet.isNotEmpty &&
                    a.price > 0 &&
                    a.creatorWallet != (WalletService.instance.connectedWallet ?? '')) ...[
                  if (_ctrl.isPurchased.value)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A8A48).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF5A8A48).withValues(alpha: 0.4)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF5A8A48), size: 16),
                        SizedBox(width: 6),
                        Text('Purchased', style: TextStyle(color: Color(0xFF5A8A48), fontWeight: FontWeight.w600)),
                      ]),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5A8A48),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _ctrl.isPurchaseLoading.value ? null : _buyAgent,
                        icon: _ctrl.isPurchaseLoading.value
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.shopping_cart_outlined, size: 16),
                        label: Text(_ctrl.isPurchaseLoading.value ? 'Processing...' : 'Buy  ${a.price.toStringAsFixed(2)} MON'),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // Fork button
                Tooltip(
                  message: _ctrl.canFork ? '' : 'Insufficient credits',
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _ctrl.isForkLoading.value
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.fork_right, size: 18),
                      label: Text(_ctrl.isForkLoading.value ? 'Forking...' : 'Fork  \u26A15'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF282918),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: (_ctrl.isForkLoading.value || !_ctrl.canFork) ? null : _forkAgent,
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Right panel — tabbed content ────────────────────────────────
          Expanded(
            child: Column(children: [
              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 32, 36, 0),
                child: Row(children: [
                  Expanded(child: Text(a.title,
                    style: const TextStyle(color: AppTheme.textH, fontSize: 26, fontWeight: FontWeight.bold))),
                  if (a.price > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6B5010), AppTheme.gold], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${a.price.toStringAsFixed(2)} MON',
                        style: const TextStyle(color: Color(0xFF1E1A14), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: const Icon(Icons.compare_arrows, color: Color(0xFF6B5A40), size: 24),
                    tooltip: 'Compare agents',
                    onPressed: () => showDialog(context: context, builder: (_) => CompareModal(baseAgent: a)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Color(0xFF6B5A40)),
                    tooltip: 'Share Agent',
                    onPressed: () => _shareAgent(a),
                  ),
                  Obx(() => IconButton(
                    onPressed: _toggleLibrary,
                    icon: Icon(
                      _ctrl.inLibrary.value ? Icons.bookmark : Icons.bookmark_outline,
                      color: _ctrl.inLibrary.value ? AppTheme.primary : const Color(0xFF6B5A40),
                      size: 26,
                    ),
                  )),
                ]),
              ),

              // Tab bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: TabBar(
                  controller: _tabCtrl,
                  tabs: const [Tab(text: 'Details'), Tab(text: 'Test Agent'), Tab(text: 'Similar')],
                  labelColor: AppTheme.textH, unselectedLabelColor: AppTheme.textM,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF8B1A11)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: AppTheme.border,
                  splashFactory: NoSplash.splashFactory,
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // Tab 1 — Details
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(36),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.description,
                          style: const TextStyle(color: AppTheme.textB, fontSize: 15, height: 1.6)),
                        // Character Profile
                        if (a.profileMood != null || a.profileRolePurpose != null) ...[
                          const SizedBox(height: 20),
                          const Text('Character Profile',
                            style: TextStyle(color: AppTheme.textH, fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.card, borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: a.characterType.primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (a.profileMood != null) ...[
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.psychology_outlined, size: 14, color: a.characterType.accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(a.profileMood!,
                                    style: const TextStyle(color: Color(0xFF4A4033), fontSize: 13, height: 1.5))),
                                ]),
                              ],
                              if (a.profileMood != null && a.profileRolePurpose != null)
                                const SizedBox(height: 10),
                              if (a.profileRolePurpose != null)
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.auto_awesome_outlined, size: 14, color: a.characterType.accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(a.profileRolePurpose!,
                                    style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 12, height: 1.6))),
                                ]),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Wrap(spacing: 8, runSpacing: 8, children: a.tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.card2, borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border)),
                          child: Text('#$t', style: const TextStyle(color: AppTheme.textM, fontSize: 12)),
                        )).toList()),
                        const SizedBox(height: 28),
                        Obx(() => Row(children: [
                          const Text('Prompt', style: TextStyle(color: AppTheme.textH, fontSize: 17, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _ctrl.copyPrompt,
                            icon: Icon(_ctrl.copied.value ? Icons.check : Icons.copy, size: 15),
                            label: Text(_ctrl.copied.value ? 'Copied!' : 'Copy'),
                          ),
                        ])),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16130C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border2)),
                          child: SelectableText(a.prompt,
                            style: const TextStyle(color: Color(0xFF8BCA8B), fontSize: 13, height: 1.7, fontFamily: 'monospace')),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'By ${a.creatorWallet.length > 10 ? '${a.creatorWallet.substring(0, 6)}...${a.creatorWallet.substring(a.creatorWallet.length - 4)}' : a.creatorWallet}',
                          style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                        ),
                        if (a.tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(spacing: 6, runSpacing: 6, children: a.tags.map((tag) => Chip(
                            label: Text('#$tag', style: const TextStyle(color: Color(0xFF81231E), fontSize: 10)),
                            backgroundColor: const Color(0xFF282918), side: BorderSide.none,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          )).toList()),
                        ],
                        const SizedBox(height: 24),
                        const Text('Ratings', style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        RatingWidget(agentId: widget.ctrl.agentId),
                      ]),
                    ),

                    // Tab 2 — Test Agent (Mini Chat)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: MiniChatWidget(agentId: a.id, agentTitle: a.title),
                    ),

                    // Tab 3 — Similar
                    Obx(() {
                      final sim = _ctrl.similar;
                      if (sim.isEmpty) {
                        return const Center(
                          child: Text('No similar agents found', style: TextStyle(color: AppTheme.textM)),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
                          itemCount: sim.length,
                          itemBuilder: (ctx, i) {
                            final agent = sim[i];
                            final rc = agent.rarity.color;
                            return InkWell(
                              onTap: () => ctx.go('/agent/${agent.id}'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: rc.withValues(alpha: 0.3)),
                                ),
                                child: Column(children: [
                                  PixelCharacterWidget(
                                    characterType: agent.characterType, rarity: agent.rarity,
                                    size: 72, agentId: agent.id, generatedImage: agent.generatedImage),
                                  const SizedBox(height: 10),
                                  Text(agent.title,
                                    style: const TextStyle(color: AppTheme.textH, fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(agent.description,
                                    style: const TextStyle(color: AppTheme.textM, fontSize: 10),
                                    maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                  const Spacer(),
                                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    const Icon(Icons.bookmarks_outlined, size: 11, color: AppTheme.textM),
                                    const SizedBox(width: 3),
                                    Text('${agent.saveCount}', style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
                                  ]),
                                ]),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ]),
          ),
        ]),
      );
    });
  }

}
