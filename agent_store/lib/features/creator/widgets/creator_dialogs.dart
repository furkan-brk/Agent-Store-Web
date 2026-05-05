// lib/features/creator/widgets/creator_dialogs.dart
//
// v3.12 (PR 2 / FIX 2) — Stateful Creator Dashboard dialogs.
//
// Pre-fix, _showEditDialog and _showPriceDialog in creator_dashboard_screen.dart
// instantiated TextEditingControllers inline (titleCtrl/descCtrl/tagCtrl;
// priceCtrl) and wrapped them in a StatefulBuilder. StatefulBuilder doesn't
// participate in dispose, so every Save/Cancel cycle leaked the controllers.
//
// These widgets now own and dispose their controllers via initState/dispose.
// Pattern reference: _NewCollectionDialogState / _SetPriceDialogState in
// library_screen.dart.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/pixel_character_widget.dart';

// ── Edit Agent Dialog ────────────────────────────────────────────────────────

/// Stateful edit-agent dialog.
///
/// Owns title/description/tag-input TextEditingControllers and disposes them
/// on tear-down. `onSaved` is invoked after a successful save so the host can
/// refresh the underlying list.
class CreatorEditAgentDialog extends StatefulWidget {
  final AgentModel agent;
  final VoidCallback onSaved;

  const CreatorEditAgentDialog({
    super.key,
    required this.agent,
    required this.onSaved,
  });

  @override
  State<CreatorEditAgentDialog> createState() => _CreatorEditAgentDialogState();
}

