// lib/features/legend/screens/observability_screen.dart
//
// v3.11.3 — T8 — Drill-down panel for a single Legend execution.
//
// Top: 5 summary cards (totals + duration formatted).
// Middle: per-node duration bar chart (CustomPainter).
// Bottom: DataTable with status, output preview (100 char), duration, credits.
//
// Reads execution detail via ApiService.getExecution. Renders shimmer
// placeholders during load and a friendly EmptyState when the execution
// can't be found (404 / not owned by wallet).

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../models/workflow_models.dart';
import '../widgets/observability_chart.dart';

class ObservabilityScreen extends StatefulWidget {
  final int executionId;

  /// Optional pre-fetched execution — primarily used by tests so we can
  /// bypass ApiService without a network round-trip.
  final WorkflowExecution? executionOverride;

  const ObservabilityScreen({
    super.key,
    required this.executionId,
    this.executionOverride,
  });

  @override
  State<ObservabilityScreen> createState() => _ObservabilityScreenState();
}

class _ObservabilityScreenState extends State<ObservabilityScreen> {
  WorkflowExecution? _execution;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.executionOverride != null) {
      _execution = widget.executionOverride;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await ApiService.instance.getExecution(widget.executionId);
      if (!mounted) return;
      setState(() {
        _execution = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  String _fmtDuration(Duration? d) {
    if (d == null) return '—';
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    if (d.inSeconds < 60) return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m}m ${s}s';
  }

  String _previewOutput(String s) {
    final trimmed = s.trim();
    if (trimmed.length <= 100) return trimmed;
    return '${trimmed.substring(0, 100)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? _buildLoading()
              : (_loadError != null
                  ? _buildEmpty(message: _loadError)
                  : (_execution == null ? _buildEmpty() : _buildContent())),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const ShimmerScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShimmerBox(width: double.infinity, height: 56, color: AppTheme.card),
          SizedBox(height: 16),
          ShimmerBox(width: double.infinity, height: 90, color: AppTheme.card),
          SizedBox(height: 16),
          ShimmerBox(width: double.infinity, height: 220, color: AppTheme.card),
        ],
      ),
    );
  }

  Widget _buildEmpty({String? message}) {
    return EmptyState(
      icon: message != null ? Icons.error_outline_rounded : Icons.search_off_rounded,
      title: message != null ? 'Load Failed' : 'Execution not found',
      subtitle: message ??
          'Execution #${widget.executionId} could not be loaded. It may have been deleted or you may not be the owner.',
      actionLabel: 'Back',
      onAction: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildContent() {
    final exec = _execution!;
    final completed = exec.nodeResults.where((r) => !r.hasError).length;
    final failed = exec.nodeResults.where((r) => r.hasError).length;
    final totalDurationMs = exec.nodeResults.fold<int>(0, (a, r) => a + r.durationMs);

    final bars = exec.nodeResults
        .map((r) => ObservabilityBar(
              nodeId: r.nodeId,
              label: r.nodeLabel,
              durationMs: r.durationMs,
              status: r.hasError ? 'failed' : 'completed',
            ))
        .toList();

    return ListView(
      children: [
        PageHeader(
          icon: Icons.insights_rounded,
          iconColor: AppTheme.gold,
          title: 'Execution #${exec.id}',
          subtitle: '${exec.workflowName} · ${exec.status}',
        ),
        const SizedBox(height: 16),
        // Summary cards row
        LayoutBuilder(
          builder: (ctx, c) {
            final isNarrow = c.maxWidth < 768;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryCard(
                  label: 'Total Nodes',
                  value: '${exec.totalNodes}',
                  icon: Icons.account_tree_outlined,
                  color: AppTheme.textH,
                  width: isNarrow ? c.maxWidth : 180,
                ),
                _SummaryCard(
                  label: 'Completed',
                  value: '$completed',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.success,
                  width: isNarrow ? c.maxWidth : 180,
                ),
                _SummaryCard(
                  label: 'Failed',
                  value: '$failed',
                  icon: Icons.error_outline_rounded,
                  color: AppTheme.primary,
                  width: isNarrow ? c.maxWidth : 180,
                ),
                _SummaryCard(
                  label: 'Credits',
                  value: '${exec.creditsUsed}',
                  icon: Icons.bolt_outlined,
                  color: AppTheme.gold,
                  width: isNarrow ? c.maxWidth : 180,
                ),
                _SummaryCard(
                  label: 'Duration',
                  value: _fmtDuration(
                    exec.duration ?? Duration(milliseconds: totalDurationMs),
                  ),
                  icon: Icons.schedule_rounded,
                  color: AppTheme.info,
                  width: isNarrow ? c.maxWidth : 180,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        // Duration chart
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NODE DURATION',
                style: TextStyle(
                  color: AppTheme.textM,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ObservabilityChart(bars: bars),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Per-node table
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  'NODES',
                  style: TextStyle(
                    color: AppTheme.textM,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.surface),
                  dividerThickness: 0.5,
                  columns: const [
                    DataColumn(label: Text('Node', style: TextStyle(color: AppTheme.textH))),
                    DataColumn(label: Text('Status', style: TextStyle(color: AppTheme.textH))),
                    DataColumn(label: Text('Output', style: TextStyle(color: AppTheme.textH))),
                    DataColumn(label: Text('Duration', style: TextStyle(color: AppTheme.textH))),
                  ],
                  rows: exec.nodeResults
                      .map((r) => DataRow(cells: [
                            DataCell(Text(r.nodeId,
                                style: const TextStyle(
                                    color: AppTheme.textB,
                                    fontFamily: 'monospace',
                                    fontSize: 12))),
                            DataCell(_statusChip(r.hasError)),
                            DataCell(SizedBox(
                              width: 320,
                              child: Text(
                                _previewOutput(
                                  r.hasError ? (r.error ?? '') : r.output,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: r.hasError
                                      ? AppTheme.primary.withValues(alpha: 0.95)
                                      : AppTheme.textB,
                                  fontSize: 12,
                                ),
                              ),
                            )),
                            DataCell(Text('${r.durationMs}ms',
                                style: const TextStyle(color: AppTheme.textM))),
                          ]))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusChip(bool failed) {
    final color = failed ? AppTheme.primary : AppTheme.success;
    final label = failed ? 'FAILED' : 'OK';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textM,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
