// lib/features/legend/screens/legend_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../features/character/character_types.dart';
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

  // Port dragging (format: "nodeId_output" or "nodeId_input")
  String? _dragFromPort;
  Offset _dragCurrentOffset = Offset.zero;

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
    try {
      await MissionService.instance.refresh();
      await LegendService.instance.refresh();
      final agents = ApiService.instance.isAuthenticated ? await ApiService.instance.getLibrary() : <AgentModel>[];
      if (!mounted) return;
      setState(() {
        _libraryAgents = agents;
        _missions = MissionService.instance.missions;
        _savedWorkflows = LegendService.instance.workflows;
        _loadingAgents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _libraryAgents = <AgentModel>[];
        _missions = MissionService.instance.missions;
        _savedWorkflows = LegendService.instance.workflows;
        _loadingAgents = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotice(
          'Legend data could not be loaded. Please try again.',
          background: AppTheme.error,
        );
      });
    }
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
      _dragFromPort = null;
      _dragCurrentOffset = Offset.zero;
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
        _dragFromPort = null;
        _dragCurrentOffset = Offset.zero;
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
      _dragFromPort = null;
      _dragCurrentOffset = Offset.zero;
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
    setState(() => _selectedNodeId = node.id);
  }

  void _onPortDragStart(String portId) {
    setState(() {
      _dragFromPort = portId;
      _dragCurrentOffset = Offset.zero;
    });
  }

  void _onPortDragUpdate(Offset globalOffset) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    setState(() => _dragCurrentOffset = local);
  }

  void _onPortDragEnd(String? toPortId) {
    final fromPortId = _dragFromPort;
    // Prefer pointer-based drop target because drag end callback comes from source port.
    final dropTargetPortId = _findNearestPortId(_dragCurrentOffset) ?? toPortId;

    if (fromPortId != null && dropTargetPortId != null && fromPortId != dropTargetPortId) {
      final from = _parsePortId(fromPortId);
      final to = _parsePortId(dropTargetPortId);
      if (from != null && to != null && from.nodeId != to.nodeId) {
        // Only allow output -> input connections.
        if (from.side == 'output' && to.side == 'input') {
          final alreadyExists = _edges.any(
            (e) => e.fromId == from.nodeId && e.toId == to.nodeId,
          );
          if (!alreadyExists) {
            setState(() {
              _edges.add(WorkflowEdge(
                id: '${from.nodeId}_${to.nodeId}',
                fromId: from.nodeId,
                toId: to.nodeId,
              ));
            });
          }
        }
      }
    }
    setState(() {
      _dragFromPort = null;
      _dragCurrentOffset = Offset.zero;
    });
  }

  _PortRef? _parsePortId(String portId) {
    final sep = portId.lastIndexOf('_');
    if (sep <= 0 || sep >= portId.length - 1) return null;
    final nodeId = portId.substring(0, sep);
    final side = portId.substring(sep + 1);
    if (side != 'input' && side != 'output') return null;
    return _PortRef(nodeId: nodeId, side: side);
  }

  String? _findNearestPortId(Offset localOffset) {
    if (_nodes.isEmpty) return null;
    const maxDistance = 18.0;

    String? nearestPortId;
    var nearestDist = double.infinity;

    for (final node in _nodes) {
      final inputCenter = Offset(
        node.x + _canvasOffset.dx,
        node.y + _canvasOffset.dy + _kNodeH / 2,
      );
      final outputCenter = Offset(
        node.x + _canvasOffset.dx + _kNodeW,
        node.y + _canvasOffset.dy + _kNodeH / 2,
      );

      final inputDist = (localOffset - inputCenter).distance;
      if (inputDist < nearestDist) {
        nearestDist = inputDist;
        nearestPortId = '${node.id}_input';
      }

      final outputDist = (localOffset - outputCenter).distance;
      if (outputDist < nearestDist) {
        nearestDist = outputDist;
        nearestPortId = '${node.id}_output';
      }
    }

    if (nearestDist > maxDistance) return null;
    return nearestPortId;
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
      _dragFromPort = null;
      _dragCurrentOffset = Offset.zero;
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
    showDialog(
      context: context,
      builder: (_) => _RenameNodeDialogWithMentions(
        initialLabel: node.label,
        libraryAgents: _libraryAgents,
        missions: _missions,
        onRename: (newLabel) {
          if (newLabel.trim().isNotEmpty) {
            final idx = _nodes.indexWhere((n) => n.id == node.id);
            if (idx >= 0) {
              setState(() => _nodes[idx] = _nodes[idx].copyWith(label: newLabel.trim()));
            }
          }
        },
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
              onPanUpdate: (d) {
                _onCanvasPan(d);
                if (_dragFromPort != null) _onPortDragUpdate(d.globalPosition);
              },
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
                        dragFromPort: _dragFromPort,
                        dragOffset: _dragCurrentOffset,
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
                          onPortDragStart: _onPortDragStart,
                          onPortDragUpdate: _onPortDragUpdate,
                          onPortDragEnd: _onPortDragEnd,
                        ),
                      ),
                    ),

                  // Empty state hint
                  if (_nodes.isEmpty)
                    const Center(
                      child: _CanvasEmptyHint(),
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
  final bool accent;
  final bool danger;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = danger
        ? AppTheme.error
        : accent
            ? AppTheme.gold
            : AppTheme.textB;
    final Color bg = danger
        ? AppTheme.error.withValues(alpha: 0.12)
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
          border: Border.all(color: fg.withValues(alpha: accent ? 0.5 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500),
            ),
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
  final Function(String)? onPortDragStart;
  final Function(Offset)? onPortDragUpdate;
  final Function(String?)? onPortDragEnd;

  const _NodeCard({
    required this.node,
    required this.isSelected,
    this.onPortDragStart,
    this.onPortDragUpdate,
    this.onPortDragEnd,
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
    final portId = node.id;

    return SizedBox(
      width: _kNodeW,
      height: _kNodeH,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
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
        child: Stack(
          children: [
            // Main content (centered)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Type badge
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
            // Input port (left)
            Positioned(
              left: -5,
              top: _kNodeH / 2 - 5,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onPanStart: (_) => onPortDragStart?.call('${portId}_input'),
                  onPanUpdate: (d) => onPortDragUpdate?.call(d.globalPosition),
                  onPanEnd: (_) => onPortDragEnd?.call('${portId}_input'),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.border2,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Output port (right)
            Positioned(
              right: -5,
              top: _kNodeH / 2 - 5,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onPanStart: (_) => onPortDragStart?.call('${portId}_output'),
                  onPanUpdate: (d) => onPortDragUpdate?.call(d.globalPosition),
                  onPanEnd: (_) => onPortDragEnd?.call('${portId}_output'),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.gold,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.gold.withValues(alpha: 0.6),
                          blurRadius: 6,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortRef {
  final String nodeId;
  final String side;

  const _PortRef({required this.nodeId, required this.side});
}

// ── Edge painter ──────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  final List<WorkflowNode> nodes;
  final List<WorkflowEdge> edges;
  final Offset offset;
  final String? dragFromPort;
  final Offset dragOffset;

  const _EdgePainter({
    required this.nodes,
    required this.edges,
    required this.offset,
    this.dragFromPort,
    this.dragOffset = Offset.zero,
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

    for (final edge in edges) {
      final from = _nodeById(edge.fromId);
      final to = _nodeById(edge.toId);
      if (from == null || to == null) continue;

      final src = _outputPort(from);
      final dst = _inputPort(to);

      _drawBezier(canvas, src, dst, edgePaint);

      // Arrowhead
      _drawArrow(canvas, dst, math.atan2(dst.dy - src.dy, dst.dx - src.dx), edgePaint);
    }

    // Ports are now handled by _NodeCard widgets themselves
    // No need to paint them here
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
      old.edges != edges ||
      old.nodes != nodes ||
      old.offset != offset ||
      old.dragFromPort != dragFromPort ||
      old.dragOffset != dragOffset;
}

// ── Rename Node Dialog with Mentions ──────────────────────────────────────────

class _RenameNodeDialogWithMentions extends StatefulWidget {
  final String initialLabel;
  final List<AgentModel> libraryAgents;
  final List<MissionModel> missions;
  final Function(String) onRename;

  const _RenameNodeDialogWithMentions({
    required this.initialLabel,
    required this.libraryAgents,
    required this.missions,
    required this.onRename,
  });

  @override
  State<_RenameNodeDialogWithMentions> createState() => _RenameNodeDialogWithMentionsState();
}

class _RenameNodeDialogWithMentionsState extends State<_RenameNodeDialogWithMentions> {
  late final TextEditingController _ctrl;
  List<AgentModel> _agentSuggestions = const [];
  List<MissionModel> _missionSuggestions = const [];
  String _activeTrigger = '';
  bool _showMentions = false;
  int _mentionStart = -1;
  int _selectedSuggestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialLabel);
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final selection = _ctrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : _ctrl.text.length;
    final text = _ctrl.text;
    if (cursor > text.length) return;

    final prefix = text.substring(0, cursor);
    final at = prefix.lastIndexOf('@');
    final hash = prefix.lastIndexOf('#');
    final trigger = at > hash ? '@' : '#';
    final triggerIndex = trigger == '@' ? at : hash;
    if (triggerIndex == -1) {
      _hideMentions();
      return;
    }

    if (triggerIndex > 0 && !RegExp(r'\s').hasMatch(prefix[triggerIndex - 1])) {
      _hideMentions();
      return;
    }

    final query = prefix.substring(triggerIndex + 1);
    if (query.contains(RegExp(r'\s'))) {
      _hideMentions();
      return;
    }

    final q = query.toLowerCase();
    if (trigger == '@') {
      final suggestions =
          widget.libraryAgents.where((a) => q.isEmpty || a.title.toLowerCase().contains(q)).take(8).toList();
      setState(() {
        _mentionStart = triggerIndex;
        _activeTrigger = '@';
        _agentSuggestions = suggestions;
        _missionSuggestions = const [];
        _showMentions = true;
        _selectedSuggestionIndex = 0;
      });
      return;
    }

    final missionSuggestions = widget.missions
        .where((m) => q.isEmpty || m.title.toLowerCase().contains(q) || m.slug.toLowerCase().contains(q))
        .take(8)
        .toList();
    setState(() {
      _mentionStart = triggerIndex;
      _activeTrigger = '#';
      _agentSuggestions = const [];
      _missionSuggestions = missionSuggestions;
      _showMentions = true;
      _selectedSuggestionIndex = 0;
    });
  }

  void _hideMentions() {
    if (!_showMentions && _agentSuggestions.isEmpty && _missionSuggestions.isEmpty) return;
    setState(() {
      _showMentions = false;
      _activeTrigger = '';
      _agentSuggestions = const [];
      _missionSuggestions = const [];
      _mentionStart = -1;
      _selectedSuggestionIndex = 0;
    });
  }

  void _insertMention(AgentModel agent) {
    final text = _ctrl.text;
    final selection = _ctrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 || _mentionStart >= cursor || cursor > text.length) return;

    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '@${agent.title}';
    final next = '$before$mention$after';
    _ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _hideMentions();
  }

  void _insertMission(MissionModel mission) {
    final text = _ctrl.text;
    final selection = _ctrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 || _mentionStart >= cursor || cursor > text.length) return;

    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '#${mission.slug}';
    final next = '$before$mention$after';
    _ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _hideMentions();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.card,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Rename Node',
                style: TextStyle(color: AppTheme.textH, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _MentionTextField(
                controller: _ctrl,
                onChanged: _onTextChanged,
              ),
              if (_showMentions) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: _activeTrigger == '@'
                      ? _agentSuggestions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'No agents found',
                                style: TextStyle(color: AppTheme.textM, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _agentSuggestions.length,
                              itemBuilder: (_, i) {
                                final agent = _agentSuggestions[i];
                                final isSelected = i == _selectedSuggestionIndex;
                                return Container(
                                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      hoverColor: AppTheme.primary.withValues(alpha: 0.12),
                                      title: Text(
                                        agent.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.textH,
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        agent.characterType.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppTheme.textM, fontSize: 10),
                                      ),
                                      trailing: isSelected
                                          ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 18)
                                          : null,
                                      onTap: () => _insertMention(agent),
                                    ),
                                  ),
                                );
                              },
                            )
                      : _missionSuggestions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'No missions found',
                                style: TextStyle(color: AppTheme.textM, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _missionSuggestions.length,
                              itemBuilder: (_, i) {
                                final mission = _missionSuggestions[i];
                                final isSelected = i == _selectedSuggestionIndex;
                                return Container(
                                  color: isSelected ? AppTheme.gold.withValues(alpha: 0.15) : Colors.transparent,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      hoverColor: AppTheme.gold.withValues(alpha: 0.1),
                                      title: Text(
                                        '#${mission.slug}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.gold,
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        mission.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppTheme.textM, fontSize: 10),
                                      ),
                                      trailing: isSelected
                                          ? const Icon(Icons.check_circle, color: AppTheme.gold, size: 18)
                                          : null,
                                      onTap: () => _insertMission(mission),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    onPressed: () {
                      final v = _ctrl.text.trim();
                      if (v.isNotEmpty) {
                        widget.onRename(v);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Rename'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mention-aware text field ──────────────────────────────────────────────

class _MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _MentionTextField({
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<_MentionTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(widget.onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(widget.onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: true,
      style: const TextStyle(color: AppTheme.textH),
      decoration: InputDecoration(
        hintText: 'Node label (type @ for agents, # for missions)',
        hintStyle: TextStyle(color: AppTheme.textM.withValues(alpha: 0.6)),
        filled: true,
        fillColor: AppTheme.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }
}
