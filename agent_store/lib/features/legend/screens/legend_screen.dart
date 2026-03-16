// lib/features/legend/screens/legend_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/models/mission_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/mission_service.dart';
import '../models/workflow_models.dart';
import '../services/legend_service.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const double _kNodeW = 160.0;
const double _kNodeH = 72.0;

// ── Drag payload ──────────────────────────────────────────────────────────────

class _NodeDragData {
  final WorkflowNodeType type;
  final String label;
  final String? refId;
  const _NodeDragData(this.type, this.label, [this.refId]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  LegendScreen
// ─────────────────────────────────────────────────────────────────────────────

class LegendScreen extends StatefulWidget {
  const LegendScreen({super.key});

  @override
  State<LegendScreen> createState() => _LegendScreenState();
}

class _LegendScreenState extends State<LegendScreen> {
  // ── Canvas state ───────────────────────────────────────────────────────────
  List<WorkflowNode> _nodes = [];
  List<WorkflowEdge> _edges = [];
  Offset _canvasOffset = Offset.zero;
  String? _selectedNodeId;

  // Connect mode
  bool _connectMode = false;
  String? _connectFromId;

  // Canvas key to convert global offsets to local
  final GlobalKey _canvasKey = GlobalKey();

  // ── Palette data ───────────────────────────────────────────────────────────
  List<AgentModel> _libraryAgents = [];
  List<MissionModel> _missions = [];
  bool _loadingAgents = false;

  // ── Workflow persistence ───────────────────────────────────────────────────
  String _workflowName = 'My Workflow';
  String? _currentWorkflowId;
  List<LegendWorkflow> _savedWorkflows = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingAgents = true);
    final agents = ApiService.instance.isAuthenticated ? await ApiService.instance.getLibrary() : <AgentModel>[];
    if (!mounted) return;
    setState(() {
      _libraryAgents = agents;
      _missions = MissionService.instance.missions;
      _savedWorkflows = LegendService.instance.workflows;
      _loadingAgents = false;
    });
  }

  bool get _hasCanvasContent => _nodes.isNotEmpty || _edges.isNotEmpty;

  int get _workflowCount => _savedWorkflows.length;

