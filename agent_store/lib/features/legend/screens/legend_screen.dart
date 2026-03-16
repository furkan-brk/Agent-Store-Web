// lib/features/legend/screens/legend_screen.dart

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/models/mission_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/mission_service.dart';
import '../models/workflow_models.dart';
import '../services/legend_service.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const double _kNodeW = 180.0;
const double _kNodeH = 80.0;

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

class _LegendScreenState extends State<LegendScreen>
    with TickerProviderStateMixin {
  // ── Canvas state ───────────────────────────────────────────────────────────
  List<WorkflowNode> _nodes = [];
  List<WorkflowEdge> _edges = [];
  Offset _canvasOffset = Offset.zero;
  double _zoom = 1.0;
  String? _selectedNodeId;
  String? _selectedEdgeId;

  // Port dragging
  String? _dragFromPort;
  Offset _dragCurrentOffset = Offset.zero;

  final GlobalKey _canvasKey = GlobalKey();

  // ── Palette data ───────────────────────────────────────────────────────────
  List<AgentModel> _libraryAgents = [];
  List<MissionModel> _missions = [];
  bool _loadingAgents = false;

  // ── Workflow persistence ───────────────────────────────────────────────────
  String _workflowName = 'My Workflow';
  String? _currentWorkflowId;
  List<LegendWorkflow> _savedWorkflows = [];

  // ── Execution state ────────────────────────────────────────────────────────
  bool _executing = false;
  WorkflowExecution? _lastExecution;
  bool _showResultsPanel = false;

  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingAgents = true);
    try {
      await MissionService.instance.refresh();
      await LegendService.instance.refresh();
      final agents = ApiService.instance.isAuthenticated
          ? await ApiService.instance.getLibrary()
          : <AgentModel>[];
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
        title: const Text('Replace current workflow?',
            style: TextStyle(color: AppTheme.textH)),
        content: const Text(
            'Your current canvas will be cleared before creating a new workflow.',
            style: TextStyle(color: AppTheme.textM)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
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
    final workflowName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : 'Workflow ${_workflowCount + 1}';
    final workflow = LegendService.instance.newWorkflow(workflowName);
    setState(() {
      _workflowName = workflow.name;
      _currentWorkflowId = workflow.id;
      _nodes = [];
      _edges = [];
      _selectedNodeId = null;
      _selectedEdgeId = null;
      _dragFromPort = null;
      _dragCurrentOffset = Offset.zero;
      _canvasOffset = Offset.zero;
      _zoom = 1.0;
      _lastExecution = null;
      _showResultsPanel = false;
    });
  }

  void _showNewWorkflowDialog() {
    final ctrl = TextEditingController(text: 'Workflow ${_workflowCount + 1}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('New Workflow',
            style: TextStyle(color: AppTheme.textH)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textH),
          decoration: const InputDecoration(hintText: 'Workflow name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              Navigator.pop(context);
              await _confirmReplaceCanvas(
                  () => _startWorkflow(name: ctrl.text));
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
      final workflow = LegendService.instance
          .newWorkflow('Starter Workflow ${_workflowCount + 1}');
      final nodes = <WorkflowNode>[];
      final edges = <WorkflowEdge>[];
      var nextX = 100.0;
      const rowY = 160.0;

      void addNode(WorkflowNode node) {
        if (nodes.isNotEmpty) {
          final previous = nodes.last;
          edges.add(WorkflowEdge(
            id: '${previous.id}_${node.id}',
            fromId: previous.id,
            toId: node.id,
          ));
        }
        nodes.add(node);
        nextX += 260;
      }

      addNode(WorkflowNode(
        id: '${workflow.id}_start',
        type: WorkflowNodeType.start,
        label: 'START',
        x: nextX,
        y: rowY,
      ));

      for (final mission in sourceMissions) {
        addNode(WorkflowNode(
          id: '${workflow.id}_mission_${mission.slug}',
          type: WorkflowNodeType.mission,
          label: mission.title,
          x: nextX,
          y: rowY,
          refId: mission.slug,
        ));
      }

      for (final agent in sourceAgents) {
        addNode(WorkflowNode(
          id: '${workflow.id}_agent_${agent.id}',
          type: WorkflowNodeType.agent,
          label: agent.title,
          x: nextX,
          y: rowY,
          refId: agent.id.toString(),
        ));
      }

      addNode(WorkflowNode(
        id: '${workflow.id}_end',
        type: WorkflowNodeType.end,
        label: 'END',
        x: nextX,
        y: rowY,
      ));

      setState(() {
        _workflowName = workflow.name;
        _currentWorkflowId = workflow.id;
        _nodes = nodes;
        _edges = edges;
        _selectedNodeId = null;
        _selectedEdgeId = null;
        _dragFromPort = null;
        _dragCurrentOffset = Offset.zero;
        _canvasOffset = Offset.zero;
        _zoom = 1.0;
      });
      _showNotice('Starter workflow created', background: AppTheme.success);
    });
  }

  String? _validateWorkflow() {
    if (_workflowName.trim().isEmpty) return 'Workflow name cannot be empty.';
    if (_nodes.length < 2) return 'Add at least two nodes before saving.';
    final startCount =
        _nodes.where((n) => n.type == WorkflowNodeType.start).length;
    final endCount =
        _nodes.where((n) => n.type == WorkflowNodeType.end).length;
    if (startCount != 1 || endCount != 1) {
      return 'Each workflow needs exactly one Start and one End node.';
    }
    if (_edges.isEmpty) return 'Create at least one connection before saving.';
    final nodeIds = _nodes.map((n) => n.id).toSet();
    final hasBrokenEdge = _edges
        .any((e) => !nodeIds.contains(e.fromId) || !nodeIds.contains(e.toId));
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
    final cx = (local.dx - _canvasOffset.dx) / _zoom - _kNodeW / 2;
    final cy = (local.dy - _canvasOffset.dy) / _zoom - _kNodeH / 2;

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
    if (_selectedEdgeId != null) {
      setState(() {
        _edges.removeWhere((e) => e.id == _selectedEdgeId);
        _selectedEdgeId = null;
      });
      return;
    }
    if (_selectedNodeId == null) return;
    setState(() {
      _edges.removeWhere(
          (e) => e.fromId == _selectedNodeId || e.toId == _selectedNodeId);
      _nodes.removeWhere((n) => n.id == _selectedNodeId);
      _selectedNodeId = null;
    });
  }

  void _clearCanvas() {
    setState(() {
      _nodes.clear();
      _edges.clear();
      _selectedNodeId = null;
      _selectedEdgeId = null;
      _dragFromPort = null;
      _dragCurrentOffset = Offset.zero;
      _lastExecution = null;
      _showResultsPanel = false;
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
        x: (n.x + delta.dx / _zoom).clamp(0.0, 4000.0),
        y: (n.y + delta.dy / _zoom).clamp(0.0, 3000.0),
        refId: n.refId,
      );
    });
  }

  // ── Connect mode ───────────────────────────────────────────────────────────

  void _onNodeTap(WorkflowNode node) {
    setState(() {
      _selectedNodeId = node.id;
      _selectedEdgeId = null;
    });
  }

  void _onEdgeTap(String edgeId) {
    setState(() {
      _selectedEdgeId = edgeId;
      _selectedNodeId = null;
    });
  }

  void _onCanvasTap() {
    setState(() {
      _selectedNodeId = null;
      _selectedEdgeId = null;
    });
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
    final dropTargetPortId =
        _findNearestPortId(_dragCurrentOffset) ?? toPortId;

    if (fromPortId != null &&
        dropTargetPortId != null &&
        fromPortId != dropTargetPortId) {
      final from = _parsePortId(fromPortId);
      final to = _parsePortId(dropTargetPortId);
      if (from != null && to != null && from.nodeId != to.nodeId) {
        if (from.side == 'output' && to.side == 'input') {
          final alreadyExists = _edges
              .any((e) => e.fromId == from.nodeId && e.toId == to.nodeId);
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
    const maxDistance = 28.0;
    String? nearestPortId;
    var nearestDist = double.infinity;

    for (final node in _nodes) {
      final inputCenter = Offset(
        node.x * _zoom + _canvasOffset.dx,
        node.y * _zoom + _canvasOffset.dy + _kNodeH * _zoom / 2,
      );
      final outputCenter = Offset(
        node.x * _zoom + _canvasOffset.dx + _kNodeW * _zoom,
        node.y * _zoom + _canvasOffset.dy + _kNodeH * _zoom / 2,
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

  /// Returns the canvas-local position of the nearest valid drop port
  /// (used to draw a highlight ring in the edge painter).
  Offset? _findNearestDropPortOffset() {
    if (_dragFromPort == null || _dragCurrentOffset == Offset.zero) {
      return null;
    }
    final nearestId = _findNearestPortId(_dragCurrentOffset);
    if (nearestId == null) return null;

    // Don't highlight the source port itself
    if (nearestId == _dragFromPort) return null;

    final parsed = _parsePortId(nearestId);
    if (parsed == null) return null;

    // Find the node
    final node = _nodes.cast<WorkflowNode?>().firstWhere(
        (n) => n?.id == parsed.nodeId,
        orElse: () => null);
    if (node == null) return null;

    if (parsed.side == 'input') {
      return Offset(
        node.x * _zoom + _canvasOffset.dx,
        node.y * _zoom + _canvasOffset.dy + _kNodeH * _zoom / 2,
      );
    } else {
      return Offset(
        node.x * _zoom + _canvasOffset.dx + _kNodeW * _zoom,
        node.y * _zoom + _canvasOffset.dy + _kNodeH * _zoom / 2,
      );
    }
  }

  // ── Canvas pan & zoom ─────────────────────────────────────────────────────

  void _onCanvasPan(DragUpdateDetails d) {
    setState(() => _canvasOffset += d.delta);
  }

  void _onCanvasZoom(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        final delta = event.scrollDelta.dy > 0 ? -0.05 : 0.05;
        _zoom = (_zoom + delta).clamp(0.3, 2.0);
      });
    }
  }

  // ── Save / load ────────────────────────────────────────────────────────────

  Future<void> _saveWorkflow() async {
    final validationError = _validateWorkflow();
    if (validationError != null) {
      _showNotice(validationError, background: AppTheme.error);
      return;
    }

    final id = _currentWorkflowId ??
        DateTime.now().millisecondsSinceEpoch.toString();
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
    _showNotice('Workflow "$_workflowName" saved',
        background: AppTheme.success);
  }

  void _loadWorkflow(LegendWorkflow wf) {
    setState(() {
      _nodes = List.of(wf.nodes);
      _edges = List.of(wf.edges);
      _workflowName = wf.name;
      _currentWorkflowId = wf.id;
      _selectedNodeId = null;
      _selectedEdgeId = null;
      _dragFromPort = null;
      _dragCurrentOffset = Offset.zero;
      _canvasOffset = Offset.zero;
      _zoom = 1.0;
      _lastExecution = null;
      _showResultsPanel = false;
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
        title: const Text('Rename Workflow',
            style: TextStyle(color: AppTheme.textH)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textH),
          decoration: const InputDecoration(hintText: 'Workflow name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
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
          title: const Text('Load Workflow',
              style: TextStyle(color: AppTheme.textH)),
          content: SizedBox(
            width: 420,
            child: _savedWorkflows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No saved workflows.',
                        style: TextStyle(color: AppTheme.textM)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _savedWorkflows.length,
                    itemBuilder: (_, i) {
                      final wf = _savedWorkflows[i];
                      return ListTile(
                        leading: const Icon(Icons.account_tree_outlined,
                            color: AppTheme.gold),
                        title: Text(wf.name,
                            style: const TextStyle(color: AppTheme.textH)),
                        subtitle: Text(
                          '${wf.nodes.length} nodes · ${wf.edges.length} edges',
                          style: const TextStyle(
                              color: AppTheme.textM, fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.textM),
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
              child:
                  const Text('Close', style: TextStyle(color: AppTheme.textM)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Execute workflow ──────────────────────────────────────────────────────

  void _showExecuteDialog() {
    final validationError = _validateWorkflow();
    if (validationError != null) {
      _showNotice(validationError, background: AppTheme.error);
      return;
    }
    if (_currentWorkflowId == null) {
      _showNotice('Save the workflow before executing.',
          background: AppTheme.error);
      return;
    }
    if (!ApiService.instance.isAuthenticated) {
      _showNotice('Connect your wallet to execute workflows.',
          background: AppTheme.error);
      return;
    }

    final agentCount =
        _nodes.where((n) => n.type == WorkflowNodeType.agent).length;
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Row(
          children: [
            const Icon(Icons.rocket_launch_outlined,
                color: AppTheme.gold, size: 20),
            const SizedBox(width: 8),
            const Text('Execute Workflow',
                style: TextStyle(color: AppTheme.textH, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: AppTheme.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This workflow has $agentCount agent node${agentCount != 1 ? 's' : ''} and will cost $agentCount credit${agentCount != 1 ? 's' : ''}.',
                        style: const TextStyle(
                            color: AppTheme.textM, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Input Message',
                  style: TextStyle(
                      color: AppTheme.textH,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.textH, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Enter the input message for your workflow...',
                  hintStyle: TextStyle(
                      color: AppTheme.textM.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: AppTheme.bg,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppTheme.gold, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.bg,
            ),
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: const Text('Execute'),
            onPressed: () {
              final msg = ctrl.text.trim();
              if (msg.isEmpty) return;
              Navigator.pop(context);
              _executeWorkflow(msg);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executeWorkflow(String inputMessage) async {
    if (_currentWorkflowId == null || _executing) return;

    // Auto-save before execution
    await _saveWorkflow();

    setState(() {
      _executing = true;
      _lastExecution = null;
      _showResultsPanel = true;
    });

    try {
      final result = await ApiService.instance
          .executeWorkflow(_currentWorkflowId!, inputMessage);
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _lastExecution = result;
          _executing = false;
        });
        if (result.isCompleted) {
          _showNotice('Workflow completed successfully!',
              background: AppTheme.success);
        } else if (result.isFailed) {
          _showNotice(
              'Workflow failed: ${result.errorMessage ?? "Unknown error"}',
              background: AppTheme.error);
        }
      } else {
        setState(() => _executing = false);
        _showNotice('Execution failed. Check your credits and try again.',
            background: AppTheme.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _executing = false);
      _showNotice('Execution error: $e', background: AppTheme.error);
    }
  }

  // ── Execution history ─────────────────────────────────────────────────────

  void _showHistoryDialog() {
    if (!ApiService.instance.isAuthenticated) {
      _showNotice('Connect wallet to view execution history.',
          background: AppTheme.error);
      return;
    }

    showDialog(
      context: context,
      builder: (_) => _ExecutionHistoryDialog(
        workflowId: _currentWorkflowId,
        onViewExecution: (exec) {
          Navigator.pop(context);
          setState(() {
            _lastExecution = exec;
            _showResultsPanel = true;
          });
        },
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
              setState(
                  () => _nodes[idx] = _nodes[idx].copyWith(label: newLabel.trim()));
            }
          }
        },
      ),
    );
  }

  // ── Get execution status for a node ───────────────────────────────────────

  NodeExecutionResult? _getNodeResult(String nodeId) {
    if (_lastExecution == null) return null;
    for (final r in _lastExecution!.nodeResults) {
      if (r.nodeId == nodeId) return r;
    }
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.delete) {
            _deleteSelected();
          }
        },
        child: Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLeftPanel(),
                  const VerticalDivider(width: 1, color: AppTheme.border),
                  Expanded(child: _buildCanvas()),
                  if (_showResultsPanel) ...[
                    const VerticalDivider(width: 1, color: AppTheme.border),
                    _buildResultsPanel(),
                  ],
                ],
              ),
            ),
          ],
        ),
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
          const SizedBox(width: 12),
          // Zoom indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              '${(_zoom * 100).round()}%',
              style: const TextStyle(
                  color: AppTheme.textM,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          _ToolbarButton(
            icon: Icons.add_box_outlined,
            label: 'New',
            onTap: _showNewWorkflowDialog,
          ),
          const SizedBox(width: 6),
          _ToolbarButton(
            icon: Icons.auto_fix_high_outlined,
            label: 'Starter',
            onTap: _buildStarterWorkflow,
          ),
          const SizedBox(width: 6),
          if (_selectedNodeId != null || _selectedEdgeId != null) ...[
            _ToolbarButton(
              icon: Icons.delete_outline,
              label: _selectedEdgeId != null ? 'Del Edge' : 'Delete',
              danger: true,
              onTap: _deleteSelected,
            ),
            const SizedBox(width: 6),
          ],
          _ToolbarButton(
            icon: Icons.folder_open_outlined,
            label: 'Load',
            onTap: _showLoadDialog,
          ),
          const SizedBox(width: 6),
          _ToolbarButton(
            icon: Icons.save_outlined,
            label: 'Save',
            accent: true,
            onTap: _saveWorkflow,
          ),
          const SizedBox(width: 6),
          _ToolbarButton(
            icon: Icons.history,
            label: 'History',
            onTap: _showHistoryDialog,
          ),
          const SizedBox(width: 6),
          _ExecuteButton(
            executing: _executing,
            onTap: _executing ? null : _showExecuteDialog,
            pulseAnimation: _pulseAnim,
          ),
          const SizedBox(width: 6),
          _ToolbarButton(
            icon: Icons.clear_all,
            label: 'Clear',
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.card,
                  title: const Text('Clear canvas?',
                      style: TextStyle(color: AppTheme.textH)),
                  content: const Text(
                    'All nodes and edges will be removed.',
                    style: TextStyle(color: AppTheme.textM),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppTheme.textM)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary),
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
      width: 230,
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
                  style:
                      const TextStyle(color: AppTheme.textM, fontSize: 11),
                ),
                if (_lastExecution != null) ...[
                  const SizedBox(height: 6),
                  _ExecutionStatusBadge(execution: _lastExecution!),
                ],
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
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
                            style: TextStyle(
                                color: AppTheme.textM, fontSize: 11),
                          ),
                        )
                      ]
                    : _libraryAgents
                        .map(
                          (a) => _DraggablePaletteItem(
                            data: _NodeDragData(WorkflowNodeType.agent,
                                a.title, a.id.toString()),
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
                        style: TextStyle(
                            color: AppTheme.textM, fontSize: 11),
                      ),
                    )
                  ]
                : _missions
                    .map(
                      (m) => _DraggablePaletteItem(
                        data: _NodeDragData(
                            WorkflowNodeType.mission, m.title, m.slug),
                        color: AppTheme.gold,
                        icon: Icons.flag_outlined,
                        label: m.title,
                        subtitle: '#${m.slug}',
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SHORTCUTS',
                  style: TextStyle(
                      color: AppTheme.textM,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                _shortcutRow('Scroll', 'Zoom in/out'),
                _shortcutRow('Drag canvas', 'Pan'),
                _shortcutRow('Click edge', 'Select'),
                _shortcutRow('Delete key', 'Remove selected'),
                _shortcutRow('Double-tap', 'Rename node'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shortcutRow(String key, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(key,
                style: const TextStyle(
                    color: AppTheme.textM,
                    fontSize: 9,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Text(desc,
              style: const TextStyle(
                  color: AppTheme.textM, fontSize: 9)),
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
        return Listener(
          onPointerSignal: _onCanvasZoom,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bg,
              border: highlight
                  ? Border.all(color: AppTheme.primary, width: 2)
                  : null,
            ),
            child: ClipRect(
              child: GestureDetector(
                onPanUpdate: (d) {
                  _onCanvasPan(d);
                  if (_dragFromPort != null) {
                    _onPortDragUpdate(d.globalPosition);
                  }
                },
                onTap: _onCanvasTap,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  key: _canvasKey,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    const Positioned.fill(child: _CanvasGrid()),

                    // Edge layer (with click detection)
                    Positioned.fill(
                      child: GestureDetector(
                        onTapDown: (details) {
                          _handleEdgeTap(details.localPosition);
                        },
                        behavior: HitTestBehavior.translucent,
                        child: CustomPaint(
                          painter: _EdgePainter(
                            nodes: _nodes,
                            edges: _edges,
                            offset: _canvasOffset,
                            zoom: _zoom,
                            dragFromPort: _dragFromPort,
                            dragOffset: _dragCurrentOffset,
                            selectedEdgeId: _selectedEdgeId,
                            executionResults:
                                _lastExecution?.nodeResults ?? [],
                            nearestDropPort: _findNearestDropPortOffset(),
                          ),
                        ),
                      ),
                    ),

                    // Nodes
                    for (final node in _nodes)
                      Positioned(
                        left:
                            node.x * _zoom + _canvasOffset.dx,
                        top:
                            node.y * _zoom + _canvasOffset.dy,
                        child: Transform.scale(
                          scale: _zoom,
                          alignment: Alignment.topLeft,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onNodeTap(node),
                            onDoubleTap: () =>
                                _showRenameNodeDialog(node),
                            onPanUpdate: (d) =>
                                _moveNode(node.id, d.delta),
                            child: _NodeCard(
                              node: node,
                              isSelected:
                                  _selectedNodeId == node.id,
                              onPortDragStart: _onPortDragStart,
                              onPortDragUpdate: _onPortDragUpdate,
                              onPortDragEnd: _onPortDragEnd,
                              executionResult:
                                  _getNodeResult(node.id),
                              isExecuting: _executing,
                            ),
                          ),
                        ),
                      ),

                    // Execution overlay
                    if (_executing)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Container(
                            color: AppTheme.gold.withValues(
                                alpha: _pulseAnim.value * 0.04),
                          ),
                        ),
                      ),

                    if (_nodes.isEmpty)
                      const Center(child: _CanvasEmptyHint()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleEdgeTap(Offset localPosition) {
    const hitThreshold = 8.0;
    String? tappedEdgeId;

    for (final edge in _edges) {
      final fromNode = _nodes.cast<WorkflowNode?>().firstWhere(
          (n) => n?.id == edge.fromId,
          orElse: () => null);
      final toNode = _nodes.cast<WorkflowNode?>().firstWhere(
          (n) => n?.id == edge.toId,
          orElse: () => null);
      if (fromNode == null || toNode == null) continue;

      final src = Offset(
        fromNode.x * _zoom + _canvasOffset.dx + _kNodeW * _zoom,
        fromNode.y * _zoom + _canvasOffset.dy + _kNodeH * _zoom / 2,
      );
      final dst = Offset(
        toNode.x * _zoom + _canvasOffset.dx,
        toNode.y * _zoom + _canvasOffset.dy + _kNodeH * _zoom / 2,
      );

      if (_isPointNearBezier(localPosition, src, dst, hitThreshold)) {
        tappedEdgeId = edge.id;
        break;
      }
    }

    if (tappedEdgeId != null) {
      _onEdgeTap(tappedEdgeId);
    }
  }

  bool _isPointNearBezier(
      Offset point, Offset src, Offset dst, double threshold) {
    const steps = 20;
    final dx = (dst.dx - src.dx).abs().clamp(60.0, 200.0);
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final t2 = t * t;
      final t3 = t2 * t;
      final mt = 1 - t;
      final mt2 = mt * mt;
      final mt3 = mt2 * mt;

      final cp1 = Offset(src.dx + dx * 0.5, src.dy);
      final cp2 = Offset(dst.dx - dx * 0.5, dst.dy);

      final px =
          mt3 * src.dx + 3 * mt2 * t * cp1.dx + 3 * mt * t2 * cp2.dx + t3 * dst.dx;
      final py =
          mt3 * src.dy + 3 * mt2 * t * cp1.dy + 3 * mt * t2 * cp2.dy + t3 * dst.dy;

      if ((Offset(px, py) - point).distance < threshold) return true;
    }
    return false;
  }

  // ── Results Panel ──────────────────────────────────────────────────────────

  Widget _buildResultsPanel() {
    return Container(
      width: 340,
      color: AppTheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Icon(
                  _executing
                      ? Icons.sync
                      : _lastExecution?.isCompleted == true
                          ? Icons.check_circle
                          : Icons.error_outline,
                  size: 16,
                  color: _executing
                      ? AppTheme.gold
                      : _lastExecution?.isCompleted == true
                          ? AppTheme.success
                          : AppTheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  _executing
                      ? 'EXECUTING...'
                      : _lastExecution?.isCompleted == true
                          ? 'COMPLETED'
                          : 'FAILED',
                  style: TextStyle(
                    color: _executing
                        ? AppTheme.gold
                        : _lastExecution?.isCompleted == true
                            ? AppTheme.success
                            : AppTheme.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (_lastExecution != null) ...[
                  Text(
                    '${_lastExecution!.creditsUsed} credits',
                    style: const TextStyle(
                        color: AppTheme.gold, fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AppTheme.textM,
                  onPressed: () =>
                      setState(() => _showResultsPanel = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _executing
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppTheme.gold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Running workflow...',
                          style: TextStyle(
                              color: AppTheme.textM, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Agent nodes are being processed',
                          style: TextStyle(
                              color: AppTheme.textM, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : _lastExecution == null
                    ? const Center(
                        child: Text('No execution results.',
                            style: TextStyle(
                                color: AppTheme.textM, fontSize: 12)),
                      )
                    : _buildExecutionResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionResults() {
    final exec = _lastExecution!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exec.workflowName,
                  style: const TextStyle(
                      color: AppTheme.textH,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '${exec.completedNodes}/${exec.totalNodes} nodes · ${exec.duration?.inSeconds ?? '?'}s',
                style: const TextStyle(
                    color: AppTheme.textM, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Input
        _ResultSection(
          title: 'INPUT',
          icon: Icons.input,
          color: AppTheme.info,
          content: exec.inputMessage,
        ),
        const SizedBox(height: 8),

        // Node results
        for (int i = 0; i < exec.nodeResults.length; i++) ...[
          _NodeResultCard(result: exec.nodeResults[i], index: i),
          const SizedBox(height: 6),
        ],

        // Final output
        if (exec.finalOutput.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ResultSection(
            title: 'FINAL OUTPUT',
            icon: Icons.output,
            color: AppTheme.success,
            content: exec.finalOutput,
            expanded: true,
          ),
        ],

        // Error
        if (exec.errorMessage != null &&
            exec.errorMessage!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ResultSection(
            title: 'ERROR',
            icon: Icons.error_outline,
            color: AppTheme.error,
            content: exec.errorMessage!,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ExecuteButton extends StatelessWidget {
  final bool executing;
  final VoidCallback? onTap;
  final Animation<double> pulseAnimation;

  const _ExecuteButton({
    required this.executing,
    required this.onTap,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    if (executing) {
      return AnimatedBuilder(
        animation: pulseAnimation,
        builder: (_, __) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: pulseAnimation.value * 0.3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: AppTheme.gold.withValues(alpha: pulseAnimation.value)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.gold),
              ),
              SizedBox(width: 6),
              Text('Running...',
                  style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4A843), Color(0xFFE8C060)],
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch, size: 14, color: Color(0xFF1E1A14)),
            SizedBox(width: 5),
            Text(
              'Execute',
              style: TextStyle(
                color: Color(0xFF1E1A14),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutionStatusBadge extends StatelessWidget {
  final WorkflowExecution execution;
  const _ExecutionStatusBadge({required this.execution});

  @override
  Widget build(BuildContext context) {
    final color = execution.isCompleted
        ? AppTheme.success
        : execution.isFailed
            ? AppTheme.error
            : AppTheme.gold;
    final label = execution.isCompleted
        ? 'Last run: OK'
        : execution.isFailed
            ? 'Last run: Failed'
            : 'Running...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            execution.isCompleted
                ? Icons.check_circle
                : execution.isFailed
                    ? Icons.error
                    : Icons.sync,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

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
          border:
              Border.all(color: fg.withValues(alpha: accent ? 0.5 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
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
        border: Border.all(
            color: dragging ? color : color.withValues(alpha: 0.4)),
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
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textH, fontSize: 12)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 10)),
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
          child: SizedBox(width: _kNodeW, child: _chip(dragging: true)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: _chip()),
      child: _chip(),
    );
  }
}

// ── Result widgets ────────────────────────────────────────────────────────────

class _ResultSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String content;
  final bool expanded;

  const _ResultSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
    this.expanded = false,
  });

  @override
  State<_ResultSection> createState() => _ResultSectionState();
}

class _ResultSectionState extends State<_ResultSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(widget.icon, size: 12, color: widget.color),
                  const SizedBox(width: 6),
                  Text(widget.title,
                      style: TextStyle(
                          color: widget.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 14,
                    color: AppTheme.textM,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                widget.content.length > 2000
                    ? '${widget.content.substring(0, 2000)}...'
                    : widget.content,
                style: const TextStyle(
                    color: AppTheme.textB,
                    fontSize: 11,
                    height: 1.5,
                    fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NodeResultCard extends StatefulWidget {
  final NodeExecutionResult result;
  final int index;
  const _NodeResultCard({required this.result, required this.index});

  @override
  State<_NodeResultCard> createState() => _NodeResultCardState();
}

class _NodeResultCardState extends State<_NodeResultCard> {
  bool _expanded = false;

  Color get _color {
    if (widget.result.hasError) return AppTheme.error;
    switch (widget.result.nodeType) {
      case 'start':
        return AppTheme.success;
      case 'end':
        return AppTheme.primary;
      case 'agent':
        return AppTheme.info;
      case 'mission':
        return AppTheme.gold;
      default:
        return AppTheme.textM;
    }
  }

  IconData get _icon {
    switch (widget.result.nodeType) {
      case 'start':
        return Icons.play_arrow_rounded;
      case 'end':
        return Icons.stop_rounded;
      case 'agent':
        return Icons.smart_toy_outlined;
      case 'mission':
        return Icons.flag_outlined;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: r.hasError
              ? AppTheme.error.withValues(alpha: 0.5)
              : _color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Center(child: Icon(_icon, size: 11, color: _color)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.nodeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textH,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        Text(
                          '${r.nodeType.toUpperCase()} · ${r.durationMs}ms',
                          style: const TextStyle(
                              color: AppTheme.textM, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  if (r.hasError)
                    const Icon(Icons.error, size: 14, color: AppTheme.error)
                  else
                    const Icon(Icons.check_circle,
                        size: 14, color: AppTheme.success),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: AppTheme.textM,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.output.isNotEmpty) ...[
                    const Text('Output:',
                        style: TextStyle(
                            color: AppTheme.textM,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        r.output.length > 1000
                            ? '${r.output.substring(0, 1000)}...'
                            : r.output,
                        style: const TextStyle(
                            color: AppTheme.textB,
                            fontSize: 10,
                            height: 1.5,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                  if (r.hasError) ...[
                    const SizedBox(height: 8),
                    Text('Error: ${r.error}',
                        style: const TextStyle(
                            color: AppTheme.error, fontSize: 10)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Execution History Dialog ──────────────────────────────────────────────────

class _ExecutionHistoryDialog extends StatefulWidget {
  final String? workflowId;
  final Function(WorkflowExecution) onViewExecution;

  const _ExecutionHistoryDialog({
    this.workflowId,
    required this.onViewExecution,
  });

  @override
  State<_ExecutionHistoryDialog> createState() =>
      _ExecutionHistoryDialogState();
}

class _ExecutionHistoryDialogState extends State<_ExecutionHistoryDialog> {
  List<WorkflowExecution> _executions = [];
  bool _loading = true;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.instance.listExecutions(
      workflowId: widget.workflowId,
      limit: 30,
    );
    if (!mounted) return;
    setState(() {
      _executions = result.executions;
      _total = result.total;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Row(
        children: [
          const Icon(Icons.history, color: AppTheme.gold, size: 20),
          const SizedBox(width: 8),
          const Text('Execution History',
              style: TextStyle(color: AppTheme.textH, fontSize: 16)),
          const Spacer(),
          Text('$_total total',
              style: const TextStyle(
                  color: AppTheme.textM, fontSize: 11)),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 400,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.gold))
            : _executions.isEmpty
                ? const Center(
                    child: Text('No executions yet.',
                        style: TextStyle(color: AppTheme.textM)))
                : ListView.builder(
                    itemCount: _executions.length,
                    itemBuilder: (_, i) {
                      final exec = _executions[i];
                      final statusColor = exec.isCompleted
                          ? AppTheme.success
                          : exec.isFailed
                              ? AppTheme.error
                              : AppTheme.gold;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: Icon(
                            exec.isCompleted
                                ? Icons.check_circle
                                : exec.isFailed
                                    ? Icons.error
                                    : Icons.sync,
                            color: statusColor,
                            size: 20,
                          ),
                          title: Text(
                            exec.workflowName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textH,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${exec.completedNodes}/${exec.totalNodes} nodes · ${exec.creditsUsed} credits · ${_formatTime(exec.startedAt)}',
                            style: const TextStyle(
                                color: AppTheme.textM, fontSize: 10),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.visibility_outlined,
                                size: 18, color: AppTheme.gold),
                            onPressed: () =>
                                widget.onViewExecution(exec),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Close', style: TextStyle(color: AppTheme.textM)),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
        Icon(Icons.account_tree_outlined,
            size: 56, color: AppTheme.textM.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text(
          'Drag agents and missions here',
          style: TextStyle(
              color: AppTheme.textM.withValues(alpha: 0.5), fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'from the left panel to build your workflow',
          style: TextStyle(
              color: AppTheme.textM.withValues(alpha: 0.35), fontSize: 12),
        ),
        const SizedBox(height: 16),
        Text(
          'Then hit Execute to run the entire chain',
          style: TextStyle(
              color: AppTheme.gold.withValues(alpha: 0.4), fontSize: 11),
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
  final NodeExecutionResult? executionResult;
  final bool isExecuting;

  const _NodeCard({
    required this.node,
    required this.isSelected,
    this.onPortDragStart,
    this.onPortDragUpdate,
    this.onPortDragEnd,
    this.executionResult,
    this.isExecuting = false,
  });

  Color get _accentColor {
    if (executionResult != null && executionResult!.hasError) {
      return AppTheme.error;
    }
    if (executionResult != null && !executionResult!.hasError) {
      return AppTheme.success;
    }
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
    final hasResult = executionResult != null;

    return SizedBox(
      width: _kNodeW,
      height: _kNodeH,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accent
                : hasResult
                    ? accent.withValues(alpha: 0.6)
                    : AppTheme.border,
            width: isSelected ? 2 : hasResult ? 1.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: 2,
              )
            else if (hasResult)
              BoxShadow(
                color: accent.withValues(alpha: 0.2),
                blurRadius: 8,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Type badge + execution status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
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
                              style: TextStyle(
                                color: accent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (executionResult != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '${executionResult!.durationMs}ms',
                            style: TextStyle(
                                color: accent,
                                fontSize: 8,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
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
            // Execution result indicator
            if (hasResult)
              Positioned(
                right: 6,
                top: 6,
                child: Icon(
                  executionResult!.hasError
                      ? Icons.error
                      : Icons.check_circle,
                  size: 12,
                  color: accent,
                ),
              ),
            // Input port (left) — large hit area, small visual dot
            Positioned(
              left: -14,
              top: _kNodeH / 2 - 14,
              child: _PortHandle(
                portId: '${portId}_input',
                dotColor: AppTheme.border2,
                glowColor: AppTheme.info,
                onPortDragStart: onPortDragStart,
                onPortDragUpdate: onPortDragUpdate,
                onPortDragEnd: onPortDragEnd,
              ),
            ),
            // Output port (right) — large hit area, small visual dot
            Positioned(
              right: -14,
              top: _kNodeH / 2 - 14,
              child: _PortHandle(
                portId: '${portId}_output',
                dotColor: AppTheme.gold,
                glowColor: AppTheme.gold,
                onPortDragStart: onPortDragStart,
                onPortDragUpdate: onPortDragUpdate,
                onPortDragEnd: onPortDragEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A port handle with a large invisible hit area (28x28) and a small visible
/// dot (12x12) in the centre. Shows a glow ring on hover so the user knows
/// they can start dragging.
class _PortHandle extends StatefulWidget {
  final String portId;
  final Color dotColor;
  final Color glowColor;
  final Function(String)? onPortDragStart;
  final Function(Offset)? onPortDragUpdate;
  final Function(String?)? onPortDragEnd;

  const _PortHandle({
    required this.portId,
    required this.dotColor,
    required this.glowColor,
    this.onPortDragStart,
    this.onPortDragUpdate,
    this.onPortDragEnd,
  });

  @override
  State<_PortHandle> createState() => _PortHandleState();
}

class _PortHandleState extends State<_PortHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => widget.onPortDragStart?.call(widget.portId),
        onPanUpdate: (d) => widget.onPortDragUpdate?.call(d.globalPosition),
        onPanEnd: (_) => widget.onPortDragEnd?.call(widget.portId),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _hovered ? 16 : 12,
              height: _hovered ? 16 : 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.dotColor,
                boxShadow: [
                  BoxShadow(
                    color: _hovered
                        ? widget.glowColor.withValues(alpha: 0.7)
                        : widget.glowColor.withValues(alpha: 0.3),
                    blurRadius: _hovered ? 10 : 4,
                    spreadRadius: _hovered ? 2 : 0,
                  ),
                ],
              ),
            ),
          ),
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
  final double zoom;
  final String? dragFromPort;
  final Offset dragOffset;
  final String? selectedEdgeId;
  final List<NodeExecutionResult> executionResults;
  final Offset? nearestDropPort;

  const _EdgePainter({
    required this.nodes,
    required this.edges,
    required this.offset,
    this.zoom = 1.0,
    this.dragFromPort,
    this.dragOffset = Offset.zero,
    this.selectedEdgeId,
    this.executionResults = const [],
    this.nearestDropPort,
  });

  Offset _outputPort(WorkflowNode n) => Offset(
      n.x * zoom + offset.dx + _kNodeW * zoom,
      n.y * zoom + offset.dy + _kNodeH * zoom / 2);

  Offset _inputPort(WorkflowNode n) =>
      Offset(n.x * zoom + offset.dx, n.y * zoom + offset.dy + _kNodeH * zoom / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final executionNodeIds =
        executionResults.map((r) => r.nodeId).toSet();
    final failedNodeIds = executionResults
        .where((r) => r.hasError)
        .map((r) => r.nodeId)
        .toSet();

    for (final edge in edges) {
      final from = _nodeById(edge.fromId);
      final to = _nodeById(edge.toId);
      if (from == null || to == null) continue;

      final src = _outputPort(from);
      final dst = _inputPort(to);

      final isSelected = edge.id == selectedEdgeId;

      // Determine edge color based on execution state
      Color edgeColor = AppTheme.border2;
      double strokeWidth = 2.0;

      if (executionNodeIds.contains(edge.fromId) &&
          executionNodeIds.contains(edge.toId)) {
        if (failedNodeIds.contains(edge.toId)) {
          edgeColor = AppTheme.error;
        } else {
          edgeColor = AppTheme.success;
        }
        strokeWidth = 2.5;
      }

      if (isSelected) {
        edgeColor = AppTheme.gold;
        strokeWidth = 3.0;
      }

      final edgePaint = Paint()
        ..color = edgeColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      _drawBezier(canvas, src, dst, edgePaint);
      _drawArrow(canvas, dst,
          math.atan2(dst.dy - src.dy, dst.dx - src.dx), edgePaint);

      // Draw selection glow
      if (isSelected) {
        final glowPaint = Paint()
          ..color = AppTheme.gold.withValues(alpha: 0.15)
          ..strokeWidth = 8.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        _drawBezier(canvas, src, dst, glowPaint);
      }
    }

    // ── Drag preview line ──────────────────────────────────────────────────
    if (dragFromPort != null && dragOffset != Offset.zero) {
      final parsed = _parsePortId(dragFromPort!);
      if (parsed != null) {
        final sourceNode = _nodeById(parsed.nodeId);
        if (sourceNode != null) {
          final src = parsed.side == 'output'
              ? _outputPort(sourceNode)
              : _inputPort(sourceNode);
          final dst = dragOffset;

          // Glow behind the preview line
          final glowPaint = Paint()
            ..color = AppTheme.gold.withValues(alpha: 0.12)
            ..strokeWidth = 8.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          _drawBezier(canvas, src, dst, glowPaint);

          // Main preview line (dashed-like via short dashes)
          final previewPaint = Paint()
            ..color = AppTheme.gold.withValues(alpha: 0.7)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          _drawBezier(canvas, src, dst, previewPaint);

          // Small dot at cursor position
          canvas.drawCircle(
            dst,
            5,
            Paint()..color = AppTheme.gold.withValues(alpha: 0.5),
          );
          canvas.drawCircle(
            dst,
            3,
            Paint()..color = AppTheme.gold,
          );

          // Highlight nearest compatible port
          if (nearestDropPort != null) {
            canvas.drawCircle(
              nearestDropPort!,
              10,
              Paint()
                ..color = AppTheme.gold.withValues(alpha: 0.25)
                ..style = PaintingStyle.fill,
            );
            canvas.drawCircle(
              nearestDropPort!,
              10,
              Paint()
                ..color = AppTheme.gold.withValues(alpha: 0.6)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          }
        }
      }
    }
  }

  _PortRef? _parsePortId(String portId) {
    final sep = portId.lastIndexOf('_');
    if (sep <= 0 || sep >= portId.length - 1) return null;
    final nodeId = portId.substring(0, sep);
    final side = portId.substring(sep + 1);
    if (side != 'input' && side != 'output') return null;
    return _PortRef(nodeId: nodeId, side: side);
  }

  void _drawBezier(Canvas canvas, Offset src, Offset dst, Paint paint) {
    final dx = (dst.dx - src.dx).abs().clamp(60.0, 200.0);
    final path = Path()
      ..moveTo(src.dx, src.dy)
      ..cubicTo(
        src.dx + dx * 0.5, src.dy,
        dst.dx - dx * 0.5, dst.dy,
        dst.dx, dst.dy,
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
      old.zoom != zoom ||
      old.dragFromPort != dragFromPort ||
      old.dragOffset != dragOffset ||
      old.selectedEdgeId != selectedEdgeId ||
      old.executionResults != executionResults ||
      old.nearestDropPort != nearestDropPort;
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
  State<_RenameNodeDialogWithMentions> createState() =>
      _RenameNodeDialogWithMentionsState();
}

class _RenameNodeDialogWithMentionsState
    extends State<_RenameNodeDialogWithMentions> {
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
    final cursor =
        selection.baseOffset >= 0 ? selection.baseOffset : _ctrl.text.length;
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

    if (triggerIndex > 0 &&
        !RegExp(r'\s').hasMatch(prefix[triggerIndex - 1])) {
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
      final suggestions = widget.libraryAgents
          .where((a) => q.isEmpty || a.title.toLowerCase().contains(q))
          .take(8)
          .toList();
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
        .where((m) =>
            q.isEmpty ||
            m.title.toLowerCase().contains(q) ||
            m.slug.toLowerCase().contains(q))
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
    if (!_showMentions &&
        _agentSuggestions.isEmpty &&
        _missionSuggestions.isEmpty) return;
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
    final cursor =
        selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 ||
        _mentionStart >= cursor ||
        cursor > text.length) return;

    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '@${agent.title}';
    final next = '$before$mention$after';
    _ctrl.value = TextEditingValue(
      text: next,
      selection:
          TextSelection.collapsed(offset: (before + mention).length),
    );
    _hideMentions();
  }

  void _insertMission(MissionModel mission) {
    final text = _ctrl.text;
    final selection = _ctrl.selection;
    final cursor =
        selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (_mentionStart < 0 ||
        _mentionStart >= cursor ||
        cursor > text.length) return;

    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final mention = '#${mission.slug}';
    final next = '$before$mention$after';
    _ctrl.value = TextEditingValue(
      text: next,
      selection:
          TextSelection.collapsed(offset: (before + mention).length),
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
              const Text('Rename Node',
                  style: TextStyle(
                      color: AppTheme.textH,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
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
                              child: Text('No agents found',
                                  style: TextStyle(
                                      color: AppTheme.textM,
                                      fontSize: 12)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _agentSuggestions.length,
                              itemBuilder: (_, i) {
                                final agent = _agentSuggestions[i];
                                final isSelected =
                                    i == _selectedSuggestionIndex;
                                return Container(
                                  color: isSelected
                                      ? AppTheme.primary
                                          .withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      visualDensity:
                                          VisualDensity.compact,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6),
                                      hoverColor: AppTheme.primary
                                          .withValues(alpha: 0.12),
                                      title: Text(agent.title,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: AppTheme.textH,
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500)),
                                      subtitle: Text(
                                          agent.characterType
                                              .displayName,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppTheme.textM,
                                              fontSize: 10)),
                                      trailing: isSelected
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: AppTheme.primary,
                                              size: 18)
                                          : null,
                                      onTap: () =>
                                          _insertMention(agent),
                                    ),
                                  ),
                                );
                              },
                            )
                      : _missionSuggestions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('No missions found',
                                  style: TextStyle(
                                      color: AppTheme.textM,
                                      fontSize: 12)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _missionSuggestions.length,
                              itemBuilder: (_, i) {
                                final mission =
                                    _missionSuggestions[i];
                                final isSelected =
                                    i == _selectedSuggestionIndex;
                                return Container(
                                  color: isSelected
                                      ? AppTheme.gold
                                          .withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      visualDensity:
                                          VisualDensity.compact,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6),
                                      hoverColor: AppTheme.gold
                                          .withValues(alpha: 0.1),
                                      title: Text('#${mission.slug}',
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: AppTheme.gold,
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600)),
                                      subtitle: Text(mission.title,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppTheme.textM,
                                              fontSize: 10)),
                                      trailing: isSelected
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: AppTheme.gold,
                                              size: 18)
                                          : null,
                                      onTap: () =>
                                          _insertMission(mission),
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
                    child: const Text('Cancel',
                        style: TextStyle(color: AppTheme.textM)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary),
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
        hintStyle:
            TextStyle(color: AppTheme.textM.withValues(alpha: 0.6)),
        filled: true,
        fillColor: AppTheme.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          borderSide:
              const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }
}
