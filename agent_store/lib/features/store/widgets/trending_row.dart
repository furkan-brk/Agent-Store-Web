import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../character/character_types.dart';

class TrendingRow extends StatefulWidget {
  const TrendingRow({super.key});

  @override
  State<TrendingRow> createState() => _TrendingRowState();
}

class _TrendingRowState extends State<TrendingRow> {
  List<AgentModel> _agents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final agents = await ApiService.instance.getTrending();
      if (mounted) setState(() { _agents = agents; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(children: [
            const Icon(Icons.local_fire_department_rounded, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            const Text(
              'TRENDING',
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 178,
          child: _loading ? _buildShimmer() : _buildList(),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppTheme.card, AppTheme.card2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppTheme.border),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_agents.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _agents.length,
      itemBuilder: (_, i) => _TrendingCard(agent: _agents[i], rank: i + 1),
    );
  }
}

class _TrendingCard extends StatefulWidget {
  final AgentModel agent;
  final int rank;
  const _TrendingCard({required this.agent, required this.rank});
  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rc = widget.agent.rarity.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/agent/${widget.agent.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 130,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? rc.withValues(alpha: 0.7) : rc.withValues(alpha: 0.3),
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: rc.withValues(alpha: 0.25), blurRadius: 14, spreadRadius: 1)]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
          ),
          child: Stack(children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                PixelCharacterWidget(
                  characterType: widget.agent.characterType,
                  rarity: widget.agent.rarity,
                  subclass: widget.agent.subclass,
                  size: 72,
                  agentId: widget.agent.id,
                  generatedImage: widget.agent.generatedImage,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    widget.agent.title,
                    style: const TextStyle(
                      color: AppTheme.textH,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bookmarks_outlined, size: 10, color: AppTheme.textM),
                    const SizedBox(width: 3),
                    Text(
                      '${widget.agent.saveCount}',
                      style: const TextStyle(color: AppTheme.textM, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
            // Rank badge
            if (widget.rank <= 3)
              Positioned(
                top: 6, left: 6,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: widget.rank == 1
                        ? AppTheme.gold
                        : widget.rank == 2
                            ? const Color(0xFF8A9A9A)
                            : const Color(0xFF8B6350),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#${widget.rank}',
                      style: const TextStyle(
                        color: Color(0xFF1E1A14),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
