// lib/features/agent_detail/screens/agent_detail_screen.dart
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:agent_store/features/character/character_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../controllers/agent_detail_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/mission_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../store/data/background_data.dart';
import '../widgets/compare_modal.dart';
import '../widgets/export_agent_widget.dart';
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

  // ── Auth guard ──────────────────────────────────────────────────────────────

  /// Shows a "Connect Wallet" dialog and returns false if the user is not
  /// authenticated.  Wrap every authenticated action with:
  ///   if (!_requireAuth()) return;
  bool _requireAuth() {
    if (_ctrl.isLibraryAvailable) return true;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.border2),
        ),
        title: const Row(children: [
          Icon(Icons.account_balance_wallet_outlined, color: AppTheme.gold, size: 20),
          SizedBox(width: 10),
          Text('Wallet Required', style: TextStyle(color: AppTheme.textH)),
        ]),
        content: const Text(
          'Connect your wallet to perform this action.',
          style: TextStyle(color: AppTheme.textB, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/wallet');
            },
            icon: const Icon(Icons.link, size: 16),
            label: const Text('Connect Wallet'),
          ),
        ],
      ),
    );
    return false;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleLibrary() async {
    if (!_requireAuth()) return;
    await _ctrl.toggleLibrary();
    if (mounted && !_ctrl.inLibrary.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from library'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _forkAgent() async {
    if (!_requireAuth()) return;
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
    if (!_requireAuth()) return;
    if (_ctrl.isPurchased.value) return;

    // Show confirmation dialog before sending transaction
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.border2),
        ),
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_outlined, color: AppTheme.gold, size: 20),
            SizedBox(width: 10),
            Text('Confirm Purchase', style: TextStyle(color: AppTheme.textH)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase "${agent.title}" for ${agent.price.toStringAsFixed(2)} MON?',
              style: const TextStyle(color: AppTheme.textB, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppTheme.textM),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To: ${_truncateWallet(agent.creatorWallet)}',
                    style: const TextStyle(color: AppTheme.textM, fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will send a transaction via MetaMask on Monad Testnet.',
              style: TextStyle(color: AppTheme.textM, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.shopping_cart_outlined, size: 16),
            label: Text('Pay ${agent.price.toStringAsFixed(2)} MON'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final txHash = await WalletService.instance.sendTransaction(
        agent.creatorWallet, agent.price,
      );
      if (txHash == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.gold, size: 16),
              SizedBox(width: 8),
              Text('Transaction cancelled or failed. No funds were sent.'),
            ]),
          ));
        }
        return;
      }
      final ok = await _ctrl.purchaseAgent(txHash, agent.price);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              color: ok ? AppTheme.success : AppTheme.primary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(ok ? 'Agent purchased successfully!' : 'Purchase failed. Try again.'),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: AppTheme.primary, size: 16),
            const SizedBox(width: 8),
            Flexible(child: Text('Purchase error: $e')),
          ]),
        ));
      }
    }
  }

  // _handleTrial removed — trial now runs server-side via _buildTrialTab chat UI

  void _shareAgent(AgentModel agent) {
    final url = '${html.window.location.origin}/agent/${agent.id}';
    final text = '${agent.title} — ${agent.characterType.displayName} on AgentStore\n$url';
    html.window.navigator.clipboard?.writeText(text).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 16),
            SizedBox(width: 8),
            Text('Link copied to clipboard!'),
          ]),
          duration: Duration(seconds: 2),
        ));
      }
    }).catchError((_) {});
  }

  static String _truncateWallet(String wallet) {
    if (wallet.length > 14) {
      return '${wallet.substring(0, 6)}...${wallet.substring(wallet.length - 4)}';
    }
    return wallet;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_ctrl.isLoading.value) {
        return const _DetailLoadingSkeleton();
      }
      final a = _ctrl.agent.value;
      if (a == null) {
        return const _DetailErrorState();
      }

      final hasAccess = _ctrl.hasAccess;

      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Row(children: [
          // ── Left panel — character ──────────────────────────────────────
          _buildLeftPanel(a, hasAccess),

          // ── Right panel — scrollable tabbed content ─────────────────────
          Expanded(
            child: Stack(
              children: [
                // Background image layer — fills top portion, fades to transparent
                _HeroBackdrop(agent: a),

                // Actual content on top
                Column(children: [
                  // Top breathing room so the backdrop image has space to show
                  const SizedBox(height: 50),

                  // Title row with breathing room
                  _buildTitleRow(a),

                  const SizedBox(height: 8),

                  // Quick stats bar — moved here from inside Details tab for visibility
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildQuickInfoBar(a),
                  ),

                  const SizedBox(height: 16),

                  // Tab bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: TabBar(
                      controller: _tabCtrl,
                      tabs: const [
                        Tab(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.info_outline_rounded, size: 15),
                            SizedBox(width: 6),
                            Text('Details'),
                          ]),
                        ),
                        Tab(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.play_circle_outline_rounded, size: 15),
                            SizedBox(width: 6),
                            Text('Test Agent'),
                          ]),
                        ),
                        Tab(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.grid_view_rounded, size: 15),
                            SizedBox(width: 6),
                            Text('Similar'),
                          ]),
                        ),
                      ],
                      labelColor: AppTheme.textH,
                      unselectedLabelColor: AppTheme.textM,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: AppTheme.border,
                      splashFactory: NoSplash.splashFactory,
                    ),
                  ),

                  // Tab content — each tab handles its own scrolling
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // Tab 1 — Details
                        _buildDetailsTab(a, hasAccess),

                        // Tab 2 — Test Agent (Mini Chat) — only for owned, otherwise trial
                        hasAccess
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: MiniChatWidget(agentId: a.id, agentTitle: a.title),
                              )
                            : _buildTrialTab(a),

                        // Tab 3 — Similar
                        _buildSimilarTab(),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      );
    });
  }

  // ── Left Panel ──────────────────────────────────────────────────────────────

  Widget _buildLeftPanel(AgentModel a, bool hasAccess) {
    final rarityColor = a.rarity.color;
    return Container(
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
            imageUrl: a.imageUrl,
          ),
          const SizedBox(height: 12),

          // Category + Rarity badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BadgeChip(
                label: a.category.isNotEmpty ? a.category : a.characterType.displayName,
                icon: Icons.category_outlined,
                color: a.characterType.primaryColor,
              ),
              const SizedBox(width: 8),
              _BadgeChip(
                label: a.rarity.displayName,
                icon: Icons.auto_awesome,
                color: rarityColor,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Subclass badge
          if (a.subclass != CharacterSubclass.archmage || a.characterType == CharacterType.wizard)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                a.subclass.displayName,
                style: TextStyle(
                  color: a.characterType.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

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

          // Purchase button — shown when NOT owned and has a price
          if (!hasAccess && a.price > 0) ...[
            Obx(() {
              if (_ctrl.isPurchased.value) {
                return _PurchasedBadge();
              }
              return SizedBox(
                width: double.infinity,
                child: _HoverButton(
                  onPressed: _ctrl.isPurchaseLoading.value ? null : _buyAgent,
                  color: AppTheme.gold,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_ctrl.isPurchaseLoading.value)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                      else
                        const Icon(Icons.shopping_cart_outlined, size: 16, color: AppTheme.bg),
                      const SizedBox(width: 8),
                      Text(
                        _ctrl.isPurchaseLoading.value ? 'Processing...' : 'Purchase for ${a.price.toStringAsFixed(2)} MON',
                        style: const TextStyle(color: AppTheme.bg, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Show "Purchased" badge if owned via purchase and has price
          if (hasAccess && !_ctrl.isOwnAgent && a.price > 0)
            Obx(() {
              if (_ctrl.isPurchased.value || a.owned) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PurchasedBadge(),
                );
              }
              return const SizedBox.shrink();
            }),

          // Fork button
          Tooltip(
            message: _ctrl.canFork ? '' : 'Insufficient credits',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _ctrl.isForkLoading.value
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textH))
                    : const Icon(Icons.fork_right, size: 18),
                label: Text(_ctrl.isForkLoading.value ? 'Forking...' : 'Fork  \u26A15'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.card2,
                  foregroundColor: AppTheme.textH,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (_ctrl.isForkLoading.value || !_ctrl.canFork) ? null : _forkAgent,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Title Row ──────────────────────────────────────────────────────────────

  Widget _buildTitleRow(AgentModel a) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.title,
                style: const TextStyle(color: AppTheme.textH, fontSize: 26, fontWeight: FontWeight.bold)),
              if (a.serviceDescription != null && a.serviceDescription!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  a.serviceDescription!,
                  style: const TextStyle(color: AppTheme.textM, fontSize: 13, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (a.price > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.gold.withValues(alpha: 0.3), AppTheme.gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_outlined, size: 13, color: AppTheme.bg),
                const SizedBox(width: 4),
                Text('${a.price.toStringAsFixed(2)} MON',
                  style: const TextStyle(color: AppTheme.bg, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
            ),
            child: const Text('Free',
              style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
        _HoverIconButton(
          icon: Icons.compare_arrows,
          tooltip: 'Compare agents',
          onPressed: () => showDialog(context: context, builder: (_) => CompareModal(baseAgent: a)),
        ),
        _HoverIconButton(
          icon: Icons.share_outlined,
          tooltip: 'Share Agent',
          onPressed: () => _shareAgent(a),
        ),
        Obx(() => _HoverIconButton(
          icon: _ctrl.inLibrary.value ? Icons.bookmark : Icons.bookmark_outline,
          tooltip: _ctrl.inLibrary.value ? 'Remove from Library' : 'Save to Library',
          color: _ctrl.inLibrary.value ? AppTheme.primary : AppTheme.textM,
          onPressed: _toggleLibrary,
        )),
      ]),
    );
  }

  // ── Quick Info Bar (replaces duplicate hero) ──────────────────────────────

  Widget _buildQuickInfoBar(AgentModel a) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _QuickStat(icon: Icons.play_circle_outline_rounded, label: 'Uses', value: '${a.useCount}'),
          _quickDivider(),
          _QuickStat(icon: Icons.bookmark_outline_rounded, label: 'Saves', value: '${a.saveCount}'),
          _quickDivider(),
          _QuickStat(
            icon: Icons.speed_outlined,
            label: 'Score',
            value: '${a.promptScore}',
            valueColor: _scoreColor(a.promptScore),
          ),
          _quickDivider(),
          _QuickStat(
            icon: Icons.calendar_today_outlined,
            label: 'Created',
            value: _formatDate(a.createdAt),
          ),
          if (a.tags.isNotEmpty) ...[
            _quickDivider(),
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.label_outline_rounded, size: 13, color: AppTheme.textM),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      a.tags.map((t) => '#$t').join('  '),
                      style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.border,
    );
  }

  // ── Details Tab ─────────────────────────────────────────────────────────────

  Widget _buildDetailsTab(AgentModel a, bool hasAccess) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Description section
        const _SectionHeader(icon: Icons.description_outlined, title: 'Description'),
        const SizedBox(height: 12),
        Text(a.description,
          style: const TextStyle(color: AppTheme.textB, fontSize: 15, height: 1.7)),

        // Character Profile
        if (a.profileMood != null || a.profileRolePurpose != null) ...[
          const SizedBox(height: 28),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 24),
          const _SectionHeader(icon: Icons.psychology_outlined, title: 'Character Profile'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: a.characterType.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (a.profileMood != null) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.mood_outlined, size: 14, color: a.characterType.accentColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.profileMood!,
                    style: const TextStyle(color: AppTheme.textB, fontSize: 13, height: 1.5))),
                ]),
              ],
              if (a.profileMood != null && a.profileRolePurpose != null)
                const SizedBox(height: 12),
              if (a.profileRolePurpose != null)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.auto_awesome_outlined, size: 14, color: a.characterType.accentColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.profileRolePurpose!,
                    style: const TextStyle(color: AppTheme.textM, fontSize: 12, height: 1.6))),
                ]),
            ]),
          ),
        ],

        // Tags
        if (a.tags.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 24),
          const _SectionHeader(icon: Icons.label_outline_rounded, title: 'Tags'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: a.tags.map((t) => _HoverTagChip(tag: t)).toList()),
        ],

        // ── Prompt section — only if owned AND prompt is not empty ──
        if (hasAccess && a.prompt.isNotEmpty) ...[
          const SizedBox(height: 32),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 24),
          Obx(() => Row(children: [
            const Icon(Icons.code_rounded, size: 18, color: AppTheme.gold),
            const SizedBox(width: 8),
            const Text('Prompt', style: TextStyle(color: AppTheme.textH, fontSize: 17, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: _ctrl.copyPrompt,
              icon: Icon(_ctrl.copied.value ? Icons.check : Icons.copy, size: 15),
              label: Text(_ctrl.copied.value ? 'Copied!' : 'Copy'),
            ),
          ])),
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border2)),
            child: SelectableText(a.prompt,
              style: TextStyle(color: AppTheme.success.withValues(alpha: 0.85), fontSize: 13, height: 1.7, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 24),
          ExportAgentWidget(agent: a),
        ] else if (!hasAccess) ...[
          // ── Locked prompt section — blurred preview + buy/trial buttons ──
          const SizedBox(height: 32),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 24),
          _buildLockedPromptSection(a),
        ],

        // Creator info
        const SizedBox(height: 28),
        const Divider(color: AppTheme.border, height: 1),
        const SizedBox(height: 24),
        const _SectionHeader(icon: Icons.person_outline_rounded, title: 'Creator'),
        const SizedBox(height: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go('/profile/${a.creatorWallet}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppTheme.textM),
                  const SizedBox(width: 8),
                  SelectableText(
                    _truncateWallet(a.creatorWallet),
                    style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.textM),
                ],
              ),
            ),
          ),
        ),

        // Ratings section
        const SizedBox(height: 28),
        const Divider(color: AppTheme.border, height: 1),
        const SizedBox(height: 24),
        const _SectionHeader(icon: Icons.star_outline_rounded, title: 'Ratings'),
        const SizedBox(height: 14),
        RatingWidget(agentId: widget.ctrl.agentId),

        // Bottom breathing room
        const SizedBox(height: 32),
      ]),
    );
  }

  // ── Stats Row (used only inside Details tab now as expanded view) ─────────

  // ignore: unused_element
  Widget _buildStatsRow(AgentModel a) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _StatItem(icon: Icons.play_circle_outline_rounded, label: 'Uses', value: '${a.useCount}'),
          _statDivider(),
          _StatItem(icon: Icons.bookmark_outline_rounded, label: 'Saves', value: '${a.saveCount}'),
          _statDivider(),
          _StatItem(
            icon: Icons.speed_outlined,
            label: 'Score',
            value: '${a.promptScore}',
            valueColor: _scoreColor(a.promptScore),
          ),
          _statDivider(),
          _StatItem(
            icon: Icons.calendar_today_outlined,
            label: 'Created',
            value: _formatDate(a.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.border,
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 50) return AppTheme.gold;
    return AppTheme.primary;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ── Locked Prompt Section (inside Details tab for non-owners) ────────────────

  Widget _buildLockedPromptSection(AgentModel a) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Blurred/fake prompt preview with lock overlay
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Fake monospace text lines (blurred effect)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(5, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        width: [200.0, 280.0, 160.0, 240.0, 180.0][i],
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                  ),
                ),
                // Lock overlay
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: AppTheme.gold, size: 32),
                      SizedBox(height: 8),
                      Text('Prompt Locked',
                        style: TextStyle(color: AppTheme.textH, fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Purchase to view and export the full prompt',
                        style: TextStyle(color: AppTheme.textM, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons row
          Row(
            children: [
              // Buy button
              Expanded(
                child: Obx(() => _HoverButton(
                  onPressed: _ctrl.isPurchaseLoading.value ? null : _buyAgent,
                  color: AppTheme.gold,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_ctrl.isPurchaseLoading.value)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                      else
                        const Icon(Icons.shopping_cart_outlined, size: 16, color: AppTheme.bg),
                      const SizedBox(width: 8),
                      Text(
                        _ctrl.isPurchaseLoading.value ? 'Processing...' : 'Buy  ${a.price.toStringAsFixed(2)} MON',
                        style: const TextStyle(color: AppTheme.bg, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                )),
              ),
              const SizedBox(width: 12),
              // Trial button — opens the Test Agent tab
              Expanded(
                child: Obx(() {
                  final used = _ctrl.trialUsed.value;
                  final loading = _ctrl.isTrialLoading.value;
                  return _HoverButton(
                    onPressed: (loading || used) ? null : () => _tabCtrl.animateTo(1),
                    color: AppTheme.card2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          used ? Icons.check : Icons.play_circle_outline,
                          size: 16,
                          color: used ? AppTheme.textM : AppTheme.gold,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          used ? 'Trial Used' : 'Try Once',
                          style: TextStyle(
                            color: used ? AppTheme.textM : AppTheme.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Trial Tab (for non-owned agents) — server-side chat trial ────────────────

  Widget _buildTrialTab(AgentModel a) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _TrialChatPanel(
        agent: a,
        ctrl: _ctrl,
        onBuy: _buyAgent,
      ),
    );
  }

  // ── Similar Tab ──────────────────────────────────────────────────────────────

  Widget _buildSimilarTab() {
    return Obx(() {
      final sim = _ctrl.similar;
      if (sim.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textM.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text('No similar agents found',
                style: TextStyle(color: AppTheme.textM, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Try browsing the store for more agents',
                style: TextStyle(color: AppTheme.textM, fontSize: 12)),
            ],
          ),
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
            return _SimilarAgentCard(agent: agent);
          },
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Hero Backdrop — ambient background image that fades into the page background.
// Positioned behind the entire right panel content via a Stack parent.
// ══════════════════════════════════════════════════════════════════════════════

class _HeroBackdrop extends StatelessWidget {
  final AgentModel agent;
  const _HeroBackdrop({required this.agent});

  @override
  Widget build(BuildContext context) {
    final bg = matchBackground(agent.category, agent.characterType.name);
    final hasAsset = generatedBackgrounds.contains(bg.id);

    // Gradient fallback when no asset image is available
    final gradientFallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            agent.characterType.secondaryColor.withValues(alpha: 0.55),
            agent.characterType.primaryColor.withValues(alpha: 0.2),
            AppTheme.bg,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 300,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,        // fully visible at top
            Colors.transparent,  // fades to transparent at bottom
          ],
          stops: [0.0, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image or gradient fallback
            if (hasAsset)
              Opacity(
                opacity: 0.25,
                child: Image.asset(
                  bg.assetPath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => gradientFallback,
                ),
              )
            else
              gradientFallback,

            // Background name label — top-right corner
            Positioned(
              right: 16,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.landscape_outlined, size: 10,
                    color: Colors.white.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(bg.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 9,
                    )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Loading Skeleton — matches the detail page layout structure
// ══════════════════════════════════════════════════════════════════════════════

class _DetailLoadingSkeleton extends StatelessWidget {
  const _DetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: ShimmerScope(
        child: Row(
          children: [
            // Left panel skeleton
            Container(
              width: 300,
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(right: BorderSide(color: AppTheme.border)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  children: [
                    SizedBox(height: 28),
                    // Character avatar
                    ShimmerBox(width: 148, height: 148, radius: 14, color: AppTheme.card2),
                    SizedBox(height: 14),
                    // Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShimmerBox(width: 80, height: 24, radius: 12, color: AppTheme.card2),
                        SizedBox(width: 8),
                        ShimmerBox(width: 70, height: 24, radius: 12, color: AppTheme.card2),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Radar chart area
                    ShimmerBox(width: 200, height: 160, radius: 8, color: AppTheme.card2),
                    SizedBox(height: 16),
                    // Description
                    ShimmerBox(width: 220, height: 12, radius: 4, color: AppTheme.card2),
                    SizedBox(height: 6),
                    ShimmerBox(width: 180, height: 12, radius: 4, color: AppTheme.card2),
                    SizedBox(height: 20),
                    // Traits
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShimmerBox(width: 60, height: 22, radius: 12, color: AppTheme.card2),
                        SizedBox(width: 6),
                        ShimmerBox(width: 80, height: 22, radius: 12, color: AppTheme.card2),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Button
                    ShimmerBox(width: double.infinity, height: 44, radius: 10, color: AppTheme.card2),
                  ],
                ),
              ),
            ),

            // Right panel skeleton
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Accent strip
                  ShimmerBox(width: double.infinity, height: 56, radius: 0, color: AppTheme.card2),
                  // Title row
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      children: [
                        Expanded(child: ShimmerBox(width: double.infinity, height: 28, radius: 6, color: AppTheme.card2)),
                        SizedBox(width: 16),
                        ShimmerBox(width: 80, height: 24, radius: 6, color: AppTheme.card2),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  // Quick info bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: ShimmerBox(width: double.infinity, height: 48, radius: 10, color: AppTheme.card2),
                  ),
                  SizedBox(height: 16),
                  // Tab bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        ShimmerBox(width: 80, height: 32, radius: 16, color: AppTheme.card2),
                        SizedBox(width: 12),
                        ShimmerBox(width: 100, height: 32, radius: 16, color: AppTheme.card2),
                        SizedBox(width: 12),
                        ShimmerBox(width: 80, height: 32, radius: 16, color: AppTheme.card2),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  // Content area
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description lines
                        ShimmerBox(width: double.infinity, height: 14, radius: 4, color: AppTheme.card2),
                        SizedBox(height: 8),
                        ShimmerBox(width: double.infinity, height: 14, radius: 4, color: AppTheme.card2),
                        SizedBox(height: 8),
                        ShimmerBox(width: 300, height: 14, radius: 4, color: AppTheme.card2),
                        SizedBox(height: 28),
                        // Tags row
                        Row(
                          children: [
                            ShimmerBox(width: 60, height: 24, radius: 6, color: AppTheme.card2),
                            SizedBox(width: 8),
                            ShimmerBox(width: 80, height: 24, radius: 6, color: AppTheme.card2),
                            SizedBox(width: 8),
                            ShimmerBox(width: 70, height: 24, radius: 6, color: AppTheme.card2),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Error State — user-friendly error with retry
// ══════════════════════════════════════════════════════════════════════════════

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            const Text('Agent Not Found',
              style: TextStyle(color: AppTheme.textH, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This agent may have been removed or the link is invalid.',
              style: TextStyle(color: AppTheme.textM, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Store'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Trial Panel — provider selector + message input -> encrypted CLI command
// ══════════════════════════════════════════════════════════════════════════════

class _TrialChatPanel extends StatefulWidget {
  final AgentModel agent;
  final AgentDetailController ctrl;
  final VoidCallback onBuy;

  const _TrialChatPanel({
    required this.agent,
    required this.ctrl,
    required this.onBuy,
  });

  @override
  State<_TrialChatPanel> createState() => _TrialChatPanelState();
}

class _TrialChatPanelState extends State<_TrialChatPanel> {
  final _messageCtrl = TextEditingController();

  // Provider definitions with brand SVG logos
  static const _providers = [
    (id: 'claude', label: 'Claude', iconAsset: 'assets/icons/claude_logo.svg', color: Color(0xFFD97757)),
    (id: 'openai', label: 'ChatGPT', iconAsset: 'assets/icons/openai_logo.svg', color: Color(0xFF10A37F)),
    (id: 'gemini', label: 'Gemini', iconAsset: 'assets/icons/gemini_logo.svg', color: Color(0xFF4285F4)),
  ];

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateTrial() async {
    final raw = _messageCtrl.text.trim();
    final text = await MissionService.instance.expandMissionTags(raw);
    if (text.isEmpty) return;
    if (widget.ctrl.trialUsed.value || widget.ctrl.isTrialLoading.value) return;

    // Guard: wallet must be connected to use trial
    if (!widget.ctrl.isLibraryAvailable) {
      _showConnectWalletDialog();
      return;
    }
    await widget.ctrl.generateTrial(text);
  }

  void _showConnectWalletDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.border2),
        ),
        title: const Row(children: [
          Icon(Icons.account_balance_wallet_outlined, color: AppTheme.gold, size: 20),
          SizedBox(width: 10),
          Text('Wallet Required', style: TextStyle(color: AppTheme.textH)),
        ]),
        content: const Text(
          'Connect your wallet to test this agent.',
          style: TextStyle(color: AppTheme.textB, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              GoRouter.of(context).go('/wallet');
            },
            icon: const Icon(Icons.link, size: 16),
            label: const Text('Connect Wallet'),
          ),
        ],
      ),
    );
  }

  String get _selectedProviderLabel {
    final id = widget.ctrl.selectedTool.value;
    if (id.isEmpty) return 'your AI provider';
    return _providers.firstWhere((t) => t.id == id, orElse: () => _providers.first).label;
  }

  Widget _terminalDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(children: [
              const Icon(Icons.play_circle_outline, color: AppTheme.gold, size: 18),
              const SizedBox(width: 8),
              const Text('Test This Agent',
                style: TextStyle(color: AppTheme.textH, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                ),
                child: const Text('1 trial',
                  style: TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(widget.agent.title,
                style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                overflow: TextOverflow.ellipsis),
            ]),
          ),

          // ── Provider Selector with brand badges ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select your AI provider:',
                  style: TextStyle(color: AppTheme.textM, fontSize: 12)),
                const SizedBox(height: 10),
                Obx(() {
                  final selected = widget.ctrl.selectedTool.value;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _providers.map((provider) {
                      final isSelected = selected == provider.id;
                      return _BrandToolPill(
                        label: provider.label,
                        iconAsset: provider.iconAsset,
                        accentColor: provider.color,
                        isSelected: isSelected,
                        onTap: () => widget.ctrl.selectedTool.value = provider.id,
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),

          const Divider(color: AppTheme.border, height: 1),

          // ── Main Content Area ──────────────────────────────────────
          Expanded(
            child: Obx(() {
              final command = widget.ctrl.trialCommand.value;
              final isLoading = widget.ctrl.isTrialLoading.value;
              final trialUsed = widget.ctrl.trialUsed.value;

              // State 4: Trial already used (no command generated)
              if (trialUsed && command == null) {
                return _buildPurchaseCTA();
              }

              // State 2: Loading
              if (isLoading) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32, height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppTheme.gold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Generating trial command...',
                        style: TextStyle(color: AppTheme.textM, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('This will only take a moment',
                        style: TextStyle(color: AppTheme.textM, fontSize: 11)),
                    ],
                  ),
                );
              }

              // State 3: Command ready
              if (command != null) {
                return _buildCommandDisplay(command);
              }

              // State 1: Input (default)
              return _buildInputState();
            }),
          ),
        ],
      ),
    );
  }

  // ── State 1: Input form ──────────────────────────────────────────────────

  Widget _buildInputState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Empty-state icon + instruction
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.terminal_rounded,
                    color: AppTheme.textM, size: 36),
                  SizedBox(height: 12),
                  Text('Type a test message, then get a CLI command',
                    style: TextStyle(color: AppTheme.textM, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('The command runs locally with your own API key — your key never leaves your machine.',
                    style: TextStyle(color: AppTheme.textM, fontSize: 11),
                    textAlign: TextAlign.center),
                ],
              ),
            ),
          ),

          // Message input + Generate button
          TextField(
            controller: _messageCtrl,
            maxLength: 2000,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(color: AppTheme.textH, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Type a message... (Use #mission and @agent)',
              hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
              counterText: '',
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
              ),
            ),
            onSubmitted: (_) => _generateTrial(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _HoverButton(
              onPressed: _generateTrial,
              color: AppTheme.gold,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.terminal_rounded, size: 16, color: AppTheme.bg),
                  SizedBox(width: 8),
                  Text('Generate Trial Command',
                    style: TextStyle(
                      color: AppTheme.bg,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── State 3: Command display ─────────────────────────────────────────────

  Widget _buildCommandDisplay(String command) {
    // Terminal styling uses intentional dark colors for code-block appearance
    const terminalBg = Color(0xFF1E1E1E);
    const terminalBorder = Color(0xFF333333);
    const terminalGreen = Color(0xFF4EC9B0);
    const terminalGrey = Color(0xFF808080);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Terminal-style command block
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: terminalBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: terminalBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _terminalDot(AppTheme.primary),
                  const SizedBox(width: 6),
                  _terminalDot(AppTheme.gold),
                  const SizedBox(width: 6),
                  _terminalDot(AppTheme.success),
                  const SizedBox(width: 12),
                  const Text('Terminal',
                    style: TextStyle(color: terminalGrey, fontSize: 11)),
                  const Spacer(),
                  _CopyButton(text: command),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                command,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: terminalGreen,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.gold, size: 16),
                  SizedBox(width: 8),
                  Text('How to run',
                    style: TextStyle(color: AppTheme.textH, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              _instructionStep('1', 'Copy the command above'),
              const SizedBox(height: 8),
              _instructionStep('2', 'Open your terminal (Terminal, PowerShell, or Command Prompt)'),
              const SizedBox(height: 8),
              _instructionStep('3', 'Paste and run — you\'ll be asked for your API key'),
              const SizedBox(height: 8),
              _instructionStep('4', 'Your API key stays on your machine and is never sent to us'),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.gold.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  const Text('Requires Node.js installed',
                    style: TextStyle(color: AppTheme.textM, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Post-command purchase CTA
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                'Liked this agent? Purchase for ${widget.agent.price.toStringAsFixed(2)} MON to use it with $_selectedProviderLabel',
                style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _HoverButton(
                  onPressed: widget.onBuy,
                  color: AppTheme.gold,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 16, color: AppTheme.bg),
                      const SizedBox(width: 8),
                      Text(
                        'Purchase for ${widget.agent.price.toStringAsFixed(2)} MON',
                        style: const TextStyle(
                          color: AppTheme.bg,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── State 4: Trial used (no command) — clear feedback + purchase CTA ─────

  Widget _buildPurchaseCTA() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Prominent icon indicating the trial was consumed
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.timer_off_outlined, size: 36, color: AppTheme.gold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Trial Already Used',
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You\'ve already tested this agent.\nPurchase it for unlimited access.',
              style: TextStyle(color: AppTheme.textB, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Purchase button
            SizedBox(
              width: 280,
              child: _HoverButton(
                onPressed: widget.onBuy,
                color: AppTheme.gold,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_outlined, size: 16, color: AppTheme.bg),
                    const SizedBox(width: 8),
                    Text(
                      'Buy Agent  \u2014  ${widget.agent.price.toStringAsFixed(2)} MON',
                      style: const TextStyle(
                        color: AppTheme.bg,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary hint
            Text(
              'Full prompt + unlimited chat included',
              style: TextStyle(
                color: AppTheme.textM.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Instruction step helper ──────────────────────────────────────────────

  Widget _instructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(number,
              style: const TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
            style: const TextStyle(color: AppTheme.textB, fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Copy button with "Copied!" feedback
// ══════════════════════════════════════════════════════════════════════════════

class _CopyButton extends StatefulWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Command copied to clipboard!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  // Terminal styling — intentional colors for code-block appearance
  static const _terminalGreen = Color(0xFF4EC9B0);
  static const _terminalGrey = Color(0xFF808080);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _copy,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _copied
                ? _terminalGreen.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _copied
                  ? _terminalGreen.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 14,
              color: _copied ? _terminalGreen : _terminalGrey,
            ),
            const SizedBox(width: 4),
            Text(
              _copied ? 'Copied!' : 'Copy',
              style: TextStyle(
                color: _copied ? _terminalGreen : _terminalGrey,
                fontSize: 11,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Brand tool pill — styled brand badge + label for AI provider selector
// ══════════════════════════════════════════════════════════════════════════════

class _BrandToolPill extends StatefulWidget {
  final String label;
  final String iconAsset;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _BrandToolPill({
    required this.label,
    required this.iconAsset,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BrandToolPill> createState() => _BrandToolPillState();
}

class _BrandToolPillState extends State<_BrandToolPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.accentColor.withValues(alpha: 0.18)
                : (_hovered ? widget.accentColor.withValues(alpha: 0.08) : AppTheme.card2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? widget.accentColor.withValues(alpha: 0.7)
                  : (_hovered ? widget.accentColor.withValues(alpha: 0.4) : AppTheme.border),
              width: widget.isSelected ? 1.5 : 1.0,
            ),
            boxShadow: widget.isSelected
                ? [BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            // Brand SVG logo
            SvgPicture.asset(
              widget.iconAsset,
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 8),
            Text(widget.label,
              style: TextStyle(
                color: active ? widget.accentColor : AppTheme.textB,
                fontSize: 13,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
              )),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Reusable hover button with accent color fill
// ══════════════════════════════════════════════════════════════════════════════

class _HoverButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color color;
  final Widget child;

  const _HoverButton({
    required this.onPressed,
    required this.color,
    required this.child,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: disabled
                ? widget.color.withValues(alpha: 0.4)
                : (_hovered ? widget.color : widget.color.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _hovered && !disabled
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section header with icon
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.gold),
        const SizedBox(width: 8),
        Text(title,
          style: const TextStyle(color: AppTheme.textH, fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Quick stat item for the compact info bar
// ══════════════════════════════════════════════════════════════════════════════

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textM),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(color: AppTheme.textM, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textH,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Stat item for the stats row (kept for reference / internal usage)
// ══════════════════════════════════════════════════════════════════════════════

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.textM),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textH,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Badge chip (category / rarity)
// ══════════════════════════════════════════════════════════════════════════════

class _BadgeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _BadgeChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Purchased badge
// ══════════════════════════════════════════════════════════════════════════════

class _PurchasedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, color: AppTheme.success, size: 16),
        SizedBox(width: 6),
        Text('Purchased', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Hover icon button for the title row
// ══════════════════════════════════════════════════════════════════════════════

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _HoverIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? AppTheme.textM;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.card2 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              color: _hovered ? AppTheme.textH : baseColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Hover tag chip
// ══════════════════════════════════════════════════════════════════════════════

class _HoverTagChip extends StatefulWidget {
  final String tag;
  const _HoverTagChip({required this.tag});

  @override
  State<_HoverTagChip> createState() => _HoverTagChipState();
}

class _HoverTagChipState extends State<_HoverTagChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.card2.withValues(alpha: 0.8) : AppTheme.card2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _hovered ? AppTheme.border2 : AppTheme.border),
        ),
        child: Text('#${widget.tag}',
          style: TextStyle(
            color: _hovered ? AppTheme.textB : AppTheme.textM,
            fontSize: 12,
          )),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Similar agent card with hover effect
// ══════════════════════════════════════════════════════════════════════════════

class _SimilarAgentCard extends StatefulWidget {
  final AgentModel agent;
  const _SimilarAgentCard({required this.agent});

  @override
  State<_SimilarAgentCard> createState() => _SimilarAgentCardState();
}

class _SimilarAgentCardState extends State<_SimilarAgentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final rc = agent.rarity.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/agent/${agent.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.card2 : AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? rc.withValues(alpha: 0.6) : rc.withValues(alpha: 0.3),
              width: _hovered ? 1.5 : 1.0,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: rc.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1)]
                : null,
          ),
          child: Column(children: [
            PixelCharacterWidget(
              characterType: agent.characterType, rarity: agent.rarity,
              size: 72, agentId: agent.id, generatedImage: agent.generatedImage,
              imageUrl: agent.imageUrl),
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
              const Icon(Icons.bookmark_outline_rounded, size: 11, color: AppTheme.textM),
              const SizedBox(width: 3),
              Text('${agent.saveCount}', style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
              const SizedBox(width: 10),
              const Icon(Icons.play_circle_outline_rounded, size: 11, color: AppTheme.textM),
              const SizedBox(width: 3),
              Text('${agent.useCount}', style: const TextStyle(color: AppTheme.textM, fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }
}
