import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../character/character_types.dart';

class SimilarAgentsWidget extends StatefulWidget {
  final String category;
  final int excludeId;

  const SimilarAgentsWidget({
    super.key,
    required this.category,
    required this.excludeId,
  });

  @override
  State<SimilarAgentsWidget> createState() => _SimilarAgentsWidgetState();
}

class _SimilarAgentsWidgetState extends State<SimilarAgentsWidget> {
  List<AgentModel> _agents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ApiService.instance.listAgents(
        category: widget.category,
        limit: 8,
      );
      final filtered = result.agents
          .where((a) => a.id != widget.excludeId)
          .take(4)
          .toList();
      if (mounted) setState(() { _agents = filtered; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_agents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Color(0xFFC0B490), size: 48),
            SizedBox(height: 12),
            Text(
              'No similar agents found',
              style: TextStyle(color: Color(0xFF6B5A40), fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _agents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _SimilarCard(agent: _agents[i]),
    );
  }
}

class _SimilarCard extends StatelessWidget {
  final AgentModel agent;
  const _SimilarCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    final rc = agent.rarity.color;
    return InkWell(
      onTap: () => context.go('/agent/${agent.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8DEC9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: rc.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            PixelCharacterWidget(
              characterType: agent.characterType,
              rarity: agent.rarity,
              subclass: agent.subclass,
              size: 56,
              agentId: agent.id,
              generatedImage: agent.generatedImage,
              imageUrl: agent.imageUrl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agent.title,
                    style: const TextStyle(
                      color: Color(0xFF2B2C1E),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    agent.description,
                    style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.bookmarks_outlined, size: 11, color: Color(0xFF7A6E52)),
                      const SizedBox(width: 3),
                      Text(
                        '${agent.saveCount}',
                        style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF5A5038), size: 18),
          ],
        ),
      ),
    );
  }
}
