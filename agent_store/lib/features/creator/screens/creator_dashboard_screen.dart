import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../controllers/creator_controller.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../../features/character/character_types.dart';

class CreatorDashboardScreen extends StatelessWidget {
  const CreatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(CreatorController());
    return Obx(() => Scaffold(
      backgroundColor: const Color(0xFFDDD1BB),
      body: Column(children: [
        _buildHeader(ctrl),
        const Divider(height: 1, color: Color(0xFFADA07A)),
        if (!ApiService.instance.isAuthenticated)
          _buildUnauthState(context)
        else if (ctrl.isLoading.value)
          const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF81231E))))
        else if (ctrl.error.value != null)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Color(0xFF81231E), size: 48),
            const SizedBox(height: 12),
            Text(ctrl.error.value!, style: const TextStyle(color: Color(0xFF81231E), fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: ctrl.load, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF81231E)), child: const Text('Retry', style: TextStyle(color: Colors.white))),
          ])))
        else
          Expanded(child: ctrl.agents.isEmpty ? _buildEmptyState(context) : _buildContent(ctrl)),
      ]),
    ));
  }

  Widget _buildHeader(CreatorController ctrl) => Container(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
    color: const Color(0xFFC8BA9A),
    child: Row(children: [
      const Icon(Icons.analytics_outlined, color: Color(0xFF81231E), size: 22),
      const SizedBox(width: 10),
      const Text('Creator Dashboard', style: TextStyle(color: Color(0xFF2B2C1E), fontSize: 20, fontWeight: FontWeight.bold)),
      const Spacer(),
      Obx(() => Text('${ctrl.agents.length} agents', style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 12))),
      const SizedBox(width: 12),
      IconButton(onPressed: ctrl.load, icon: const Icon(Icons.refresh, color: Color(0xFF7A6E52), size: 18), tooltip: 'Refresh', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
    ]),
  );

  Widget _buildUnauthState(BuildContext context) => Expanded(
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFC0B490), size: 64),
      const SizedBox(height: 16),
      const Text('Connect wallet to view your creator stats', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 15)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: () => context.go('/wallet'),
        icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 18),
        label: const Text('Connect Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF81231E), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
    ])),
  );

  Widget _buildEmptyState(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.auto_awesome_outlined, color: Color(0xFFC0B490), size: 64),
    const SizedBox(height: 16),
    const Text('No agents created yet', style: TextStyle(color: Color(0xFF7A6E52), fontSize: 15)),
    const SizedBox(height: 20),
    ElevatedButton.icon(
      onPressed: () => context.go('/create'),
      icon: const Icon(Icons.add, color: Colors.white, size: 18),
      label: const Text('Create Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF81231E), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    ),
  ]));

  Widget _buildContent(CreatorController ctrl) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildStatsRow(ctrl),
      const SizedBox(height: 24),
      _buildAgentsTable(ctrl),
    ]),
  );

  Widget _buildStatsRow(CreatorController ctrl) => Row(children: [
    Expanded(child: _StatCard(icon: Icons.auto_awesome_outlined, value: '${ctrl.agents.length}', label: 'Total Agents')),
    const SizedBox(width: 12),
    Expanded(child: _StatCard(icon: Icons.bookmark_border, value: '${ctrl.totalSaves}', label: 'Total Saves')),
    const SizedBox(width: 12),
    Expanded(child: _StatCard(icon: Icons.play_circle_outline, value: '${ctrl.totalUses}', label: 'Total Uses')),
    const SizedBox(width: 12),
    Expanded(child: _StatCard(icon: Icons.monetization_on_outlined, value: ctrl.totalRevenue > 0 ? '${ctrl.totalRevenue.toStringAsFixed(1)} MON' : '0 MON', label: 'Total Revenue')),
  ]);

  Widget _buildAgentsTable(CreatorController ctrl) => Container(
    decoration: BoxDecoration(color: const Color(0xFFC8BA9A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFADA07A))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: [
        Icon(Icons.table_chart_outlined, color: Color(0xFF81231E), size: 16), SizedBox(width: 8),
        Text('Agent Performance', style: TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.w600, fontSize: 14)),
      ])),
      const Divider(height: 1, color: Color(0xFFADA07A)),
      SizedBox(width: double.infinity, child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFE8DEC9)),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const Color(0xFF81231E).withValues(alpha: 0.08);
            return Colors.transparent;
          }),
          dividerThickness: 0.5, columnSpacing: 20, horizontalMargin: 16,
          headingTextStyle: const TextStyle(color: Color(0xFF7A6E52), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
          dataTextStyle: const TextStyle(color: Color(0xFF4A4033), fontSize: 13),
          columns: const [
            DataColumn(label: Text('CHARACTER')), DataColumn(label: Text('TITLE')),
            DataColumn(label: Text('CATEGORY')), DataColumn(label: Text('SAVES')),
            DataColumn(label: Text('USES')), DataColumn(label: Text('PRICE')),
            DataColumn(label: Text('RARITY')),
          ],
          rows: ctrl.agents.map((agent) => DataRow(
            onSelectChanged: (_) { /* go to agent detail */ },
            cells: [
              DataCell(SizedBox(width: 48, height: 48, child: Center(child: PixelCharacterWidget(characterType: agent.characterType, rarity: agent.rarity, subclass: agent.subclass, size: 32, agentId: agent.id, generatedImage: agent.generatedImage)))),
              DataCell(Text(agent.title.length > 20 ? '${agent.title.substring(0, 20)}…' : agent.title, style: const TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.w500))),
              DataCell(_CategoryChip(category: agent.category)),
              DataCell(Row(children: [const Icon(Icons.bookmark_border, color: Color(0xFF81231E), size: 14), const SizedBox(width: 4), Text('${agent.saveCount}', style: const TextStyle(color: Color(0xFF4A4033)))])),
              DataCell(Row(children: [const Icon(Icons.play_circle_outline, color: Color(0xFF5A8A48), size: 14), const SizedBox(width: 4), Text('${agent.useCount}', style: const TextStyle(color: Color(0xFF4A4033)))])),
              DataCell(Text(agent.price == 0 ? 'Free' : '${agent.price.toStringAsFixed(1)} MON', style: TextStyle(color: agent.price == 0 ? const Color(0xFF7A6E52) : const Color(0xFF9B7B1A), fontWeight: agent.price > 0 ? FontWeight.w600 : FontWeight.normal))),
              DataCell(_RarityChip(rarity: agent.rarity)),
            ],
          )).toList(),
        ),
      )),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon; final String value; final String label;
  const _StatCard({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFFE8DEC9), borderRadius: BorderRadius.circular(10), border: const Border(top: BorderSide(color: Color(0xFF81231E), width: 2), left: BorderSide(color: Color(0xFFADA07A)), right: BorderSide(color: Color(0xFFADA07A)), bottom: BorderSide(color: Color(0xFFADA07A)))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: const Color(0xFF81231E), size: 18), const SizedBox(height: 8),
      Text(value, style: const TextStyle(color: Color(0xFF2B2C1E), fontWeight: FontWeight.bold, fontSize: 22)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 11)),
    ]),
  );
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xFFADA07A), borderRadius: BorderRadius.circular(4)),
    child: Text(category.isEmpty ? '—' : category, style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 11)),
  );
}

class _RarityChip extends StatelessWidget {
  final CharacterRarity rarity;
  const _RarityChip({required this.rarity});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(gradient: LinearGradient(colors: rarity.gradientColors), borderRadius: BorderRadius.circular(4)),
    child: Text(rarity.displayName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
  );
}
