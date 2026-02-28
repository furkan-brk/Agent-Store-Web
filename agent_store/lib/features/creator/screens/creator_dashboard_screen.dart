import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../../features/character/character_types.dart';

class CreatorDashboardScreen extends StatefulWidget {
  const CreatorDashboardScreen({super.key});

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
  List<AgentModel> _agents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!ApiService.instance.isAuthenticated) {
      setState(() { _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    final data = await ApiService.instance.getUserProfile();
    if (!mounted) return;
    if (data != null) {
      final rawAgents = data['created_agents'] as List<dynamic>? ?? [];
      final agents = rawAgents
          .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _agents = agents;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = 'Failed to load creator stats.';
      });
    }
  }

  int get _totalSaves => _agents.fold(0, (s, a) => s + a.saveCount);
  int get _totalUses  => _agents.fold(0, (s, a) => s + a.useCount);
  double get _totalRevenue =>
      _agents.fold(0.0, (s, a) => s + (a.price > 0 ? a.price : 0.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181910),
      body: Column(children: [
        _buildHeader(),
        const Divider(height: 1, color: Color(0xFF3D3E2A)),
        if (!ApiService.instance.isAuthenticated)
          _buildUnauthState()
        else if (_loading)
          const Expanded(child: Center(
            child: CircularProgressIndicator(color: Color(0xFF81231E))))
        else if (_error != null)
          Expanded(child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: Color(0xFF81231E), size: 48),
              const SizedBox(height: 12),
              Text(_error!,
                style: const TextStyle(color: Color(0xFF81231E), fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF81231E)),
                child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
              ),
            ])))
        else
          Expanded(child: _buildContent()),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
    color: const Color(0xFF22231A),
    child: Row(children: [
      const Icon(Icons.analytics_outlined, color: Color(0xFF81231E), size: 22),
      const SizedBox(width: 10),
      const Text('Creator Dashboard',
        style: TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const Spacer(),
      Text('${_agents.length} agents',
        style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 12)),
      const SizedBox(width: 12),
      IconButton(
        onPressed: _load,
        icon: const Icon(Icons.refresh, color: Color(0xFF7A6E52), size: 18),
        tooltip: 'Refresh',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
    ]),
  );

  Widget _buildUnauthState() => Expanded(
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.account_balance_wallet_outlined,
        color: Color(0xFF4A4A33), size: 64),
      const SizedBox(height: 16),
      const Text('Connect wallet to view your creator stats',
        style: TextStyle(color: Color(0xFF7A6E52), fontSize: 15)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: () => context.go('/wallet'),
        icon: const Icon(Icons.account_balance_wallet_outlined,
          color: Colors.white, size: 18),
        label: const Text('Connect Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81231E),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ])),
  );

  Widget _buildContent() {
    if (_agents.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.auto_awesome_outlined,
          color: Color(0xFF4A4A33), size: 64),
        const SizedBox(height: 16),
        const Text('No agents created yet',
          style: TextStyle(color: Color(0xFF7A6E52), fontSize: 15)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => context.go('/create'),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: const Text('Create Agent',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF81231E),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildStatsRow(),
        const SizedBox(height: 24),
        _buildAgentsTable(),
      ]),
    );
  }

  Widget _buildStatsRow() => LayoutBuilder(
    builder: (context, constraints) {
      return Row(children: [
        Expanded(child: _StatCard(
          icon: Icons.auto_awesome_outlined,
          value: '${_agents.length}',
          label: 'Total Agents',
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          icon: Icons.bookmark_border,
          value: '$_totalSaves',
          label: 'Total Saves',
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          icon: Icons.play_circle_outline,
          value: '$_totalUses',
          label: 'Total Uses',
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          icon: Icons.monetization_on_outlined,
          value: _totalRevenue > 0
              ? '${_totalRevenue.toStringAsFixed(1)} MON'
              : '0 MON',
          label: 'Total Revenue',
        )),
      ]);
    },
  );

  Widget _buildAgentsTable() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF22231A),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF3D3E2A)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Icon(Icons.table_chart_outlined,
            color: Color(0xFF81231E), size: 16),
          SizedBox(width: 8),
          Text('Agent Performance',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14)),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFF3D3E2A)),
      SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              const Color(0xFF2A2B1E)),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF81231E).withValues(alpha: 0.08);
              }
              return Colors.transparent;
            }),
            dividerThickness: 0.5,
            columnSpacing: 20,
            horizontalMargin: 16,
            headingTextStyle: const TextStyle(
              color: Color(0xFF7A6E52),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
            dataTextStyle: const TextStyle(
              color: Color(0xFFD0BF98),
              fontSize: 13,
            ),
            columns: const [
              DataColumn(label: Text('CHARACTER')),
              DataColumn(label: Text('TITLE')),
              DataColumn(label: Text('CATEGORY')),
              DataColumn(label: Text('SAVES')),
              DataColumn(label: Text('USES')),
              DataColumn(label: Text('PRICE')),
              DataColumn(label: Text('RARITY')),
            ],
            rows: _agents.map((agent) => DataRow(
              onSelectChanged: (_) => context.go('/agent/${agent.id}'),
              cells: [
                DataCell(SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: PixelCharacterWidget(
                      characterType: agent.characterType,
                      rarity: agent.rarity,
                      subclass: agent.subclass,
                      size: 32,
                      agentId: agent.id,
                      generatedImage: agent.generatedImage,
                    ),
                  ),
                )),
                DataCell(Text(
                  agent.title.length > 20
                      ? '${agent.title.substring(0, 20)}…'
                      : agent.title,
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
                )),
                DataCell(_CategoryChip(category: agent.category)),
                DataCell(Row(children: [
                  const Icon(Icons.bookmark_border,
                    color: Color(0xFF81231E), size: 14),
                  const SizedBox(width: 4),
                  Text('${agent.saveCount}',
                    style: const TextStyle(color: Color(0xFFD0BF98))),
                ])),
                DataCell(Row(children: [
                  const Icon(Icons.play_circle_outline,
                    color: Color(0xFF5A8A48), size: 14),
                  const SizedBox(width: 4),
                  Text('${agent.useCount}',
                    style: const TextStyle(color: Color(0xFFD0BF98))),
                ])),
                DataCell(Text(
                  agent.price == 0
                      ? 'Free'
                      : '${agent.price.toStringAsFixed(1)} MON',
                  style: TextStyle(
                    color: agent.price == 0
                        ? const Color(0xFF7A6E52)
                        : const Color(0xFF9B7B1A),
                    fontWeight: agent.price > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                )),
                DataCell(_RarityChip(rarity: agent.rarity)),
              ],
            )).toList(),
          ),
        ),
      ),
    ]),
  );
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF2A2B1E),
      borderRadius: BorderRadius.circular(10),
      border: const Border(
        top: BorderSide(color: Color(0xFF81231E), width: 2),
        left: BorderSide(color: Color(0xFF3D3E2A)),
        right: BorderSide(color: Color(0xFF3D3E2A)),
        bottom: BorderSide(color: Color(0xFF3D3E2A)),
      ),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: const Color(0xFF81231E), size: 18),
      const SizedBox(height: 8),
      Text(value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        )),
      const SizedBox(height: 2),
      Text(label,
        style: const TextStyle(
          color: Color(0xFF7A6E52),
          fontSize: 11,
        )),
    ]),
  );
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF3D3E2A),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      category.isEmpty ? '—' : category,
      style: const TextStyle(
        color: Color(0xFF9E8F72),
        fontSize: 11,
      ),
    ),
  );
}

class _RarityChip extends StatelessWidget {
  final CharacterRarity rarity;
  const _RarityChip({required this.rarity});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: rarity.gradientColors),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      rarity.displayName.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );
}
