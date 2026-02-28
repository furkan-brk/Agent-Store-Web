import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../store/widgets/agent_card.dart';

class PublicProfileScreen extends StatefulWidget {
  final String wallet;
  const PublicProfileScreen({super.key, required this.wallet});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _profile;
  List<AgentModel> _createdAgents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.instance.getPublicProfile(widget.wallet);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _error = 'Profile not found.';
          _loading = false;
        });
        return;
      }
      final rawAgents = result['agents'] as List<dynamic>? ?? [];
      final agents = rawAgents
          .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _profile = result;
        _createdAgents = agents;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load profile.';
          _loading = false;
        });
      }
    }
  }

  String _shortenWallet(String wallet) {
    if (wallet.length <= 10) return wallet;
    return '${wallet.substring(0, 6)}...${wallet.substring(wallet.length - 4)}';
  }

  int get _agentCount {
    if (_profile != null && _profile!.containsKey('agent_count')) {
      return (_profile!['agent_count'] as num?)?.toInt() ?? _createdAgents.length;
    }
    return _createdAgents.length;
  }

  int get _totalSaves {
    if (_profile != null && _profile!.containsKey('total_saves')) {
      return (_profile!['total_saves'] as num?)?.toInt() ?? 0;
    }
    return _createdAgents.fold(0, (sum, a) => sum + a.saveCount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDD1BB),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFF7A6E52), size: 56),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF6B5A40), fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Retry', style: TextStyle(color: Color(0xFF81231E))),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(child: _buildProfileHeader()),
            if (_createdAgents.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_outlined, color: Color(0xFFC0B490), size: 56),
                      SizedBox(height: 12),
                      Text(
                        'No agents created yet',
                        style: TextStyle(color: Color(0xFF6B5A40), fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => AgentCard(agent: _createdAgents[i]),
                    childCount: _createdAgents.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: const Color(0xFFC8BA9A),
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
      title: Text(
        _shortenWallet(widget.wallet),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      color: const Color(0xFFC8BA9A),
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF81231E).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF81231E).withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(Icons.person_outline, color: Color(0xFF81231E), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _shortenWallet(widget.wallet),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  _StatChip(label: 'Agents', value: '$_agentCount'),
                  const SizedBox(width: 12),
                  _VerticalDivider(),
                  const SizedBox(width: 12),
                  _StatChip(label: 'Total Saves', value: '$_totalSaves'),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFADA07A), height: 1),
          const SizedBox(height: 16),
          const Text(
            'Created Agents',
            style: TextStyle(
              color: Color(0xFF6B5A40),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          TextSpan(
            text: '  $label',
            style: const TextStyle(color: Color(0xFF7A6E52), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 14,
    color: const Color(0xFFC0B490),
  );
}
