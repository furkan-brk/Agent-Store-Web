// lib/features/agent_detail/widgets/similar_agents_ribbon.dart
//
// Horizontal AgentCard ribbon shown at the bottom of the Agent Detail
// "Details" tab. Fetches `/agents/:id/similar` once on initState; hides
// itself silently on empty result or transport error so the page never
// looks broken.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../store/widgets/agent_card.dart';

class SimilarAgentsRibbon extends StatefulWidget {
  final int agentId;

  /// Override hook for tests — when non-null, used instead of the singleton
  /// ApiService. Production callers leave this null.
  final Future<List<AgentModel>> Function(int id)? fetchOverride;

  /// Override hook for tests — when non-null, used to build each card slot
  /// instead of the production AgentCard. Lets unit tests assert on the
  /// loaded path without pulling AgentCard's hover animations into the
  /// test scheduler. Production callers leave this null.
  final Widget Function(BuildContext, AgentModel)? cardBuilder;

  const SimilarAgentsRibbon({
    super.key,
    required this.agentId,
    this.fetchOverride,
    this.cardBuilder,
  });

  @override
  State<SimilarAgentsRibbon> createState() => _SimilarAgentsRibbonState();
}

class _SimilarAgentsRibbonState extends State<SimilarAgentsRibbon> {
  bool _loading = true;
  List<AgentModel> _agents = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final fetcher = widget.fetchOverride ??
          (id) => ApiService.instance.getSimilarAgents(id, limit: 5);
      final result = await fetcher(widget.agentId);
      if (!mounted) return;
      setState(() {
        _agents = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _agents = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide entirely once we know there are no similar agents — keeps the
    // page tidy instead of showing an empty section.
    if (!_loading && _agents.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 24),
          Row(children: [
            const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.gold),
            const SizedBox(width: 8),
            const Text(
              'Similar agents',
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            if (!_loading)
              Text(
                '· ${_agents.length}',
                style: const TextStyle(color: AppTheme.textM, fontSize: 12),
              ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: _loading ? _buildSkeleton() : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ShimmerScope(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SizedBox(
          width: 180,
          height: 220,
          child: ShimmerBox(
            width: 180,
            height: 220,
            radius: 14,
            color: AppTheme.card2,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final builder = widget.cardBuilder;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _agents.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (ctx, i) => SizedBox(
        width: 200,
        child: builder != null
            ? builder(ctx, _agents[i])
            : AgentCard(agent: _agents[i]),
      ),
    );
  }
}
