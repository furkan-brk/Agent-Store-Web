// lib/features/legend/screens/legend_screen.dart

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/models/guild_model.dart';
import '../../../shared/models/mission_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/mission_service.dart' show MissionService, SyncStatus;
import '../models/workflow_models.dart';
import '../../../core/utils/input_mode.dart';
import '../services/claude_export_service.dart';
import '../services/legend_service.dart';
import '../widgets/legend_export_dialog.dart';
import '../widgets/legend_onboarding.dart';

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
  double _baseZoom = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  String? _selectedNodeId;
  String? _selectedEdgeId;

  // Port dragging
  String? _dragFromPort;
  Offset _dragCurrentOffset = Offset.zero;

  final GlobalKey _canvasKey = GlobalKey();

  // ── Palette data ───────────────────────────────────────────────────────────
  List<AgentModel> _libraryAgents = [];
  List<MissionModel> _missions = [];
  List<GuildModel> _guilds = [];
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

  // ── Onboarding ────────────────────────────────────────────────────────────
  bool _showOnboarding = false;

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
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final show = await LegendOnboarding.shouldShow();
    if (show && mounted) setState(() => _showOnboarding = true);
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
      final isAuth = ApiService.instance.isAuthenticated;
      final agents = isAuth
          ? await ApiService.instance.getLibrary()
          : <AgentModel>[];
      final guildsResult = isAuth
          ? await ApiService.instance.listGuilds(limit: 50)
          : (guilds: <GuildModel>[], total: 0);
      if (!mounted) return;
      setState(() {
        _libraryAgents = agents;
        _missions = MissionService.instance.missions;
        _guilds = guildsResult.guilds;
        _savedWorkflows = LegendService.instance.workflows;
        _loadingAgents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _libraryAgents = <AgentModel>[];
        _missions = MissionService.instance.missions;
        _guilds = <GuildModel>[];
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

  // ── Unsaved changes tracking ──────────────────────────────────────────
  String _lastSavedState = '';

  bool get _hasUnsavedChanges {
    final current = jsonEncode({'nodes': _nodes.map((n) => n.toJson()).toList(), 'edges': _edges.map((e) => e.toJson()).toList()});
    return current != _lastSavedState && (_nodes.isNotEmpty || _edges.isNotEmpty);
  }

  void _markSaved() {
    _lastSavedState = jsonEncode({'nodes': _nodes.map((n) => n.toJson()).toList(), 'edges': _edges.map((e) => e.toJson()).toList()});
  }

  String _fmtTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
        metadata: n.metadata,
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
    final maxDistance = InputModeDetector.portSnapDistance;
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

  void _onCanvasScaleStart(ScaleStartDetails d) {
    _baseZoom = _zoom;
    _lastFocalPoint = d.focalPoint;
  }

  void _onCanvasScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.scale == 1.0) {
        // Pan
        final delta = d.focalPoint - _lastFocalPoint;
        _canvasOffset += delta;
        if (_dragFromPort != null) {
          _onPortDragUpdate(d.focalPoint);
        }
      } else {
        // Pinch zoom toward focal point
        final newZoom = (_baseZoom * d.scale).clamp(0.3, 2.0);
        final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final localFocal = box.globalToLocal(d.focalPoint);
          final focalBefore = (localFocal - _canvasOffset) / _zoom;
          _zoom = newZoom;
          _canvasOffset = localFocal - focalBefore * _zoom;
        } else {
          _zoom = newZoom;
        }
      }
      _lastFocalPoint = d.focalPoint;
    });
  }

  void _onCanvasZoom(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        final step = event.kind == PointerDeviceKind.trackpad ? 0.01 : 0.05;
        final delta = event.scrollDelta.dy > 0 ? -step : step;
        final newZoom = (_zoom + delta).clamp(0.3, 2.0);

        // Zoom toward cursor position
        final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final localPos = box.globalToLocal(event.position);
          final focalBefore = (localPos - _canvasOffset) / _zoom;
          _zoom = newZoom;
          _canvasOffset = localPos - focalBefore * _zoom;
        } else {
          _zoom = newZoom;
        }
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
    _markSaved();
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
    _markSaved();
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
        title: const Row(
          children: [
            Icon(Icons.rocket_launch_outlined,
                color: AppTheme.gold, size: 20),
            SizedBox(width: 8),
            Text('Execute Workflow',
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

  // ── Node settings dialog ─────────────────────────────────────────────────

  void _showNodeSettingsDialog(WorkflowNode node) {
    final meta = node.metadata ?? {};
    var engine = meta['engine'] as String? ?? 'gemini';
    var model = meta['model'] as String? ?? 'sonnet';
    var label = node.label;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.card,
            title: const Row(
              children: [
                Icon(Icons.settings, color: AppTheme.gold, size: 18),
                SizedBox(width: 8),
                Text('Node Settings', style: TextStyle(color: AppTheme.textH, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label
                  const Text('Label', style: TextStyle(color: AppTheme.textM, fontSize: 11)),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: label,
                    style: const TextStyle(color: AppTheme.textB, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) => label = v,
                  ),
                  const SizedBox(height: 14),
                  // Engine
                  const Text('Execution Engine', style: TextStyle(color: AppTheme.textM, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _SettingsChip(label: 'Claude', selected: engine == 'claude', color: const Color(0xFF8B5CF6),
                          onTap: () => setDialogState(() => engine = 'claude')),
                      const SizedBox(width: 8),
                      _SettingsChip(label: 'Gemini', selected: engine == 'gemini', color: const Color(0xFF3B82F6),
                          onTap: () => setDialogState(() => engine = 'gemini')),
                    ],
                  ),
                  if (engine == 'claude') ...[
                    const SizedBox(height: 14),
                    const Text('Model', style: TextStyle(color: AppTheme.textM, fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _SettingsChip(label: 'Haiku (1cr)', selected: model == 'haiku', color: const Color(0xFF10B981),
                            onTap: () => setDialogState(() => model = 'haiku')),
                        const SizedBox(width: 6),
                        _SettingsChip(label: 'Sonnet (3cr)', selected: model == 'sonnet', color: const Color(0xFFF59E0B),
                            onTap: () => setDialogState(() => model = 'sonnet')),
                        const SizedBox(width: 6),
                        _SettingsChip(label: 'Opus (10cr)', selected: model == 'opus', color: const Color(0xFFEF4444),
                            onTap: () => setDialogState(() => model = 'opus')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.bg),
                onPressed: () {
                  final idx = _nodes.indexWhere((n) => n.id == node.id);
                  if (idx >= 0) {
                    final newMeta = Map<String, dynamic>.from(meta);
                    newMeta['engine'] = engine;
                    if (engine == 'claude') newMeta['model'] = model;
                    setState(() {
                      _nodes[idx] = _nodes[idx].copyWith(
                        label: label.trim().isNotEmpty ? label.trim() : null,
                        metadata: newMeta,
                      );
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  int _calculateTotalCredits() {
    int total = 0;
    for (final node in _nodes) {
      if (node.type != WorkflowNodeType.agent) continue;
      final engine = node.metadata?['engine'] as String? ?? 'gemini';
      if (engine == 'claude') {
        final model = node.metadata?['model'] as String? ?? 'sonnet';
        switch (model) {
          case 'haiku': total += 1; break;
          case 'sonnet': total += 3; break;
          case 'opus': total += 10; break;
        }
      } else {
        total += 1; // gemini = 1 credit
      }
    }
    return total;
  }

  // ── Split guild node ─────────────────────────────────────────────────────

  Future<void> _splitGuildNode(WorkflowNode guildNode) async {
    if (guildNode.type != WorkflowNodeType.guild || guildNode.refId == null) {
      return;
    }

    final guildId = int.tryParse(guildNode.refId!);
    if (guildId == null) return;

    // Try to find the guild in already-loaded list
    GuildModel? guild;
    for (final g in _guilds) {
      if (g.id == guildId) {
        guild = g;
        break;
      }
    }

    // If guild has no members in local data, fetch from API
    if (guild == null || guild.members.isEmpty) {
      final detail = await ApiService.instance.getGuild(guildId);
      if (detail != null) {
        guild = detail.guild;
      }
    }

    if (guild == null || guild.members.isEmpty) {
      _showNotice('Guild has no members to split into.',
          background: AppTheme.error);
      return;
    }

    final members = guild.members;
    final newNodes = <WorkflowNode>[];
    final ts = DateTime.now().millisecondsSinceEpoch;

    // Create individual agent nodes spread horizontally
    for (int i = 0; i < members.length; i++) {
      final member = members[i];
      final agentTitle = member.agent?.title ?? 'Agent #${member.agentId}';
      newNodes.add(WorkflowNode(
        id: '${ts}_split_$i',
        type: WorkflowNodeType.agent,
        label: agentTitle,
        x: (guildNode.x + i * 200).clamp(0.0, 4000.0),
        y: guildNode.y,
        refId: member.agentId.toString(),
      ));
    }

    // Build chain edges between agent nodes
    final newEdges = <WorkflowEdge>[];
    for (int i = 0; i < newNodes.length - 1; i++) {
      newEdges.add(WorkflowEdge(
        id: '${newNodes[i].id}_${newNodes[i + 1].id}',
        fromId: newNodes[i].id,
        toId: newNodes[i + 1].id,
      ));
    }

    // Re-wire existing edges
    final firstNewId = newNodes.first.id;
    final lastNewId = newNodes.last.id;
    final rewiredEdges = <WorkflowEdge>[];

    for (final edge in _edges) {
      if (edge.toId == guildNode.id && edge.fromId == guildNode.id) {
        // Self-loop — skip
        continue;
      } else if (edge.toId == guildNode.id) {
        // Edges pointing TO guild → point to FIRST agent
        rewiredEdges.add(WorkflowEdge(
          id: '${edge.fromId}_$firstNewId',
          fromId: edge.fromId,
          toId: firstNewId,
        ));
      } else if (edge.fromId == guildNode.id) {
        // Edges pointing FROM guild → point from LAST agent
        rewiredEdges.add(WorkflowEdge(
          id: '${lastNewId}_${edge.toId}',
          fromId: lastNewId,
          toId: edge.toId,
        ));
      } else {
        // Keep edge as-is
        rewiredEdges.add(edge);
      }
    }

    setState(() {
      _nodes.removeWhere((n) => n.id == guildNode.id);
      _nodes.addAll(newNodes);
      _edges = [...rewiredEdges, ...newEdges];
      _selectedNodeId = null;
    });

    _showNotice(
      'Guild split into ${newNodes.length} agent nodes',
      background: AppTheme.success,
    );
  }

  // ── Export workflow JSON ─────────────────────────────────────────────────

  void _showExportDialog() {
    if (!_hasCanvasContent) {
      _showNotice('Add nodes to export.', background: AppTheme.error);
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
    final json = const JsonEncoder.withIndent('  ').convert(wf.toJson());

    showDialog(
      context: context,
      builder: (_) => LegendExportDialog(
        workflow: wf,
        workflowJson: json,
        lastExecution: _lastExecution,
      ),
    );
  }

  // ── Import workflow JSON ─────────────────────────────────────────────────

  void _showImportDialog() {
    showDialog<String>(
      context: context,
      builder: (_) => const _ImportJsonDialog(),
    ).then((jsonStr) {
      if (jsonStr == null || jsonStr.trim().isEmpty) return;
      _importWorkflowFromJson(jsonStr);
    });
  }

  void _importWorkflowFromJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        _showNotice('Invalid JSON: expected an object.', background: AppTheme.error);
        return;
      }

      final wf = LegendWorkflow.fromJson(decoded);

      if (wf.nodes.isEmpty) {
        _showNotice('Workflow has no nodes.', background: AppTheme.error);
        return;
      }

      _confirmReplaceCanvas(() {
        setState(() {
          _nodes
            ..clear()
            ..addAll(wf.nodes);
          _edges
            ..clear()
            ..addAll(wf.edges);
          _workflowName = wf.name;
          _currentWorkflowId = wf.id;
          _selectedNodeId = null;
          _selectedEdgeId = null;
          _lastExecution = null;
        });
        _showNotice('Workflow imported: ${wf.name}', background: AppTheme.success);
      });
    } catch (e) {
      _showNotice('Failed to parse JSON: $e', background: AppTheme.error);
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return PopScope(
          canPop: !_hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final action = await _showUnsavedDialog();
            if (!mounted) return;
            if (action == 'save') {
              await _saveWorkflow();
              if (mounted) Navigator.of(context).maybePop();
            } else if (action == 'discard') {
              _markSaved(); // clear dirty flag
              if (mounted) Navigator.of(context).maybePop();
            }
          },
          child: Scaffold(
          backgroundColor: AppTheme.bg,
          drawer: isMobile
              ? Drawer(
                  backgroundColor: AppTheme.surface,
                  child: SafeArea(child: _buildLeftPanel()),
                )
              : null,
          body: Stack(children: [
            KeyboardListener(
            focusNode: FocusNode()..requestFocus(),
            autofocus: true,
            onKeyEvent: (event) {
              if (event is! KeyDownEvent) return;
              final ctrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
              if (ctrl && event.logicalKey == LogicalKeyboardKey.keyS) {
                _saveWorkflow();
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                setState(() { _selectedNodeId = null; _selectedEdgeId = null; });
              } else if (ctrl && event.logicalKey == LogicalKeyboardKey.slash) {
                _showKeyboardShortcutsDialog();
              } else if (event.logicalKey == LogicalKeyboardKey.delete) {
                _deleteSelected();
              }
            },
            child: Column(
              children: [
                _buildToolbar(isMobile: isMobile),
                Expanded(
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isMobile) _buildLeftPanel(),
                          if (!isMobile) const VerticalDivider(width: 1, color: AppTheme.border),
                          Expanded(child: _buildCanvas()),
                          if (_showResultsPanel) ...[
                            const VerticalDivider(width: 1, color: AppTheme.border),
                            _buildResultsPanel(),
                          ],
                        ],
                      ),
                      // Floating zoom controls for mobile
                      if (isMobile)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ZoomFab(icon: Icons.add, onTap: () => setState(() {
                                _zoom = (_zoom + 0.1).clamp(0.3, 2.0);
                              })),
                              const SizedBox(height: 6),
                              _ZoomFab(icon: Icons.remove, onTap: () => setState(() {
                                _zoom = (_zoom - 0.1).clamp(0.3, 2.0);
                              })),
                              const SizedBox(height: 6),
                              _ZoomFab(icon: Icons.crop_free, onTap: () => setState(() {
                                _zoom = 1.0;
                                _canvasOffset = Offset.zero;
                              })),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showOnboarding)
            LegendOnboarding(
              onDismiss: () => setState(() => _showOnboarding = false),
            ),
          ]),
        ),
        );
      },
    );
  }

  Future<String?> _showUnsavedDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        icon: const Icon(Icons.warning_amber_rounded, color: AppTheme.gold, size: 28),
        title: const Text('Unsaved Changes', style: TextStyle(color: AppTheme.textH, fontWeight: FontWeight.bold)),
        content: const Text('You have unsaved changes. What would you like to do?', style: TextStyle(color: AppTheme.textB)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard', style: TextStyle(color: AppTheme.primary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: const Color(0xFF1E1A14)),
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save & Leave'),
          ),
        ],
      ),
    );
  }

  void _showKeyboardShortcutsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Text('Keyboard Shortcuts', style: TextStyle(color: AppTheme.textH, fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _shortcutRow('Ctrl + S', 'Save workflow'),
              _shortcutRow('Escape', 'Deselect node/edge'),
              _shortcutRow('Delete', 'Delete selected'),
              _shortcutRow('Ctrl + /', 'Show shortcuts'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.textM)),
          ),
        ],
      ),
    );
  }

  Widget _shortcutRow(String key, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(key, style: const TextStyle(color: AppTheme.textH, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ),
        const SizedBox(width: 16),
        Text(desc, style: const TextStyle(color: AppTheme.textM, fontSize: 13)),
      ]),
    );
  }

  // ── Toolbar ────────────────────────────────────────────────────────────────

  Widget _buildToolbar({bool isMobile = false}) {
    return Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: AppTheme.textM, size: 20),
              onPressed: () => Scaffold.of(context).openDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 18),
          if (!isMobile) ...[
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
            const SizedBox(width: 8),
            // Sync status indicator
            ValueListenableBuilder<SyncStatus>(
              valueListenable: LegendService.instance.syncStatusNotifier,
              builder: (_, status, __) => switch (status) {
                SyncStatus.synced => Tooltip(
                    message: 'Synced${LegendService.instance.lastSyncTime != null ? " at ${_fmtTime(LegendService.instance.lastSyncTime!)}" : ""}',
                    child: const Icon(Icons.cloud_done_rounded, color: AppTheme.olive, size: 14),
                  ),
                SyncStatus.syncing => const Tooltip(
                    message: 'Syncing...',
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.gold)),
                  ),
                SyncStatus.failed => Tooltip(
                    message: LegendService.instance.syncError ?? 'Sync failed',
                    child: GestureDetector(
                      onTap: () => LegendService.instance.forceSyncToBackend(),
                      child: const Icon(Icons.cloud_off_rounded, color: AppTheme.primary, size: 14),
                    ),
                  ),
                SyncStatus.pending => const SizedBox.shrink(),
              },
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
          ],
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
          // Split button — only when a guild node is selected
          if (_selectedNodeId != null &&
              _nodes.any((n) =>
                  n.id == _selectedNodeId &&
                  n.type == WorkflowNodeType.guild)) ...[
            _ToolbarButton(
              icon: Icons.call_split,
              label: 'Split',
              accent: true,
              onTap: () {
                final guildNode = _nodes.firstWhere(
                    (n) => n.id == _selectedNodeId);
                _splitGuildNode(guildNode);
              },
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
            icon: Icons.data_object,
            label: 'Export',
            onTap: _showExportDialog,
          ),
          const SizedBox(width: 6),
          _ToolbarButton(
            icon: Icons.upload_outlined,
            label: 'Import',
            onTap: _showImportDialog,
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
          if (_nodes.any((n) => n.type == WorkflowNodeType.agent)) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${_calculateTotalCredits()} cr',
                style: const TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(width: 6),
          _ToolbarButton(
            icon: Icons.help_outline_rounded,
            label: '?',
            onTap: _showKeyboardShortcutsDialog,
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
          const SizedBox(height: 12),
          _PaletteSection(
            label: 'GUILDS',
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
                            color: Color(0xFFFFA000),
                          ),
                        ),
                      ),
                    )
                  ]
                : _guilds.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No guilds available.\nCreate guilds first.',
                            style: TextStyle(
                                color: AppTheme.textM, fontSize: 11),
                          ),
                        )
                      ]
                    : _guilds
                        .map(
                          (g) => _DraggablePaletteItem(
                            data: _NodeDragData(WorkflowNodeType.guild,
                                g.name, g.id.toString()),
                            color: const Color(0xFFFFA000),
                            icon: Icons.shield_outlined,
                            label: g.name,
                            subtitle: '${g.memberCount} members',
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

  // ── Canvas ─────────────────────────────────────────────────────────────────

  Widget _buildCanvas() {
    return DragTarget<_NodeDragData>(
      onAcceptWithDetails: (d) => _addNode(d.data, d.offset),
      builder: (ctx, candidates, rejected) {
        final highlight = candidates.isNotEmpty;
        return Listener(
          onPointerSignal: _onCanvasZoom,
          onPointerDown: (e) => InputModeDetector.detectFromPointerEvent(e),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bg,
              border: highlight
                  ? Border.all(color: AppTheme.primary, width: 2)
                  : null,
            ),
            child: ClipRect(
              child: GestureDetector(
                onScaleStart: _onCanvasScaleStart,
                onScaleUpdate: _onCanvasScaleUpdate,
                onScaleEnd: (_) {},
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
                            onDoubleTap: () => node.type == WorkflowNodeType.agent
                                ? _showNodeSettingsDialog(node)
                                : _showRenameNodeDialog(node),
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
    final isMobile = MediaQuery.of(context).size.width < 768;
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
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 7 : 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: fg.withValues(alpha: accent ? 0.5 : 0.25)),
          ),
          child: isMobile
              ? Icon(icon, size: 14, color: fg)
              : Row(
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
      case 'guild':
        return const Color(0xFFFFA000);
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
      case 'guild':
        return Icons.shield_outlined;
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
          'Drag agents, missions & guilds here',
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

  static const _guildAmber = Color(0xFFFFA000);

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
      case WorkflowNodeType.guild:
        return _guildAmber;
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
      case WorkflowNodeType.guild:
        return Icons.shield_outlined;
      case WorkflowNodeType.end:
        return Icons.stop_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final portId = node.id;
    final hasResult = executionResult != null;
    final isGuild = node.type == WorkflowNodeType.guild;

    // Guild nodes get a thicker border for visual distinction
    final borderWidth = isSelected
        ? 2.5
        : isGuild
            ? 2.0
            : hasResult
                ? 1.5
                : 1.0;
    final borderColor = isSelected
        ? accent
        : isGuild
            ? _guildAmber.withValues(alpha: 0.7)
            : hasResult
                ? accent.withValues(alpha: 0.6)
                : AppTheme.border;

    return SizedBox(
      width: _kNodeW,
      height: _kNodeH,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isGuild
              ? _guildAmber.withValues(alpha: 0.06)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: 2,
              )
            else if (isGuild)
              BoxShadow(
                color: _guildAmber.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
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
            // Engine/model badge
            if (node.type == WorkflowNodeType.agent && node.metadata?['engine'] != null)
              Positioned(
                left: 6,
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: node.metadata!['engine'] == 'claude'
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      node.metadata!['engine'] == 'claude'
                          ? (node.metadata!['model'] as String? ?? 'sonnet').substring(0, 1).toUpperCase() +
                            (node.metadata!['model'] as String? ?? 'sonnet').substring(1)
                          : 'Gemini',
                      style: TextStyle(
                        color: node.metadata!['engine'] == 'claude'
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF3B82F6),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
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
              left: -(InputModeDetector.portHitSize / 2),
              top: _kNodeH / 2 - InputModeDetector.portHitSize / 2,
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
              right: -(InputModeDetector.portHitSize / 2),
              top: _kNodeH / 2 - InputModeDetector.portHitSize / 2,
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
        onLongPressStart: (_) => widget.onPortDragStart?.call(widget.portId),
        child: SizedBox(
          width: InputModeDetector.portHitSize,
          height: InputModeDetector.portHitSize,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _hovered ? (InputModeDetector.isTouch ? 18 : 16) : (InputModeDetector.isTouch ? 14 : 12),
              height: _hovered ? (InputModeDetector.isTouch ? 18 : 16) : (InputModeDetector.isTouch ? 14 : 12),
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
        _missionSuggestions.isEmpty) {
      return;
    }
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
        cursor > text.length) {
      return;
    }

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
        cursor > text.length) {
      return;
    }

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

class _MentionTextField extends StatelessWidget {
  final TextEditingController controller;

  const _MentionTextField({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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

// ── Export JSON Dialog ──────────────────────────────────────────────────────

class _ZoomFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: const CircleBorder(side: BorderSide(color: AppTheme.border)),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: AppTheme.textB),
        ),
      ),
    );
  }
}

class _SettingsChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SettingsChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.2) : AppTheme.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.5 : 1),
          ),
          child: Text(label, style: TextStyle(color: selected ? color : AppTheme.textM, fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ),
      ),
    );
  }
}

