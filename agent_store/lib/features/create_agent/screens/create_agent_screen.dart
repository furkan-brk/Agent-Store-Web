import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../wallet/screens/wallet_connect_screen.dart';

class CreateAgentScreen extends StatefulWidget {
  const CreateAgentScreen({super.key});
  @override
  State<CreateAgentScreen> createState() => _CreateAgentScreenState();
}

class _CreateAgentScreenState extends State<CreateAgentScreen> {
  final _form       = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _promptCtrl = TextEditingController();
  bool _loading     = false;
  String _loadingMsg = 'Analyzing prompt…';
  CharacterType _preview = CharacterType.wizard;
  AgentModel? _createdAgent;
  int _credits = 100;
  int _step = 0;

  static const List<String> _stepLabels = ['Basic Info', 'Prompt', 'Preview'];

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    if (ApiService.instance.isAuthenticated) {
      final c = await ApiService.instance.getCredits();
      if (mounted) setState(() => _credits = c);
    }
  }

  Future<bool> _checkCredits() async {
    if (_credits < 10) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border2),
          ),
          title: const Text('Insufficient Credits', style: TextStyle(color: AppTheme.textH)),
          content: Text(
            'You need ⚡10 credits to create an agent. You have ⚡$_credits.',
            style: const TextStyle(color: AppTheme.textB),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () { Navigator.of(ctx).pop(); context.go('/wallet'); },
              child: const Text('Get Credits'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  void _updatePreview() {
    final p = _promptCtrl.text.toLowerCase();
    CharacterType t = CharacterType.wizard;
    if (p.contains('plan') || p.contains('strateg') || p.contains('manager')) {
      t = CharacterType.strategist;
    } else if (p.contains('data') || p.contains('analyt') || p.contains('ml')) {
      t = CharacterType.oracle;
    } else if (p.contains('security') || p.contains('infra')) {
      t = CharacterType.guardian;
    } else if (p.contains('frontend') || p.contains('ui') || p.contains('design')) {
      t = CharacterType.artisan;
    } else if (p.contains('write') || p.contains('creat') || p.contains('story')) {
      t = CharacterType.bard;
    } else if (p.contains('research') || p.contains('learn') || p.contains('study')) {
      t = CharacterType.scholar;
    } else if (p.contains('business') || p.contains('sales') || p.contains('market')) {
      t = CharacterType.merchant;
    }
    if (_preview != t) setState(() => _preview = t);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final hasCredits = await _checkCredits();
    if (!hasCredits) return;

    setState(() { _loading = true; _loadingMsg = 'Analyzing prompt…'; });
    Future.delayed(const Duration(seconds: 4)).then((_) {
      if (mounted && _loading) setState(() => _loadingMsg = 'Building character profile…');
    });
    Future.delayed(const Duration(seconds: 14)).then((_) {
      if (mounted && _loading) setState(() => _loadingMsg = 'Generating avatar image…');
    });
    Future.delayed(const Duration(seconds: 55)).then((_) {
      if (mounted && _loading) setState(() => _loadingMsg = 'Almost there…');
    });

    final agent = await ApiService.instance.createAgent(
      title: _titleCtrl.text,
      description: _descCtrl.text,
      prompt: _promptCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (agent != null) {
      setState(() => _createdAgent = agent);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Agent created with unique AI character!'),
        backgroundColor: AppTheme.olive,
      ));
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) context.go('/agent/${agent.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Creation failed. Try again or check your connection.'),
        backgroundColor: AppTheme.primary,
      ));
    }
  }

  void _nextStep() {
    if (_step == 0) {
      if (_titleCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Title is required to continue.'),
          backgroundColor: AppTheme.primary,
        ));
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_promptCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Prompt is required to continue.'),
          backgroundColor: AppTheme.primary,
        ));
        return;
      }
      setState(() => _step = 2);
    }
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  Widget _stepIndicator() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: List.generate(3, (i) {
        final active = i == _step;
        final done = i < _step;
        return Expanded(child: Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: (done || active) ? AppTheme.primary : AppTheme.card2,
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('${i + 1}', style: TextStyle(
                    color: (done || active) ? Colors.white : AppTheme.textM,
                    fontSize: 12)),
          ),
          if (i < 2) Expanded(child: Container(
            height: 2,
            color: i < _step ? AppTheme.primary : AppTheme.border,
          )),
        ]));
      })),
      const SizedBox(height: 8),
      Row(children: List.generate(3, (i) {
        final active = i == _step;
        final done = i < _step;
        return Expanded(child: Text(_stepLabels[i], style: TextStyle(
          color: (done || active) ? AppTheme.primary : AppTheme.textM,
          fontSize: 11,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        )));
      })),
    ]);
  }

  Widget _step0Content() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _field('Title *', _titleCtrl, required: true, hint: 'My Awesome Agent'),
    const SizedBox(height: 14),
    _field('Description', _descCtrl, hint: 'What does this agent do?', lines: 3),
    const SizedBox(height: 28),
    _navButtons(showNext: true, showBack: false, showSubmit: false),
  ]);

  Widget _step1Content() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextFormField(
      controller: _promptCtrl,
      onChanged: (_) => _updatePreview(),
      maxLines: 10,
      style: const TextStyle(color: AppTheme.textH, fontFamily: 'monospace', fontSize: 12),
      validator: (v) => (v == null || v.isEmpty) ? 'Prompt is required' : null,
      decoration: const InputDecoration(
        labelText: 'Prompt *',
        hintText: 'You are a helpful assistant that…',
        alignLabelWithHint: true,
      ),
    ),
    const SizedBox(height: 28),
    _navButtons(showNext: true, showBack: true, showSubmit: false),
  ]);

  Widget _step2Content() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Center(child: Column(children: [
      PixelCharacterWidget(
        characterType: _preview,
        rarity: CharacterRarity.common,
        size: 160,
        showName: true,
        showRarity: true,
      ),
      const SizedBox(height: 12),
      Text(_preview.description,
        style: const TextStyle(color: AppTheme.textB, fontSize: 12, height: 1.5),
        textAlign: TextAlign.center),
      const SizedBox(height: 6),
      const Text('AI will generate a unique character after submission',
        style: TextStyle(color: AppTheme.textM, fontSize: 11), textAlign: TextAlign.center),
    ])),
    const SizedBox(height: 24),
    Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16130C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Summary', style: TextStyle(
          color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        _summaryRow('Title', _titleCtrl.text.isEmpty ? '—' : _titleCtrl.text),
        if (_descCtrl.text.isNotEmpty) _summaryRow('Description', _descCtrl.text),
        _summaryRow('Prompt length', '${_promptCtrl.text.length} chars'),
        _summaryRow('Cost', '⚡10 credits'),
        _summaryRow('Remaining', '⚡${_credits - 10} after creation'),
      ]),
    ),
    const SizedBox(height: 28),
    _navButtons(showNext: false, showBack: true, showSubmit: true),
  ]);

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110,
        child: Text(label, style: const TextStyle(color: AppTheme.textM, fontSize: 12))),
      Expanded(child: Text(value,
        style: const TextStyle(color: AppTheme.textH, fontSize: 12),
        overflow: TextOverflow.ellipsis, maxLines: 2)),
    ]),
  );

  Widget _navButtons({required bool showNext, required bool showBack, required bool showSubmit}) =>
    Row(children: [
      if (showBack) ...[
        OutlinedButton.icon(
          onPressed: _prevStep,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back'),
        ),
        const SizedBox(width: 12),
      ],
      if (showNext)
        Expanded(child: ElevatedButton.icon(
          onPressed: _nextStep,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('Next'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
      if (showSubmit)
        Expanded(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF8B1A11)]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 10),
                  Text(_loadingMsg, style: const TextStyle(color: Colors.white)),
                ])
              : const Text('Create Agent  ⚡10'),
          ),
        )),
    ]);

  @override
  Widget build(BuildContext context) {
    if (!ApiService.instance.isAuthenticated) return const WalletConnectScreen();
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    body: Row(children: [
      // Left preview panel
      Container(
        width: 260,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_preview.primaryColor.withValues(alpha: 0.12), AppTheme.surface]),
          border: const Border(right: BorderSide(color: AppTheme.border)),
        ),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_createdAgent != null) ...[
            const Icon(Icons.check_circle_rounded, color: AppTheme.olive, size: 22),
            const SizedBox(height: 8),
            PixelCharacterWidget(
              characterType: _createdAgent!.characterType,
              rarity: _createdAgent!.rarity,
              subclass: _createdAgent!.subclass,
              size: 120, showName: true, showRarity: true,
              agentId: _createdAgent!.id,
              generatedImage: _createdAgent!.generatedImage,
            ),
            const SizedBox(height: 10),
            const Text('Agent Created!',
              style: TextStyle(color: AppTheme.olive, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Redirecting to detail page…',
              style: TextStyle(color: AppTheme.textM, fontSize: 10)),
          ] else ...[
            const Text('PREVIEW',
              style: TextStyle(color: AppTheme.textM, fontSize: 11, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            const Text('AI will generate a unique\ncharacter after submission',
              style: TextStyle(color: AppTheme.textM, fontSize: 10, height: 1.4),
              textAlign: TextAlign.center),
            const SizedBox(height: 14),
            PixelCharacterWidget(
              characterType: _preview,
              rarity: CharacterRarity.common,
              size: 120, showName: true, showRarity: true),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_preview.description,
                style: const TextStyle(color: AppTheme.textM, fontSize: 11, height: 1.5),
                textAlign: TextAlign.center)),
            if (_loading) ...[
              const SizedBox(height: 20),
              const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_loadingMsg,
                  style: const TextStyle(color: AppTheme.primary, fontSize: 11),
                  textAlign: TextAlign.center)),
            ],
          ],
        ])),
      ),
      // Right form panel
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(36),
        child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppTheme.textH, AppTheme.gold]).createShader(b),
            child: const Text('Create Agent',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
          const SizedBox(height: 4),
          const Text(
            'Describe your AI agent — category, tags and character art will be generated automatically.',
            style: TextStyle(color: AppTheme.textM, fontSize: 13)),
          const SizedBox(height: 24),
          _stepIndicator(),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                child: child)),
            child: KeyedSubtree(key: ValueKey<int>(_step), child: _stepContent()),
          ),
        ])),
      )),
    ]),
  );

  Widget _stepContent() {
    switch (_step) {
      case 0: return _step0Content();
      case 1: return _step1Content();
      case 2: return _step2Content();
      default: return _step0Content();
    }
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool required = false, String? hint, int lines = 1}) =>
    TextFormField(
      controller: ctrl,
      maxLines: lines,
      style: const TextStyle(color: AppTheme.textH),
      validator: required ? (v) => (v == null || v.isEmpty) ? '$label is required' : null : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _promptCtrl.dispose();
    super.dispose();
  }
}
