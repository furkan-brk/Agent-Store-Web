// lib/features/create_agent/screens/create_agent_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../controllers/create_agent_controller.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/wallet_guard.dart';
import '../../../features/character/character_types.dart';
import '../../../shared/widgets/pixel_character_widget.dart';
import '../../wallet/screens/wallet_connect_screen.dart';

class CreateAgentScreen extends StatefulWidget {
  const CreateAgentScreen({super.key});
  @override
  State<CreateAgentScreen> createState() => _CreateAgentScreenState();
}

class _CreateAgentScreenState extends State<CreateAgentScreen> {
  late final CreateAgentController _ctrl;
  final _form = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();
  final _promptFocus = FocusNode();

  // Track character counts reactively
  final _titleLen = ValueNotifier<int>(0);
  final _descLen = ValueNotifier<int>(0);
  final _promptLen = ValueNotifier<int>(0);
  final _promptLineCount = ValueNotifier<int>(1);

  static const int _titleMaxLen = 80;
  static const int _promptMinLen = 20;

  static const List<String> _stepLabels = ['Basic Info', 'Prompt', 'Review'];
  static const List<IconData> _stepIcons = [
    Icons.info_outline_rounded,
    Icons.code_rounded,
    Icons.preview_rounded,
  ];

  // Breakpoints
  static const double _mobileBreak = 768;
  static const double _formMaxWidth = 640;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<CreateAgentController>()
        ? Get.find<CreateAgentController>()
        : Get.put(CreateAgentController(), permanent: true);
    _ctrl.reset();
    _titleCtrl.clear();
    _descCtrl.clear();
    _promptCtrl.clear();

    _titleCtrl.addListener(() => _titleLen.value = _titleCtrl.text.length);
    _descCtrl.addListener(() => _descLen.value = _descCtrl.text.length);
    _promptCtrl.addListener(() {
      _promptLen.value = _promptCtrl.text.length;
      _promptLineCount.value =
          '\n'.allMatches(_promptCtrl.text).length + 1;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    _promptFocus.dispose();
    _titleLen.dispose();
    _descLen.dispose();
    _promptLen.dispose();
    _promptLineCount.dispose();
    super.dispose();
  }

  // ── Submission ────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!WalletGuard.check(context, actionLabel: 'create an agent')) return;
    if (!_form.currentState!.validate()) return;
    final hasCredits = await _ctrl.checkCredits(context);
    if (!hasCredits) return;
    final agent = await _ctrl.submit(
      _titleCtrl.text,
      _descCtrl.text,
      _promptCtrl.text,
    );
    if (agent != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agent created with unique AI character!'),
          backgroundColor: AppTheme.olive,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) context.go('/agent/${agent.id}');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Creation failed. Try again or check your connection.',
          ),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  void _nextStep() {
    if (_ctrl.step.value == 0) {
      if (_titleCtrl.text.trim().isEmpty) {
        _titleFocus.requestFocus();
        _form.currentState?.validate();
        return;
      }
      _ctrl.step.value = 1;
    } else if (_ctrl.step.value == 1) {
      if (_promptCtrl.text.trim().isEmpty ||
          _promptCtrl.text.trim().length < _promptMinLen) {
        _promptFocus.requestFocus();
        _form.currentState?.validate();
        return;
      }
      _ctrl.detectCharacterType(_promptCtrl.text);
      _ctrl.step.value = 2;
    }
  }

