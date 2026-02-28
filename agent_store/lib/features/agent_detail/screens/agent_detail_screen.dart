// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../widgets/compare_modal.dart';
import '../widgets/mini_chat_widget.dart';
import '../widgets/radar_chart_widget.dart';
import '../widgets/rating_widget.dart';

class AgentDetailScreen extends StatefulWidget {
  final int agentId;
  const AgentDetailScreen({super.key, required this.agentId});
  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen>
    with SingleTickerProviderStateMixin {
  AgentModel? _agent;
  bool _loading = true;
  bool _inLibrary = false;
  bool _copied = false;
  bool _forking = false;
  bool _isPurchased = false;
  bool _buying = false;
  int _credits = 999;
  late TabController _tabCtrl;
  List<AgentModel> _similar = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final a = await ApiService.instance.getAgent(widget.agentId);
    bool saved = false;
    int credits = 999;
    bool purchased = false;
    List<AgentModel> similar = [];

    if (ApiService.instance.isAuthenticated) {
      final library = await ApiService.instance.getLibrary();
      saved = library.any((m) => m.id == widget.agentId);
      credits = await ApiService.instance.getCredits();
      if (a != null) {
        purchased = await ApiService.instance.getPurchaseStatus(a.id);
      }
    }

    if (a != null) {
      try {
        final result = await ApiService.instance.listAgents(
          category: a.category,
          limit: 9,
        );
        similar = result.agents
            .where((m) => m.id != widget.agentId)
            .take(8)
            .toList();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _agent = a;
        _inLibrary = saved;
        _credits = credits;
        _isPurchased = purchased;
        _similar = similar;
        _loading = false;
      });
    }
  }

  Future<void> _toggleLibrary() async {
    if (_agent == null) return;
    if (!ApiService.instance.isAuthenticated) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF282918),
          title: const Text('Connect Wallet', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Connect wallet to save agents?',
            style: TextStyle(color: Color(0xFF6B5A40)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/wallet');
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      );
      return;
    }
    final bool ok;
    if (_inLibrary) {
      ok = await ApiService.instance.removeFromLibrary(_agent!.id);
    } else {
      ok = await ApiService.instance.addToLibrary(_agent!.id);
    }
    if (ok) {
      setState(() => _inLibrary = !_inLibrary);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update library. Try again.')),
      );
    }
  }

  Future<void> _copyPrompt() async {
    if (_agent == null) return;
    await Clipboard.setData(ClipboardData(text: _agent!.prompt));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _forkAgent() async {
    if (_agent == null || _forking) return;
    if (!ApiService.instance.isAuthenticated) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF282918),
          title: const Text('Connect Wallet', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Connect your wallet to fork agents.',
            style: TextStyle(color: Color(0xFF6B5A40)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/wallet');
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _forking = true);
    final forked = await ApiService.instance.forkAgent(_agent!.id);
    if (mounted) {
      setState(() => _forking = false);
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
    final agent = _agent;
    if (agent == null || _buying) return;

    if (!ApiService.instance.isAuthenticated) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF282918),
          title: const Text('Connect Wallet', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Connect wallet to purchase.',
            style: TextStyle(color: Color(0xFF6B5A40)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/wallet');
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      );
      return;
    }

    if (_isPurchased) return;

    setState(() => _buying = true);
    try {
      final txHash = await WalletService.instance.sendTransaction(
        agent.creatorWallet,
        agent.price,
      );
      if (txHash == null) {
        if (mounted) setState(() => _buying = false);
        return;
      }
      final ok = await ApiService.instance.purchaseAgent(
        agent.id, txHash, amountMon: agent.price,
      );
      if (mounted) {
        setState(() {
          _buying = false;
          if (ok) _isPurchased = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Agent purchased!' : 'Purchase failed. Try again.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _buying = false);
    }
  }

  void _shareAgent(AgentModel agent) {
    final url = '${html.window.location.origin}/agent/${agent.id}';
    final text = '${agent.title} — ${agent.characterType.displayName} on AgentStore\n$url';
    html.window.navigator.clipboard?.writeText(text).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text('Link copied to clipboard!'),
            ]),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFDDD1BB),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_agent == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFDDD1BB),
        body: Center(child: Text('Agent not found', style: TextStyle(color: Colors.white))),
      );
    }
    final a = _agent!;
    return Scaffold(
      backgroundColor: const Color(0xFFDDD1BB),
      body: Row(children: [
        // Left panel — character
        Container(
          width: 300,
          color: const Color(0xFFC8BA9A),
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
              // Radar chart
              if (a.stats.isNotEmpty) ...[
                RadarChartWidget(
                  stats: a.stats,
                  color: a.characterType.primaryColor,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                a.characterType.description,
                style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 12, height: 1.5),
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
              // Buy button — shown for paid agents that aren't owned by the current user
              if (a.creatorWallet.isNotEmpty &&
                  a.price > 0 &&
                  a.creatorWallet != (WalletService.instance.connectedWallet ?? '')) ...[
                if (_isPurchased)
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
                      onPressed: _buying ? null : _buyAgent,
                      icon: _buying
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.shopping_cart_outlined, size: 16),
                      label: Text(_buying ? 'Processing...' : 'Buy  ${a.price.toStringAsFixed(2)} MON'),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              // Fork button
              Tooltip(
                message: _credits < 5 ? 'Insufficient credits' : '',
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _forking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.fork_right, size: 18),
                    label: Text(_forking ? 'Forking...' : 'Fork  \u26A15'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF282918),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (_forking || _credits < 5) ? null : _forkAgent,
                  ),
                ),
              ),
            ]),
          ),
        ),
        // Right panel — tabbed content
        Expanded(
          child: Column(children: [
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 0),
              child: Row(children: [
                Expanded(child: Text(a.title,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))),
                if (a.price > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B7B1A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF9B7B1A).withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '${a.price.toStringAsFixed(2)} MON',
                      style: const TextStyle(color: Color(0xFF9B7B1A), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_agent != null)
                  IconButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => CompareModal(baseAgent: _agent!),
                    ),
                    icon: const Icon(
                      Icons.compare_arrows,
                      color: Color(0xFF6B5A40),
                      size: 24,
                    ),
                    tooltip: 'Compare agents',
                  ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Color(0xFF6B5A40)),
                  tooltip: 'Share Agent',
                  onPressed: () { if (_agent != null) _shareAgent(_agent!); },
                ),
                IconButton(
                  onPressed: _toggleLibrary,
                  icon: Icon(
                    _inLibrary ? Icons.bookmark : Icons.bookmark_outline,
                    color: _inLibrary ? const Color(0xFF81231E) : const Color(0xFF6B5A40),
                    size: 26,
                  ),
                ),
              ]),
            ),
            // Tab bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Details'),
                  Tab(text: 'Test Agent'),
                  Tab(text: 'Similar'),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF7A6E52),
                indicator: BoxDecoration(
                  color: const Color(0xFF81231E),
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: const Color(0xFFADA07A),
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
                        style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 15, height: 1.6)),
                      // Character Profile — populated by the v2.6 world-builder + Imagen pipeline.
                      if (a.profileMood != null || a.profileRolePurpose != null) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Character Profile',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8BA9A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: a.characterType.primaryColor.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (a.profileMood != null) ...[
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.psychology_outlined,
                                      size: 14, color: a.characterType.accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a.profileMood!,
                                      style: const TextStyle(
                                          color: Color(0xFF4A4033), fontSize: 13, height: 1.5),
                                    ),
                                  ),
                                ]),
                              ],
                              if (a.profileMood != null && a.profileRolePurpose != null)
                                const SizedBox(height: 10),
                              if (a.profileRolePurpose != null)
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.auto_awesome_outlined,
                                      size: 14, color: a.characterType.accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a.profileRolePurpose!,
                                      style: const TextStyle(
                                          color: Color(0xFF6B5A40), fontSize: 12, height: 1.6),
                                    ),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(spacing: 8, runSpacing: 8, children: a.tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF282918), borderRadius: BorderRadius.circular(6)),
                        child: Text('#$t', style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 12)),
                      )).toList()),
                      const SizedBox(height: 28),
                      Row(children: [
                        const Text('Prompt', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _copyPrompt,
                          icon: Icon(_copied ? Icons.check : Icons.copy, size: 15),
                          label: Text(_copied ? 'Copied!' : 'Copy'),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC8BA9A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFADA07A))),
                        child: SelectableText(a.prompt,
                          style: const TextStyle(color: Color(0xFF4A4033), fontSize: 13, height: 1.7, fontFamily: 'monospace')),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'By ${a.creatorWallet.length > 10 ? '${a.creatorWallet.substring(0, 6)}...${a.creatorWallet.substring(a.creatorWallet.length - 4)}' : a.creatorWallet}',
                        style: const TextStyle(color: Color(0xFF5A5038), fontSize: 12),
                      ),
                      if (a.tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: a.tags.map((tag) => Chip(
                            label: Text(
                              '#$tag',
                              style: const TextStyle(
                                color: Color(0xFF81231E),
                                fontSize: 10,
                              ),
                            ),
                            backgroundColor: const Color(0xFF282918),
                            side: BorderSide.none,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          )).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Ratings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RatingWidget(agentId: widget.agentId),
                    ]),
                  ),
                  // Tab 2 — Test Agent (Mini Chat)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: MiniChatWidget(agentId: a.id, agentTitle: a.title),
                  ),
                  // Tab 3 — Similar
                  _similar.isEmpty
                      ? const Center(
                          child: Text(
                            'No similar agents found',
                            style: TextStyle(color: Color(0xFF7A6E52)),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: _similar.length,
                            itemBuilder: (ctx, i) {
                              final agent = _similar[i];
                              final rc = agent.rarity.color;
                              return InkWell(
                                onTap: () => ctx.go('/agent/${agent.id}'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8DEC9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: rc.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      PixelCharacterWidget(
                                        characterType: agent.characterType,
                                        rarity: agent.rarity,
                                        size: 72,
                                        agentId: agent.id,
                                        generatedImage: agent.generatedImage,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        agent.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        agent.description,
                                        style: const TextStyle(
                                          color: Color(0xFF6B5A40),
                                          fontSize: 10,
                                        ),
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.bookmarks_outlined,
                                            size: 11,
                                            color: Color(0xFF7A6E52),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${agent.saveCount}',
                                            style: const TextStyle(
                                              color: Color(0xFF7A6E52),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