  void _showNotice(String message, {Color background = AppTheme.info}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmReplaceCanvas(VoidCallback onConfirm) async {
    if (!_hasCanvasContent) {
      onConfirm();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text(
          'Replace current workflow?',
          style: TextStyle(color: AppTheme.textH),
        ),
        content: const Text(
          'Your current canvas will be cleared before creating a new workflow.',
          style: TextStyle(color: AppTheme.textM),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textM),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  void _startWorkflow({String? name}) {
    final workflowName = name?.trim().isNotEmpty == true ? name!.trim() : 'Workflow ${_workflowCount + 1}';
    final workflow = LegendService.instance.newWorkflow(workflowName);
    setState(() {
      _workflowName = workflow.name;
      _currentWorkflowId = workflow.id;
      _nodes = [];
      _edges = [];
      _selectedNodeId = null;
      _connectMode = false;
      _connectFromId = null;
      _canvasOffset = Offset.zero;
    });
  }

  void _showNewWorkflowDialog() {
    final ctrl = TextEditingController(
      text: 'Workflow ${_workflowCount + 1}',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text(
          'New Workflow',
          style: TextStyle(color: AppTheme.textH),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textH),
          decoration: const InputDecoration(hintText: 'Workflow name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textM),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              Navigator.pop(context);
              await _confirmReplaceCanvas(() => _startWorkflow(name: ctrl.text));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _buildStarterWorkflow() {
    final sourceMissions = _missions.take(2).toList();
    final sourceAgents = _libraryAgents.take(3).toList();
    if (sourceMissions.isEmpty && sourceAgents.isEmpty) {
      _showNotice(
        'Add at least one mission or library agent to create a starter workflow.',
        background: AppTheme.error,
      );
      return;
    }

    _confirmReplaceCanvas(() {
      final workflow = LegendService.instance.newWorkflow('Starter Workflow ${_workflowCount + 1}');
      final nodes = <WorkflowNode>[];
      final edges = <WorkflowEdge>[];
      var nextX = 100.0;
      const rowY = 160.0;

      void addNode(WorkflowNode node) {
        if (nodes.isNotEmpty) {
          final previous = nodes.last;
          edges.add(
            WorkflowEdge(
              id: '${previous.id}_${node.id}',
              fromId: previous.id,
              toId: node.id,
            ),
          );
        }
        nodes.add(node);
        nextX += 240;
      }

      addNode(
        WorkflowNode(
          id: '${workflow.id}_start',
          type: WorkflowNodeType.start,
          label: 'START',
          x: nextX,
          y: rowY,
        ),
      );

      for (final mission in sourceMissions) {
        addNode(
          WorkflowNode(
            id: '${workflow.id}_mission_${mission.slug}',
            type: WorkflowNodeType.mission,
            label: mission.title,
            x: nextX,
            y: rowY,
            refId: mission.slug,
          ),
        );
      }

      for (final agent in sourceAgents) {
        addNode(
          WorkflowNode(
            id: '${workflow.id}_agent_${agent.id}',
            type: WorkflowNodeType.agent,
            label: agent.title,
            x: nextX,
            y: rowY,
            refId: agent.id.toString(),
          ),
        );
      }

      addNode(
        WorkflowNode(
          id: '${workflow.id}_end',
          type: WorkflowNodeType.end,
          label: 'END',
          x: nextX,
          y: rowY,
        ),
      );

      setState(() {
        _workflowName = workflow.name;
        _currentWorkflowId = workflow.id;
        _nodes = nodes;
        _edges = edges;
        _selectedNodeId = null;
        _connectMode = false;
        _connectFromId = null;
        _canvasOffset = Offset.zero;
      });
      _showNotice('Starter workflow created', background: AppTheme.success);
    });
  }

  String? _validateWorkflow() {
    if (_workflowName.trim().isEmpty) {
      return 'Workflow name cannot be empty.';
    }
    if (_nodes.length < 2) {
      return 'Add at least two nodes before saving.';
    }

    final startCount = _nodes.where((node) => node.type == WorkflowNodeType.start).length;
    final endCount = _nodes.where((node) => node.type == WorkflowNodeType.end).length;

    if (startCount != 1 || endCount != 1) {
      return 'Each workflow needs exactly one Start and one End node.';
    }
    if (_edges.isEmpty) {
      return 'Create at least one connection before saving.';
    }

    final nodeIds = _nodes.map((node) => node.id).toSet();
    final hasBrokenEdge = _edges.any(
      (edge) => !nodeIds.contains(edge.fromId) || !nodeIds.contains(edge.toId),
    );
    if (hasBrokenEdge) {
      return 'One or more connections reference missing nodes.';
    }

    return null;
  }

  // ── Node creation ──────────────────────────────────────────────────────────

  void _addNode(_NodeDragData data, Offset globalDropPos) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalDropPos);
    final cx = local.dx - _canvasOffset.dx - _kNodeW / 2;
    final cy = local.dy - _canvasOffset.dy - _kNodeH / 2;

    final id = '${DateTime.now().millisecondsSinceEpoch}_${_nodes.length}';
    setState(() {
      _nodes.add(WorkflowNode(
        id: id,
        type: data.type,
        label: data.label,
        x: cx.clamp(0.0, 4000.0),
        y: cy.clamp(0.0, 3000.0),
        refId: data.refId,
      ));
    });
  }

  void _deleteSelected() {
    if (_selectedNodeId == null) return;
    setState(() {
      _edges.removeWhere(
        (e) => e.fromId == _selectedNodeId || e.toId == _selectedNodeId,
      );
      _nodes.removeWhere((n) => n.id == _selectedNodeId);
      _selectedNodeId = null;
    });
  }

  void _clearCanvas() {
    setState(() {
      _nodes.clear();
      _edges.clear();
      _selectedNodeId = null;
      _connectMode = false;
      _connectFromId = null;
    });
  }

  // ── Node move ──────────────────────────────────────────────────────────────

  void _moveNode(String id, Offset delta) {
    final idx = _nodes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    setState(() {
      final n = _nodes[idx];
      _nodes[idx] = WorkflowNode(
        id: n.id,
        type: n.type,
        label: n.label,
        x: (n.x + delta.dx).clamp(0.0, 4000.0),
        y: (n.y + delta.dy).clamp(0.0, 3000.0),
        refId: n.refId,
      );
    });
  }

  // ── Connect mode ───────────────────────────────────────────────────────────

  void _onNodeTap(WorkflowNode node) {
    if (!_connectMode) {
      setState(() => _selectedNodeId = node.id);
      return;
    }
    if (_connectFromId == null) {
      setState(() => _connectFromId = node.id);
      return;
    }
    if (_connectFromId != node.id) {
      // Prevent duplicate edges
      final alreadyExists = _edges.any(
        (e) => e.fromId == _connectFromId && e.toId == node.id,
      );
      if (!alreadyExists) {
        setState(() {
          _edges.add(WorkflowEdge(
            id: '${_connectFromId}_${node.id}',
            fromId: _connectFromId!,
            toId: node.id,
          ));
        });
      }
    }
    setState(() => _connectFromId = null);
  }

  void _toggleConnectMode() {
    setState(() {
      _connectMode = !_connectMode;
      _connectFromId = null;
      _selectedNodeId = null;
    });
  }

  // ── Canvas pan ─────────────────────────────────────────────────────────────

  void _onCanvasPan(DragUpdateDetails d) {
    setState(() => _canvasOffset += d.delta);
  }

  // ── Save / load ────────────────────────────────────────────────────────────

  Future<void> _saveWorkflow() async {
    final validationError = _validateWorkflow();
    if (validationError != null) {
      _showNotice(validationError, background: AppTheme.error);
      return;
    }

    final id = _currentWorkflowId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final wf = LegendWorkflow(
      id: id,
      name: _workflowName,
      nodes: List.of(_nodes),
      edges: List.of(_edges),
      updatedAt: DateTime.now(),
    );
    await LegendService.instance.saveWorkflow(wf);
    setState(() {
      _currentWorkflowId = id;
      _savedWorkflows = LegendService.instance.workflows;
    });
    _showNotice('Workflow "$_workflowName" saved', background: AppTheme.success);
  }

  void _loadWorkflow(LegendWorkflow wf) {
    setState(() {
      _nodes = List.of(wf.nodes);
      _edges = List.of(wf.edges);
      _workflowName = wf.name;
      _currentWorkflowId = wf.id;
      _selectedNodeId = null;
      _connectMode = false;
      _connectFromId = null;
      _canvasOffset = Offset.zero;
    });
    Navigator.of(context).pop();
  }

  Future<void> _deleteWorkflow(String id) async {
    await LegendService.instance.deleteWorkflow(id);
    setState(() => _savedWorkflows = LegendService.instance.workflows);
  }

  void _showRenameDialog() {
    final ctrl = TextEditingController(text: _workflowName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Rename Workflow', style: TextStyle(color: AppTheme.textH)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textH),
          decoration: const InputDecoration(hintText: 'Workflow name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) setState(() => _workflowName = v);
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showLoadDialog() {
    setState(() => _savedWorkflows = LegendService.instance.workflows);
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text('Load Workflow', style: TextStyle(color: AppTheme.textH)),
          content: SizedBox(
            width: 380,
            child: _savedWorkflows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No saved workflows.', style: TextStyle(color: AppTheme.textM)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _savedWorkflows.length,
                    itemBuilder: (_, i) {
                      final wf = _savedWorkflows[i];
                      return ListTile(
                        leading: const Icon(Icons.account_tree_outlined, color: AppTheme.gold),
                        title: Text(wf.name, style: const TextStyle(color: AppTheme.textH)),
                        subtitle: Text(
                          '${wf.nodes.length} nodes · ${wf.edges.length} edges',
                          style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textM),
                          onPressed: () async {
                            await _deleteWorkflow(wf.id);
                            setDlg(() {});
                          },
                        ),
                        onTap: () => _loadWorkflow(wf),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppTheme.textM)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Node name editing ──────────────────────────────────────────────────────

  void _showRenameNodeDialog(WorkflowNode node) {
    final ctrl = TextEditingController(text: node.label);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Rename Node', style: TextStyle(color: AppTheme.textH)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textH),
          decoration: const InputDecoration(hintText: 'Node label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) {
                final idx = _nodes.indexWhere((n) => n.id == node.id);
                if (idx >= 0) {
                  setState(() => _nodes[idx] = _nodes[idx].copyWith(label: v));
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLeftPanel(),
                const VerticalDivider(width: 1, color: AppTheme.border),
                Expanded(child: _buildCanvas()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Toolbar ────────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 18),
          const SizedBox(width: 8),
          const Text(
            'LEGEND',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _showRenameDialog,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '· $_workflowName',
                  style: TextStyle(
                    color: AppTheme.textM.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 12, color: AppTheme.textM),
              ],
            ),
          ),
          const Spacer(),
          _ToolbarButton(
            icon: Icons.add_box_outlined,
            label: 'New',
            onTap: _showNewWorkflowDialog,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.auto_fix_high_outlined,
            label: 'Starter',
            onTap: _buildStarterWorkflow,
          ),
          const SizedBox(width: 8),
          // Connect mode toggle
          _ToolbarButton(
            icon: Icons.cable_outlined,
            label: _connectMode ? 'Connecting…' : 'Connect',
            active: _connectMode,
            onTap: _toggleConnectMode,
          ),
          const SizedBox(width: 8),
          // Delete selected
          if (_selectedNodeId != null) ...[
            _ToolbarButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              danger: true,
              onTap: _deleteSelected,
            ),
            const SizedBox(width: 8),
          ],
          _ToolbarButton(
            icon: Icons.folder_open_outlined,
            label: 'Load',
            onTap: _showLoadDialog,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.save_outlined,
            label: 'Save',
            accent: true,
            onTap: _saveWorkflow,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.clear_all,
            label: 'Clear',
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.card,
                  title: const Text('Clear canvas?', style: TextStyle(color: AppTheme.textH)),
                  content: const Text(
                    'All nodes and edges will be removed.',
                    style: TextStyle(color: AppTheme.textM),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      onPressed: () {
                        Navigator.pop(context);
                        _clearCanvas();
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Left Panel ─────────────────────────────────────────────────────────────

  Widget _buildLeftPanel() {
    return Container(
      width: 220,
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WORKFLOW BUILDER',
                  style: TextStyle(
                    color: AppTheme.textM,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _workflowName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textH,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_nodes.length} nodes · ${_edges.length} edges · $_workflowCount saved',
                  style: const TextStyle(color: AppTheme.textM, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showNewWorkflowDialog,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Blank'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textH,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _buildStarterWorkflow,
                        icon: const Icon(Icons.bolt_outlined, size: 14),
                        label: const Text('Starter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.textH,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _PaletteSection(label: 'FLOW', children: [
            _DraggablePaletteItem(
              data: _NodeDragData(WorkflowNodeType.start, 'START'),
              color: AppTheme.success,
              icon: Icons.play_arrow_rounded,
              label: 'Start',
            ),
            _DraggablePaletteItem(
              data: _NodeDragData(WorkflowNodeType.end, 'END'),
              color: AppTheme.primary,
              icon: Icons.stop_rounded,
              label: 'End',
            ),
          ]),
          const SizedBox(height: 12),
          _PaletteSection(
            label: 'AGENTS',
            children: _loadingAgents
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    )
                  ]
                : _libraryAgents.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No library agents.\nAdd agents to library first.',
                            style: TextStyle(color: AppTheme.textM, fontSize: 11),
                          ),
                        )
                      ]
                    : _libraryAgents
                        .map(
                          (a) => _DraggablePaletteItem(
                            data: _NodeDragData(WorkflowNodeType.agent, a.title, a.id.toString()),
                            color: AppTheme.info,
                            icon: Icons.smart_toy_outlined,
                            label: a.title,
                          ),
                        )
                        .toList(),
          ),
          const SizedBox(height: 12),
          _PaletteSection(
            label: 'MISSIONS',
            children: _missions.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'No missions saved.\nCreate missions first.',
                        style: TextStyle(color: AppTheme.textM, fontSize: 11),
                      ),
                    )
                  ]
                : _missions
                    .map(
                      (m) => _DraggablePaletteItem(
                        data: _NodeDragData(WorkflowNodeType.mission, m.title, m.slug),
                        color: AppTheme.gold,
                        icon: Icons.flag_outlined,
                        label: m.title,
                        subtitle: '#${m.slug}',
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 16),
          // Quick tip
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Text(
              '💡 Drag items onto the canvas.\nUse Connect to draw edges.\nDouble-tap a node to rename.',
              style: TextStyle(color: AppTheme.textM, fontSize: 10, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Canvas ─────────────────────────────────────────────────────────────────

  Widget _buildCanvas() {
    return DragTarget<_NodeDragData>(
      onAcceptWithDetails: (d) => _addNode(d.data, d.offset),
      builder: (ctx, candidates, rejected) {
        final highlight = candidates.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.bg,
            border: highlight ? Border.all(color: AppTheme.primary, width: 2) : null,
          ),
          child: ClipRect(
            child: GestureDetector(
              onPanUpdate: _onCanvasPan,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                key: _canvasKey,
                clipBehavior: Clip.hardEdge,
                children: [
                  // Background grid
                  const Positioned.fill(child: _CanvasGrid()),

                  // Edge layer
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EdgePainter(
                        nodes: _nodes,
                        edges: _edges,
                        offset: _canvasOffset,
                        connectFromId: _connectFromId,
                      ),
                    ),
                  ),

                  // Nodes
                  for (final node in _nodes)
                    Positioned(
                      left: node.x + _canvasOffset.dx,
                      top: node.y + _canvasOffset.dy,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onNodeTap(node),
                        onDoubleTap: () => _showRenameNodeDialog(node),
                        onPanUpdate: (d) => _moveNode(node.id, d.delta),
                        child: _NodeCard(
                          node: node,
                          isSelected: _selectedNodeId == node.id,
                          isConnectSource: _connectFromId == node.id,
                          connectMode: _connectMode,
                        ),
                      ),
                    ),

                  // Empty state hint
                  if (_nodes.isEmpty)
                    const Center(
                      child: _CanvasEmptyHint(),
                    ),

                  // Connect mode banner
                  if (_connectMode)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.info),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cable_outlined, size: 14, color: AppTheme.info),
                            const SizedBox(width: 6),
                            Text(
                              _connectFromId == null ? 'Tap source node' : 'Tap target node',
                              style: const TextStyle(color: AppTheme.info, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool accent;
  final bool danger;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.accent = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = danger
        ? AppTheme.error
        : active
            ? AppTheme.info
            : accent
                ? AppTheme.gold
                : AppTheme.textB;
    final Color bg = danger
        ? AppTheme.error.withValues(alpha: 0.12)
        : active
            ? AppTheme.info.withValues(alpha: 0.15)
            : accent
                ? AppTheme.gold.withValues(alpha: 0.12)
                : AppTheme.card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: active || accent ? 0.5 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _PaletteSection extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _PaletteSection({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textM,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }
}

class _DraggablePaletteItem extends StatelessWidget {
  final _NodeDragData data;
  final Color color;
  final IconData icon;
  final String label;
  final String? subtitle;

  const _DraggablePaletteItem({
    required this.data,
    required this.color,
    required this.icon,
    required this.label,
    this.subtitle,
  });

  Widget _chip({bool dragging = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dragging ? color.withValues(alpha: 0.25) : AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dragging ? color : color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textH, fontSize: 12),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10)),
              ],
            ),
          ),
          const Icon(Icons.drag_indicator, size: 14, color: AppTheme.textM),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<_NodeDragData>(
      data: data,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(
            width: _kNodeW,
            child: _chip(dragging: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: _chip()),
      child: _chip(),
    );
  }
}

// ── Canvas empty hint ──────────────────────────────────────────────────────────

class _CanvasEmptyHint extends StatelessWidget {
  const _CanvasEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.account_tree_outlined, size: 56, color: AppTheme.textM.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text(
          'Drag agents and missions here',
          style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.5), fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'from the left panel to build your workflow',
          style: TextStyle(color: AppTheme.textM.withValues(alpha: 0.35), fontSize: 12),
        ),
      ],
    );
  }
}

// ── Canvas grid background ─────────────────────────────────────────────────────

class _CanvasGrid extends StatelessWidget {
  const _CanvasGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  static final _dotPaint = Paint()
    ..color = const Color(0xFF4A3D28).withValues(alpha: 0.6)
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1, _dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

// ── Node card ─────────────────────────────────────────────────────────────────

class _NodeCard extends StatelessWidget {
  final WorkflowNode node;
  final bool isSelected;
  final bool isConnectSource;
  final bool connectMode;

  const _NodeCard({
    required this.node,
    required this.isSelected,
    required this.isConnectSource,
    required this.connectMode,
  });

  Color get _accentColor {
    switch (node.type) {
      case WorkflowNodeType.start:
        return AppTheme.success;
      case WorkflowNodeType.agent:
        return AppTheme.info;
      case WorkflowNodeType.mission:
        return AppTheme.gold;
      case WorkflowNodeType.end:
        return AppTheme.primary;
    }
  }

  IconData get _icon {
    switch (node.type) {
      case WorkflowNodeType.start:
        return Icons.play_arrow_rounded;
      case WorkflowNodeType.agent:
        return Icons.smart_toy_outlined;
      case WorkflowNodeType.mission:
        return Icons.flag_outlined;
      case WorkflowNodeType.end:
        return Icons.stop_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final highlighted = isSelected || isConnectSource;

    return SizedBox(
      width: _kNodeW,
      height: _kNodeH,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted ? accent : (connectMode ? accent.withValues(alpha: 0.5) : AppTheme.border),
            width: highlighted ? 2 : 1,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Type badge row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_icon, size: 10, color: accent),
                        const SizedBox(width: 3),
                        Text(
                          node.type.label.toUpperCase(),
                          style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                node.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textH,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edge painter ──────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  final List<WorkflowNode> nodes;
  final List<WorkflowEdge> edges;
  final Offset offset;
  final String? connectFromId;

  const _EdgePainter({
    required this.nodes,
    required this.edges,
    required this.offset,
    this.connectFromId,
  });

  Offset _outputPort(WorkflowNode n) => Offset(n.x + offset.dx + _kNodeW, n.y + offset.dy + _kNodeH / 2);

  Offset _inputPort(WorkflowNode n) => Offset(n.x + offset.dx, n.y + offset.dy + _kNodeH / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = AppTheme.border2
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = AppTheme.gold
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final from = _nodeById(edge.fromId);
      final to = _nodeById(edge.toId);
      if (from == null || to == null) continue;

      final src = _outputPort(from);
      final dst = _inputPort(to);

      final paint = (connectFromId != null && (edge.fromId == connectFromId || edge.toId == connectFromId))
          ? activePaint
          : edgePaint;

      _drawBezier(canvas, src, dst, paint);

      // Arrowhead
      _drawArrow(canvas, dst, math.atan2(dst.dy - src.dy, dst.dx - src.dx), paint);
    }

    // Port circles on every node
    final portPaint = Paint()
      ..color = AppTheme.border2
      ..style = PaintingStyle.fill;
    final fromPortPaint = Paint()
      ..color = AppTheme.gold
      ..style = PaintingStyle.fill;

    for (final n in nodes) {
      final out = _outputPort(n);
      final inp = _inputPort(n);
      final p = (connectFromId == n.id) ? fromPortPaint : portPaint;
      canvas.drawCircle(out, 5, p);
      canvas.drawCircle(inp, 5, p);
    }
  }

  void _drawBezier(Canvas canvas, Offset src, Offset dst, Paint paint) {
    final dx = (dst.dx - src.dx).abs().clamp(60.0, 200.0);
    final path = Path()
      ..moveTo(src.dx, src.dy)
      ..cubicTo(
        src.dx + dx * 0.5,
        src.dy,
        dst.dx - dx * 0.5,
        dst.dy,
        dst.dx,
        dst.dy,
      );
    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Offset tip, double angle, Paint paint) {
    const size = 8.0;
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(
      tip.dx - size * math.cos(angle - 0.4),
      tip.dy - size * math.sin(angle - 0.4),
    );
    path.lineTo(
      tip.dx - size * math.cos(angle + 0.4),
      tip.dy - size * math.sin(angle + 0.4),
    );
    path.close();
    canvas.drawPath(path, arrowPaint);
  }

  WorkflowNode? _nodeById(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edges != edges || old.nodes != nodes || old.offset != offset || old.connectFromId != connectFromId;
}