  void _prevStep() {
    if (_ctrl.step.value > 0) _ctrl.step.value--;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!ApiService.instance.isAuthenticated) {
      return const WalletConnectScreen();
    }
    // Use LayoutBuilder outside Obx so it resolves constraints first,
    // then wrap the reactive widget tree inside Obx where .value reads
    // happen directly in the callback body (not deferred to layout phase).
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreak;
        return Obx(() {
          // Reactive reads happen here — directly inside the Obx callback —
          // so GetX properly registers them as dependencies.
          // The build methods below access _ctrl.step.value, .preview.value,
          // .isLoading.value, etc., which triggers Obx rebuilds on change.
          return Scaffold(
            backgroundColor: AppTheme.bg,
            body: isMobile
                ? _buildMobileLayout()
                : _buildDesktopLayout(),
          );
        });
      },
    );
  }

  // ── Desktop: Side-by-side layout ──────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildPreviewPanel(),
        Expanded(child: _buildFormPanel()),
      ],
    );
  }

  // ── Mobile: Stacked layout ────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMobilePreviewStrip(),
          _buildFormPanel(isMobile: true),
        ],
      ),
    );
  }

  // ── Preview panel (desktop sidebar) ───────────────────────────────────────

  Widget _buildPreviewPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth * 0.28).clamp(220.0, 320.0);
    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _ctrl.preview.value.primaryColor.withValues(alpha: 0.10),
            AppTheme.surface,
          ],
        ),
        border: const Border(
          right: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 900 ? 16 : 24,
            vertical: screenWidth < 900 ? 24 : 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Panel header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.card2.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.border.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_rounded,
                        size: 13, color: AppTheme.textM),
                    SizedBox(width: 6),
                    Text(
                      'LIVE PREVIEW',
                      style: TextStyle(
                        color: AppTheme.textM,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_ctrl.createdAgent.value != null) ...[
                // Success state in preview
                _buildPreviewSuccess(),
              ] else ...[
                // Normal preview
                _buildPreviewCharacter(),
                const SizedBox(height: 16),
                _buildPreviewDescription(),
                if (_ctrl.isLoading.value) ...[
                  const SizedBox(height: 24),
                  _buildCreationProgress(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile preview strip (compact) ────────────────────────────────────────

  Widget _buildMobilePreviewStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _ctrl.preview.value.primaryColor.withValues(alpha: 0.08),
            AppTheme.surface,
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          PixelCharacterWidget(
            characterType: _ctrl.preview.value,
            rarity: CharacterRarity.common,
            size: 64,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ctrl.preview.value.displayName,
                  style: TextStyle(
                    color: _ctrl.preview.value.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _ctrl.preview.value.description,
                  style: const TextStyle(
                    color: AppTheme.textM,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSuccess() {
    final agent = _ctrl.createdAgent.value!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.olive.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.olive.withValues(alpha: 0.3),
            ),
          ),
          child: const Column(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppTheme.olive, size: 28),
              SizedBox(height: 8),
              Text(
                'Agent Created!',
                style: TextStyle(
                  color: AppTheme.olive,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PixelCharacterWidget(
          characterType: agent.characterType,
          rarity: agent.rarity,
          subclass: agent.subclass,
          size: 120,
          showName: true,
          showRarity: true,
          agentId: agent.id,
          generatedImage: agent.generatedImage,
          imageUrl: agent.imageUrl,
        ),
        const SizedBox(height: 12),
        const Text(
          'Redirecting to detail page...',
          style: TextStyle(color: AppTheme.textM, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPreviewCharacter() {
    return Column(
      children: [
        PixelCharacterWidget(
          characterType: _ctrl.preview.value,
          rarity: CharacterRarity.common,
          size: 120,
          showName: true,
          showRarity: true,
        ),
        const SizedBox(height: 8),
        Text(
          'Detected: ${_ctrl.preview.value.displayName}',
          style: TextStyle(
            color: _ctrl.preview.value.accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewDescription() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            _ctrl.preview.value.description,
            style: const TextStyle(
              color: AppTheme.textB,
              fontSize: 11,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 10),
          const Text(
            'AI will generate a unique character\nand avatar after submission',
            style: TextStyle(
              color: AppTheme.textM,
              fontSize: 10,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Multi-step creation progress ──────────────────────────────────────────

  Widget _buildCreationProgress() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _ctrl.loadingMsg.value,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Progress steps indicator
          _buildProgressSteps(),
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    final msg = _ctrl.loadingMsg.value.toLowerCase();
    int activeStep = 0;
    if (msg.contains('profile')) {
      activeStep = 1;
    } else if (msg.contains('avatar') || msg.contains('image')) {
      activeStep = 2;
    } else if (msg.contains('almost')) {
      activeStep = 3;
    }

    const steps = ['Analyze', 'Profile', 'Avatar', 'Save'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final isDone = i < activeStep;
        final isActive = i == activeStep;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? AppTheme.olive
                    : isActive
                        ? AppTheme.primary
                        : AppTheme.card2,
                border: Border.all(
                  color: isDone
                      ? AppTheme.olive
                      : isActive
                          ? AppTheme.primary
                          : AppTheme.border,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : AppTheme.textM,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (i < steps.length - 1)
              Container(
                width: 12,
                height: 1.5,
                color: isDone ? AppTheme.olive : AppTheme.border,
              ),
          ],
        );
      }),
    );
  }

  // ── Form panel ────────────────────────────────────────────────────────────

  Widget _buildFormPanel({bool isMobile = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = isMobile ? 16.0 : (screenWidth < 900 ? 24.0 : 48.0);
    final vPad = isMobile ? 24.0 : (screenWidth < 900 ? 28.0 : 40.0);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: vPad,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _formMaxWidth),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                _buildStepIndicator(),
                const SizedBox(height: 32),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_ctrl.step.value),
                    child: _buildStepContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppTheme.textH, AppTheme.gold],
                ).createShader(b),
                child: const Text(
                  'Create Agent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Describe your AI agent — category, tags, and a unique pixel-art character will be generated automatically.',
          style: TextStyle(
            color: AppTheme.textM,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Column(
      children: [
        Row(
          children: List.generate(3, (i) {
            final active = i == _ctrl.step.value;
            final done = i < _ctrl.step.value;
            return Expanded(
              child: Row(
                children: [
                  _StepCircle(
                    index: i,
                    active: active,
                    done: done,
                    icon: _stepIcons[i],
                  ),
                  if (i < 2)
                    Expanded(
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: done
                              ? AppTheme.primary
                              : AppTheme.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(3, (i) {
            final active = i == _ctrl.step.value;
            final done = i < _ctrl.step.value;
            return Expanded(
              child: Text(
                _stepLabels[i],
                textAlign: i == 0
                    ? TextAlign.left
                    : i == 2
                        ? TextAlign.right
                        : TextAlign.center,
                style: TextStyle(
                  color: active
                      ? AppTheme.primary
                      : done
                          ? AppTheme.textB
                          : AppTheme.textM,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Step content router ───────────────────────────────────────────────────

  Widget _buildStepContent() => switch (_ctrl.step.value) {
        1 => _buildStep1(),
        2 => _buildStep2(),
        _ => _buildStep0(),
      };

  // ── Step 0: Basic Info ────────────────────────────────────────────────────

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        _buildSectionLabel(
          icon: Icons.edit_rounded,
          label: 'Basic Information',
          hint: 'Give your agent a name and description',
        ),
        const SizedBox(height: 20),

        // Title field
        _buildFieldLabel('Title', required: true),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleCtrl,
          focusNode: _titleFocus,
          maxLength: _titleMaxLen,
          style: const TextStyle(color: AppTheme.textH, fontSize: 14),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _descFocus.requestFocus(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          decoration: InputDecoration(
            hintText: 'e.g., Code Review Assistant',
            counterText: '',
            prefixIcon: const Icon(Icons.title_rounded, size: 18),
            suffixIcon: ValueListenableBuilder<int>(
              valueListenable: _titleLen,
              builder: (_, len, __) => Padding(
                padding: const EdgeInsets.only(right: 12, top: 14),
                child: Text(
                  '$len/$_titleMaxLen',
                  style: TextStyle(
                    color: len > _titleMaxLen - 10
                        ? AppTheme.primary
                        : AppTheme.textM,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a clear, descriptive name that tells users what your agent does.',
          style: TextStyle(
            color: AppTheme.textM,
            fontSize: 11,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 24),

        // Description field
        _buildFieldLabel('Description'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descCtrl,
          focusNode: _descFocus,
          maxLines: 4,
          minLines: 3,
          style: const TextStyle(color: AppTheme.textH, fontSize: 14),
          decoration: const InputDecoration(
            hintText:
                'Briefly explain what this agent does, who it\'s for, and what makes it unique...',
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: Icon(Icons.description_rounded, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<int>(
          valueListenable: _descLen,
          builder: (_, len, __) => Row(
            children: [
              const Expanded(
                child: Text(
                  'Optional but recommended. A good description helps users find your agent.',
                  style: TextStyle(
                    color: AppTheme.textM,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
              if (len > 0)
                Text(
                  '$len chars',
                  style: const TextStyle(
                    color: AppTheme.textM,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 36),
        _buildNavButtons(showNext: true, showBack: false, showSubmit: false),
      ],
    );
  }

  // ── Step 1: Prompt ────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          icon: Icons.terminal_rounded,
          label: 'Agent Prompt',
          hint: 'This is the core instruction your agent follows',
        ),
        const SizedBox(height: 20),

        _buildFieldLabel('System Prompt', required: true),
        const SizedBox(height: 8),
        TextFormField(
          controller: _promptCtrl,
          focusNode: _promptFocus,
          maxLines: 14,
          minLines: 8,
          style: const TextStyle(
            color: AppTheme.textH,
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.6,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Prompt is required';
            if (v.trim().length < _promptMinLen) {
              return 'Prompt must be at least $_promptMinLen characters';
            }
            return null;
          },
          decoration: const InputDecoration(
            hintText:
                'You are a helpful assistant that specializes in...\n\n'
                'Your role is to...\n'
                'When the user asks about...',
            hintMaxLines: 6,
            alignLabelWithHint: true,
            contentPadding: EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _promptLen,
          builder: (_, len, __) => ValueListenableBuilder<int>(
            valueListenable: _promptLineCount,
            builder: (_, lines, __) => Row(
              children: [
                // Prompt quality indicator
                if (len > 0) ...[
                  _PromptQualityBadge(charCount: len),
                  const SizedBox(width: 12),
                ],
                const Expanded(
                  child: Text(
                    'The more detailed your prompt, the better the AI character will match.',
                    style: TextStyle(
                      color: AppTheme.textM,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                Text(
                  '$len chars  |  $lines ${lines == 1 ? 'line' : 'lines'}',
                  style: TextStyle(
                    color: len < _promptMinLen
                        ? AppTheme.primary
                        : AppTheme.textM,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Prompt tips card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.gold.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: AppTheme.gold.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tips for a great prompt',
                    style: TextStyle(
                      color: AppTheme.gold.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _tipRow('Define a clear role (e.g., "You are a senior code reviewer...")'),
              _tipRow('Specify the domain or expertise area'),
              _tipRow('Include behavioral guidelines and tone'),
              _tipRow('Add examples of expected input/output'),
            ],
          ),
        ),

        const SizedBox(height: 36),
        _buildNavButtons(showNext: true, showBack: true, showSubmit: false),
      ],
    );
  }

  Widget _tipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.arrow_right_rounded,
                size: 14, color: AppTheme.textM),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textB,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Review ────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          icon: Icons.fact_check_outlined,
          label: 'Review & Create',
          hint: 'Review your agent details before submitting',
        ),
        const SizedBox(height: 24),

        // Character preview card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _ctrl.preview.value.primaryColor.withValues(alpha: 0.08),
                AppTheme.card,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              PixelCharacterWidget(
                characterType: _ctrl.preview.value,
                rarity: CharacterRarity.common,
                size: 140,
                showName: true,
                showRarity: true,
              ),
              const SizedBox(height: 12),
              Text(
                _ctrl.preview.value.description,
                style: const TextStyle(
                  color: AppTheme.textB,
                  fontSize: 12,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.2),
                  ),
                ),
                child: const Text(
                  'AI will generate unique avatar and traits after submission',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.summarize_rounded,
                      size: 15, color: AppTheme.gold),
                  SizedBox(width: 8),
                  Text(
                    'Summary',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 14),
              _buildSummaryRow(
                icon: Icons.title_rounded,
                label: 'Title',
                value: _titleCtrl.text.isEmpty ? '--' : _titleCtrl.text,
              ),
              if (_descCtrl.text.isNotEmpty)
                _buildSummaryRow(
                  icon: Icons.description_outlined,
                  label: 'Description',
                  value: _descCtrl.text,
                ),
              _buildSummaryRow(
                icon: Icons.code_rounded,
                label: 'Prompt',
                value: '${_promptCtrl.text.length} characters',
              ),
              _buildSummaryRow(
                icon: Icons.category_outlined,
                label: 'Detected type',
                value: _ctrl.preview.value.displayName,
                valueColor: _ctrl.preview.value.primaryColor,
              ),
              const SizedBox(height: 8),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 14),
              _buildCostRow(),
            ],
          ),
        ),

        const SizedBox(height: 36),
        _buildNavButtons(showNext: false, showBack: true, showSubmit: true),
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.textM),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textM,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppTheme.textH,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow() {
    final remaining = _ctrl.credits.value - 10;
    return Row(
      children: [
        // Cost
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded,
                    size: 16,
                    color: AppTheme.gold.withValues(alpha: 0.9)),
                const SizedBox(width: 4),
                const Text(
                  '10 credits',
                  style: TextStyle(
                    color: AppTheme.textH,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Balance after
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: remaining >= 10
                  ? AppTheme.olive.withValues(alpha: 0.08)
                  : AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: remaining >= 10
                    ? AppTheme.olive.withValues(alpha: 0.2)
                    : AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 14,
                  color: remaining >= 10 ? AppTheme.olive : AppTheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$remaining after',
                  style: TextStyle(
                    color: remaining >= 10 ? AppTheme.textB : AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared UI components ──────────────────────────────────────────────────

  Widget _buildSectionLabel({
    required IconData icon,
    required String label,
    required String hint,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textH,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: const TextStyle(
                    color: AppTheme.textM,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textB,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  // ── Navigation buttons ────────────────────────────────────────────────────

  Widget _buildNavButtons({
    required bool showNext,
    required bool showBack,
    required bool showSubmit,
  }) {
    return Row(
      children: [
        if (showBack) ...[
          _HoverButton(
            onPressed: _prevStep,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded,
                      size: 16, color: AppTheme.textB),
                  SizedBox(width: 8),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: AppTheme.textB,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (showNext)
          Expanded(
            child: _HoverButton(
              onPressed: _nextStep,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        size: 16, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        if (showSubmit)
          Expanded(
            child: _HoverButton(
              onPressed: _ctrl.isLoading.value ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: _ctrl.isLoading.value
                      ? LinearGradient(
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.5),
                            const Color(0xFF8B1A11).withValues(alpha: 0.5),
                          ],
                        )
                      : const LinearGradient(
                          colors: [AppTheme.primary, Color(0xFF8B1A11)],
                        ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _ctrl.isLoading.value
                      ? null
                      : [
                          BoxShadow(
                            color:
                                AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: _ctrl.isLoading.value
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _ctrl.loadingMsg.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'Create Agent',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded,
                                    size: 12,
                                    color: AppTheme.gold
                                        .withValues(alpha: 0.9)),
                                const SizedBox(width: 2),
                                const Text(
                                  '10',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

/// Step circle with icon for active state, checkmark for done, number for pending.
class _StepCircle extends StatelessWidget {
  final int index;
  final bool active;
  final bool done;
  final IconData icon;

  const _StepCircle({
    required this.index,
    required this.active,
    required this.done,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppTheme.primary
            : active
                ? AppTheme.primary.withValues(alpha: 0.15)
                : AppTheme.card2,
        border: Border.all(
          color: (done || active) ? AppTheme.primary : AppTheme.border,
          width: active ? 2 : 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : active
                ? Icon(icon, size: 15, color: AppTheme.primary)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppTheme.textM,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
      ),
    );
  }
}

/// Prompt quality indicator based on character count.
class _PromptQualityBadge extends StatelessWidget {
  final int charCount;
  const _PromptQualityBadge({required this.charCount});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final IconData icon;

    if (charCount < 20) {
      label = 'Too short';
      color = AppTheme.primary;
      icon = Icons.warning_amber_rounded;
    } else if (charCount < 100) {
      label = 'Basic';
      color = AppTheme.gold;
      icon = Icons.info_outline_rounded;
    } else if (charCount < 300) {
      label = 'Good';
      color = AppTheme.olive;
      icon = Icons.check_circle_outline_rounded;
    } else {
      label = 'Detailed';
      color = AppTheme.olive;
      icon = Icons.star_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hover-aware button wrapper for Web hover states.
class _HoverButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const _HoverButton({required this.onPressed, required this.child});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.onPressed == null
              ? 0.5
              : _hovering
                  ? 0.85
                  : 1.0,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: _hovering && widget.onPressed != null ? 1.02 : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