// ── Import JSON Dialog ──────────────────────────────────────────────────────

class _ImportJsonDialog extends StatefulWidget {
  const _ImportJsonDialog();

  @override
  State<_ImportJsonDialog> createState() => _ImportJsonDialogState();
}

class _ImportJsonDialogState extends State<_ImportJsonDialog> {
  final _controller = TextEditingController();
  String? _error;
  int _selectedTab = 0; // 0=Workflow JSON, 1=Claude Team Config, 2=Claude Agent .md, 3=Claude Context

  static const _tabLabels = ['Workflow JSON', 'Team Config', 'Agent .md', 'Context'];
  static const _tabHints = [
    '{\n  "id": "...",\n  "name": "...",\n  "nodes": [...],\n  "edges": [...]\n}',
    '{\n  "team_name": "...",\n  "agents": [\n    {"name": "...", "system_prompt": "..."}\n  ]\n}',
    '---\nname: my-agent\nmodel: sonnet\ncolor: blue\n---\n\nYour agent prompt here...',
    '# Workflow Execution Context: ...\n\n### Step 1: Agent Name (type)\n**Output:**\n...',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = null);
      return;
    }

    switch (_selectedTab) {
      case 0: // Workflow JSON
        try {
          final decoded = jsonDecode(text);
          if (decoded is! Map<String, dynamic>) {
            setState(() => _error = 'JSON must be an object with nodes and edges.');
            return;
          }
          if (decoded['nodes'] == null) {
            setState(() => _error = 'Missing "nodes" field.');
            return;
          }
          setState(() => _error = null);
        } catch (e) {
          setState(() => _error = 'Invalid JSON syntax.');
        }
        break;
      case 1: // Claude Team Config
        try {
          final decoded = jsonDecode(text);
          if (decoded is! Map<String, dynamic>) {
            setState(() => _error = 'JSON must be an object.');
            return;
          }
          if (decoded['agents'] == null || decoded['agents'] is! List) {
            setState(() => _error = 'Missing or invalid "agents" array.');
            return;
          }
          setState(() => _error = null);
        } catch (e) {
          setState(() => _error = 'Invalid JSON syntax.');
        }
        break;
      case 2: // Claude Agent .md
        if (!text.contains('---')) {
          setState(() => _error = 'Missing frontmatter delimiters (---).');
          return;
        }
        final parts = text.split('---');
        if (parts.length < 3) {
          setState(() => _error = 'Need opening and closing --- for frontmatter.');
          return;
        }
        setState(() => _error = null);
        break;
      case 3: // Claude Context
        if (!text.contains('### Step')) {
          setState(() => _error = 'No execution steps found. Expected "### Step N: ..." blocks.');
          return;
        }
        setState(() => _error = null);
        break;
    }
  }

  String? _buildImportResult() {
    final text = _controller.text.trim();

    switch (_selectedTab) {
      case 0: // Workflow JSON — return as-is
        return text;
      case 1: // Claude Team Config — parse and convert to workflow JSON
        final wf = ClaudeExportService.parseTeamConfig(text);
        if (wf == null) return null;
        return jsonEncode(wf.toJson());
      case 2: // Claude Agent .md — parse and create single-node workflow
        final result = ClaudeExportService.parseAgentMd(text);
        if (result == null) return null;
        final wf = LegendWorkflow(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result.node.label,
          nodes: [
            WorkflowNode(id: 'start_0', type: WorkflowNodeType.start, label: 'START', x: 50, y: 200),
            result.node,
            WorkflowNode(id: 'end_0', type: WorkflowNodeType.end, label: 'END', x: 550, y: 200),
          ],
          edges: [
            WorkflowEdge(id: 'e_start_agent', fromId: 'start_0', toId: result.node.id),
            WorkflowEdge(id: 'e_agent_end', fromId: result.node.id, toId: 'end_0'),
          ],
          updatedAt: DateTime.now(),
        );
        return jsonEncode(wf.toJson());
      case 3: // Claude Context — parse execution context markdown
        final wf = ClaudeExportService.parseClaudeContext(text);
        if (wf == null) return null;
        return jsonEncode(wf.toJson());
      default:
        return null;
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _controller.text = data.text!;
      _validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: const Row(
        children: [
          Icon(Icons.upload_outlined, color: AppTheme.gold, size: 20),
          SizedBox(width: 8),
          Text('Import Workflow',
              style: TextStyle(color: AppTheme.textH, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tab buttons
            Row(
              children: List.generate(_tabLabels.length, (i) {
                final selected = _selectedTab == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: selected
                        ? AppTheme.gold.withValues(alpha: 0.15)
                        : AppTheme.bg,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedTab = i;
                          _error = null;
                        });
                        if (_controller.text.isNotEmpty) _validate();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text(
                          _tabLabels[i],
                          style: TextStyle(
                            color: selected ? AppTheme.gold : AppTheme.textM,
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedTab == 0
                        ? 'Paste a workflow JSON exported from Legend.'
                        : _selectedTab == 1
                            ? 'Paste a Claude team config.json.'
                            : _selectedTab == 2
                                ? 'Paste a Claude agent .md file content.'
                                : 'Paste an execution context markdown.',
                    style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste, size: 14),
                  label: const Text('Paste'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _error != null ? AppTheme.error : AppTheme.border,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    color: AppTheme.textB,
                    fontSize: 11,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: _tabHints[_selectedTab],
                    hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 11),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => _validate(),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textM)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: AppTheme.bg,
          ),
          icon: const Icon(Icons.upload, size: 14),
          label: const Text('Import'),
          onPressed: _controller.text.trim().isEmpty || _error != null
              ? null
              : () {
                  final result = _buildImportResult();
                  if (result == null) {
                    setState(() => _error = 'Failed to parse content. Check format.');
                    return;
                  }
                  Navigator.pop(context, result);
                },
        ),
      ],
    );
  }
}
