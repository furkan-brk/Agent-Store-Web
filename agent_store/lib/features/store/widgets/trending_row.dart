import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Text(
            '🔥 TRENDING',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
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
            colors: [Color(0xFF13131F), Color(0xFF1F1F2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFF1E1E35)),
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
      itemBuilder: (_, i) => _TrendingCard(agent: _agents[i]),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final AgentModel agent;
  const _TrendingCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    final rc = agent.rarity.color;
    return GestureDetector(
      onTap: () => context.go('/agent/${agent.id}'),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rc.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: rc.withValues(alpha: 0.08), blurRadius: 8)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            PixelCharacterWidget(
              characterType: agent.characterType,
              rarity: agent.rarity,
              subclass: agent.subclass,
              size: 72,
              agentId: agent.id,
              generatedImage: agent.generatedImage,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                agent.title,
                style: const TextStyle(
                  color: Colors.white,
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
                const Icon(Icons.bookmarks_outlined, size: 10, color: Color(0xFF6B7280)),
                const SizedBox(width: 3),
                Text(
                  '${agent.saveCount}',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