class _CreatorEditAgentDialogState extends State<CreatorEditAgentDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _tagCtrl;
  late final List<String> _tags;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.agent.title);
    _descCtrl = TextEditingController(text: widget.agent.description);
    _tagCtrl = TextEditingController();
    _tags = List<String>.from(widget.agent.tags);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.instance.updateAgent(
        widget.agent.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        tags: _tags,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Error: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleLen = _titleCtrl.text.length;
    final descLen = _descCtrl.text.length;
    final titleValid = titleLen >= 3 && titleLen <= 80;
    final descValid = descLen >= 10 && descLen <= 500;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: const Row(children: [
        Icon(Icons.edit_outlined, color: AppTheme.gold, size: 20),
        SizedBox(width: 12),
        Text('Edit Agent',
            style: TextStyle(
                color: AppTheme.textH,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ]),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Title',
                  style: TextStyle(
                      color: AppTheme.textB,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                maxLength: 80,
                style: const TextStyle(color: AppTheme.textH, fontSize: 14),
                decoration: InputDecoration(
                  counterStyle:
                      const TextStyle(color: AppTheme.textM, fontSize: 11),
                  errorText: _titleCtrl.text.isNotEmpty && !titleValid
                      ? 'Title must be 3-80 characters'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Text('Description',
                  style: TextStyle(
                      color: AppTheme.textB,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(color: AppTheme.textH, fontSize: 14),
                decoration: InputDecoration(
                  counterStyle:
                      const TextStyle(color: AppTheme.textM, fontSize: 11),
                  errorText: _descCtrl.text.isNotEmpty && !descValid
                      ? 'Description must be 10-500 characters'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Text('Tags',
                  style: TextStyle(
                      color: AppTheme.textB,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${_tags.length}/10 tags',
                style: const TextStyle(color: AppTheme.textM, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ..._tags.map((tag) => Chip(
                        label: Text(tag,
                            style: const TextStyle(
                                color: AppTheme.textH, fontSize: 12)),
                        backgroundColor: AppTheme.card,
                        deleteIcon: const Icon(Icons.close,
                            size: 14, color: AppTheme.textM),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                        side: const BorderSide(color: AppTheme.border),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )),
                  if (_tags.length < 10)
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _tagCtrl,
                        style: const TextStyle(
                            color: AppTheme.textH, fontSize: 12),
                        maxLength: 30,
                        decoration: const InputDecoration(
                          hintText: 'Add tag + Enter',
                          hintStyle:
                              TextStyle(color: AppTheme.textM, fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 8, horizontal: 8),
                        ),
                        onSubmitted: (value) {
                          final trimmed = value.trim();
                          if (trimmed.isNotEmpty &&
                              _tags.length < 10 &&
                              !_tags.contains(trimmed)) {
                            setState(() {
                              _tags.add(trimmed);
                              _tagCtrl.clear();
                            });
                          }
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              (_isSaving || !titleValid || !descValid) ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.textH),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

// ── Set Price Dialog ─────────────────────────────────────────────────────────

/// Stateful set-price dialog.
///
/// Owns the price TextEditingController and disposes it on tear-down.
/// `onSaved` is invoked after a successful save.
class CreatorSetPriceDialog extends StatefulWidget {
  final AgentModel agent;
  final VoidCallback onSaved;

  const CreatorSetPriceDialog({
    super.key,
    required this.agent,
    required this.onSaved,
  });

  @override
  State<CreatorSetPriceDialog> createState() => _CreatorSetPriceDialogState();
}

class _CreatorSetPriceDialogState extends State<CreatorSetPriceDialog> {
  late final TextEditingController _priceCtrl;
  bool _isSaving = false;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.agent.price > 0
          ? widget.agent.price.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    setState(() => _isSaving = true);
    try {
      final ok =
          await ApiService.instance.setAgentPrice(widget.agent.id, price);
      if (!ok) throw Exception('Failed to update price');
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            price == 0
                ? 'Agent is now free'
                : 'Price set to ${price.toStringAsFixed(2)} MON',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Error: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: const Row(children: [
        Icon(Icons.monetization_on_outlined, color: AppTheme.gold, size: 20),
        SizedBox(width: 12),
        Text('Set Price',
            style: TextStyle(
                color: AppTheme.textH,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                const Icon(Icons.sell_outlined,
                    color: AppTheme.textM, size: 16),
                const SizedBox(width: 8),
                const Text('Current price: ',
                    style: TextStyle(color: AppTheme.textM, fontSize: 13)),
                Text(
                  widget.agent.price == 0
                      ? 'Free'
                      : '${widget.agent.price.toStringAsFixed(2)} MON',
                  style: TextStyle(
                    color: widget.agent.price == 0
                        ? AppTheme.textM
                        : AppTheme.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('New Price',
                style: TextStyle(
                    color: AppTheme.textB,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textH, fontSize: 14),
              decoration: InputDecoration(
                hintText: '0.00',
                suffixText: 'MON',
                suffixStyle: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                errorText: _priceError,
              ),
              onChanged: (val) {
                setState(() {
                  if (val.isEmpty) {
                    _priceError = null;
                    return;
                  }
                  final parsed = double.tryParse(val);
                  if (parsed == null) {
                    _priceError = 'Enter a valid number';
                  } else if (parsed < 0) {
                    _priceError = 'Price cannot be negative';
                  } else {
                    _priceError = null;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Set to 0 or leave empty to make this agent free.',
              style: TextStyle(
                  color: AppTheme.textM.withValues(alpha: 0.8), fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isSaving || _priceError != null) ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.textH),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Regenerate Avatar Dialog ─────────────────────────────────────────────────
//
// No TextEditingControllers but extracting alongside the others for cohesion
// and so the host doesn't keep an inline StatefulBuilder for it. Owns its
// _isRegenerating flag.

class CreatorRegenerateAvatarDialog extends StatefulWidget {
  final AgentModel agent;
  final VoidCallback onSaved;

  const CreatorRegenerateAvatarDialog({
    super.key,
    required this.agent,
    required this.onSaved,
  });

  @override
  State<CreatorRegenerateAvatarDialog> createState() =>
      _CreatorRegenerateAvatarDialogState();
}

class _CreatorRegenerateAvatarDialogState
    extends State<CreatorRegenerateAvatarDialog> {
  bool _isRegenerating = false;

  Future<void> _regenerate() async {
    setState(() => _isRegenerating = true);
    try {
      await ApiService.instance.regenerateImage(widget.agent.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar regenerated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegenerating = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $msg')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: const Row(children: [
        Icon(Icons.auto_fix_high_rounded, color: AppTheme.gold, size: 20),
        SizedBox(width: 12),
        Text('Regenerate Avatar',
            style: TextStyle(
                color: AppTheme.textH,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ]),
      content: SizedBox(
        width: 420,
        child: _isRegenerating
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: AppTheme.gold),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Generating new avatar...',
                    style: TextStyle(
                        color: AppTheme.textH,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This may take 30-60 seconds. Please do not close this dialog.',
                    style: TextStyle(color: AppTheme.textM, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(children: [
                      PixelCharacterWidget(
                        characterType: widget.agent.characterType,
                        rarity: widget.agent.rarity,
                        subclass: widget.agent.subclass,
                        size: 40,
                        agentId: widget.agent.id,
                        generatedImage: widget.agent.generatedImage,
                        imageUrl: widget.agent.imageUrl,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.agent.title,
                          style: const TextStyle(
                              color: AppTheme.textH,
                              fontWeight: FontWeight.w500,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This will create a new pixel-art character image using AI. The current avatar will be replaced.',
                    style: TextStyle(color: AppTheme.textB, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppTheme.gold.withValues(alpha: 0.8),
                              size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'You can regenerate once every 24 hours.',
                              style: TextStyle(
                                  color: AppTheme.textB, fontSize: 12),
                            ),
                          ),
                        ]),
                  ),
                ],
              ),
      ),
      actions: _isRegenerating
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: _regenerate,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: const Text('Regenerate'),
              ),
            ],
    );
  }
}
