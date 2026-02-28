import 'package:flutter/material.dart';
import 'package:agent_store/features/character/character_types.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import 'radar_chart_widget.dart';

class CompareModal extends StatefulWidget {
  final AgentModel baseAgent;
  const CompareModal({super.key, required this.baseAgent});

  @override
  State<CompareModal> createState() => _CompareModalState();
}

class _CompareModalState extends State<CompareModal> {
  AgentModel? _compareAgent;
  List<AgentModel> _agents = [];
  bool _loadingAgents = true;

  static const _statLabels = ['intelligence', 'power', 'speed', 'creativity', 'defense'];

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    final result = await ApiService.instance.listAgents(limit: 50);
    if (mounted) {
      setState(() {
        _agents = result.agents.where((a) => a.id != widget.baseAgent.id).toList();
        _loadingAgents = false;
      });
    }
  }

  /// Returns the stat value for a given label key, checking both exact and
  /// partial key matches (e.g. 'intelligence' matches 'INT' or 'intelligence').
  int _getStat(Map<String, int> stats, String label) {
    // Try exact match first
    if (stats.containsKey(label)) return stats[label]!;
    // Try case-insensitive prefix match
    for (final entry in stats.entries) {
      if (entry.key.toLowerCase().startsWith(label.substring(0, 3))) {
        return entry.value;
      }
    }
    // Fallback: return value by index position using _statLabels order
    final idx = _statLabels.indexOf(label);
    if (idx >= 0 && idx < stats.values.length) {
      return stats.values.elementAt(idx);
    }
    return 0;
  }

  /// Builds a single stat comparison row with two colored bars.
  Widget _statRow(String label, int baseVal, int compareVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF9E8F72),
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
          // Base bar (left-aligned, grows right)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: baseVal / 100,
                    backgroundColor: const Color(0xFF282918),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF81231E)),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              '$baseVal vs $compareVal',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7A6E52),
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Compare bar (left-aligned, grows right)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: compareVal / 100,
                    backgroundColor: const Color(0xFF282918),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF9B7B1A)),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a metadata comparison row (rarity, category, price).
  Widget _metaRow(String label, String baseVal, String compareVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9E8F72),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF81231E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF81231E).withValues(alpha: 0.3)),
              ),
              child: Text(
                baseVal,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF81231E),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9B7B1A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF9B7B1A).withValues(alpha: 0.3)),
              ),
              child: Text(
                compareVal,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9B7B1A),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _agentPanel({
    required AgentModel agent,
    required Color accentColor,
    required String panelLabel,
  }) {
    return Expanded(
      child: Column(
        children: [
          // Panel label chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              panelLabel,
              style: TextStyle(
                color: accentColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          PixelCharacterWidget(
            characterType: agent.characterType,
            rarity: agent.rarity,
            size: 64,
            showName: true,
            showRarity: true,
            agentId: agent.id,
            generatedImage: agent.generatedImage,
          ),
          const SizedBox(height: 12),
          Text(
            agent.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          if (agent.stats.isNotEmpty)
            RadarChartWidget(
              stats: agent.stats,
              color: agent.characterType.primaryColor,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseAgent;

    return Dialog(
      backgroundColor: const Color(0xFF22231A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF3D3E2A)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF3D3E2A)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows, color: Color(0xFF81231E), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Compare Agents',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF9E8F72)),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top panels: base | VS | compare
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left — base agent
                          _agentPanel(
                            agent: base,
                            accentColor: const Color(0xFF81231E),
                            panelLabel: 'BASE',
                          ),

                          // VS divider
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'VS',
                                  style: TextStyle(
                                    color: Color(0xFF81231E),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Right — compare agent
                          Expanded(
                            child: Column(
                              children: [
                                // Panel label
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9B7B1A).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF9B7B1A).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    'COMPARE',
                                    style: TextStyle(
                                      color: Color(0xFF9B7B1A),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Dropdown selector
                                if (_loadingAgents)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2A2B1E),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF3D3E2A)),
                                    ),
                                    child: DropdownButton<AgentModel>(
                                      value: _compareAgent,
                                      hint: const Text(
                                        'Select agent...',
                                        style: TextStyle(color: Color(0xFF7A6E52), fontSize: 13),
                                      ),
                                      isExpanded: true,
                                      underline: const SizedBox.shrink(),
                                      dropdownColor: const Color(0xFF2A2B1E),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Color(0xFF7A6E52),
                                      ),
                                      items: _agents.map((a) {
                                        return DropdownMenuItem<AgentModel>(
                                          value: a,
                                          child: Text(
                                            a.title,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (selected) {
                                        setState(() => _compareAgent = selected);
                                      },
                                    ),
                                  ),

                                // Show compare agent card once selected
                                if (_compareAgent != null) ...[
                                  const SizedBox(height: 12),
                                  PixelCharacterWidget(
                                    characterType: _compareAgent!.characterType,
                                    rarity: _compareAgent!.rarity,
                                    size: 64,
                                    showName: true,
                                    showRarity: true,
                                    agentId: _compareAgent!.id,
                                    generatedImage: _compareAgent!.generatedImage,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _compareAgent!.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  if (_compareAgent!.stats.isNotEmpty)
                                    RadarChartWidget(
                                      stats: _compareAgent!.stats,
                                      color: _compareAgent!.characterType.primaryColor,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Stats & meta comparison (only when both selected) ───
                    if (_compareAgent != null) ...[
                      const SizedBox(height: 28),
                      const Divider(color: Color(0xFF3D3E2A)),
                      const SizedBox(height: 16),

                      const Text(
                        'STAT COMPARISON',
                        style: TextStyle(
                          color: Color(0xFF7A6E52),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stat bars
                      ..._statLabels.map((label) {
                        final baseVal = _getStat(base.stats, label);
                        final compareVal = _getStat(_compareAgent!.stats, label);
                        return _statRow(label, baseVal, compareVal);
                      }),

                      const SizedBox(height: 20),
                      const Text(
                        'DETAILS',
                        style: TextStyle(
                          color: Color(0xFF7A6E52),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _metaRow(
                        'Rarity',
                        base.rarity.displayName,
                        _compareAgent!.rarity.displayName,
                      ),
                      _metaRow(
                        'Category',
                        base.category.isEmpty ? '—' : base.category,
                        _compareAgent!.category.isEmpty ? '—' : _compareAgent!.category,
                      ),
                      _metaRow(
                        'Price',
                        base.price == 0 ? 'Free' : '${base.price.toStringAsFixed(2)} MON',
                        _compareAgent!.price == 0
                            ? 'Free'
                            : '${_compareAgent!.price.toStringAsFixed(2)} MON',
                      ),
                      _metaRow(
                        'Saves',
                        '${base.saveCount}',
                        '${_compareAgent!.saveCount}',
                      ),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
