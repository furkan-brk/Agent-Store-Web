import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme.dart';
import '../../../character/character_types.dart';

/// Single-line text input. Pushes its value up via [onChanged] on every
/// keystroke — the controller debounces saves on its end so we don't
/// debounce twice.
class EditTextField extends StatefulWidget {
  const EditTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.helper,
    this.maxLength,
    this.minLength,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? helper;
  final int? maxLength;
  final int? minLength;

  @override
  State<EditTextField> createState() => _EditTextFieldState();
}

class _EditTextFieldState extends State<EditTextField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant EditTextField old) {
    super.didUpdateWidget(old);
    // Resync only if controller's text drifted from the props (e.g. undo/redo).
    if (widget.value != _ctrl.text) {
      final selOk = _ctrl.selection.baseOffset <= widget.value.length;
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: selOk ? _ctrl.selection : TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooShort = widget.minLength != null && widget.value.length < widget.minLength!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(widget.label),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          onChanged: widget.onChanged,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            counterText: widget.maxLength == null ? '' : null,
          ),
        ),
        if (tooShort)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Minimum ${widget.minLength} characters',
              style: const TextStyle(color: AppTheme.warning, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

/// Multi-line text area with optional character counter.
class EditLongText extends StatefulWidget {
  const EditLongText({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.minLines = 3,
    this.maxLines = 8,
    this.maxLength,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int minLines;
  final int maxLines;
  final int? maxLength;

  @override
  State<EditLongText> createState() => _EditLongTextState();
}

class _EditLongTextState extends State<EditLongText> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant EditLongText old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) {
      final selOk = _ctrl.selection.baseOffset <= widget.value.length;
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: selOk ? _ctrl.selection : TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(widget.label),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          onChanged: widget.onChanged,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hint,
            counterStyle: const TextStyle(color: AppTheme.textM, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Tag/trait chip editor. Press Enter (or tap the +) to add. Tap a chip
/// to remove. [maxItems] caps the list — additions past the cap are ignored.
class EditTagChips extends StatefulWidget {
  const EditTagChips({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.maxItems = 10,
    this.maxItemLength = 30,
    this.hint,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final int maxItems;
  final int maxItemLength;
  final String? hint;

  @override
  State<EditTagChips> createState() => _EditTagChipsState();
}

class _EditTagChipsState extends State<EditTagChips> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  void _add() {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    if (widget.values.length >= widget.maxItems) return;
    final clean = raw.length > widget.maxItemLength ? raw.substring(0, widget.maxItemLength) : raw;
    if (widget.values.contains(clean)) {
      _ctrl.clear();
      return;
    }
    widget.onChanged([...widget.values, clean]);
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _remove(String tag) {
    widget.onChanged(widget.values.where((t) => t != tag).toList(growable: false));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atCap = widget.values.length >= widget.maxItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _FieldLabel(widget.label),
            const Spacer(),
            Text(
              '${widget.values.length}/${widget.maxItems}',
              style: const TextStyle(color: AppTheme.textM, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (widget.values.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.values
                .map((t) => InputChip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => _remove(t),
                      backgroundColor: AppTheme.card2,
                      deleteIconColor: AppTheme.textM,
                      side: const BorderSide(color: AppTheme.border),
                    ))
                .toList(growable: false),
          ),
        if (widget.values.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                enabled: !atCap,
                onSubmitted: (_) => _add(),
                inputFormatters: [LengthLimitingTextInputFormatter(widget.maxItemLength)],
                decoration: InputDecoration(
                  hintText: atCap ? 'Maximum reached' : (widget.hint ?? 'Add and press Enter'),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: atCap ? null : _add,
              icon: const Icon(Icons.add, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.textH,
                disabledBackgroundColor: AppTheme.card2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Subclass swatch picker — shows the 3 subclasses for the agent's current
/// CharacterType. Selecting one dispatches [onChanged].
class EditSubclassPicker extends StatelessWidget {
  const EditSubclassPicker({
    super.key,
    required this.type,
    required this.value,
    required this.onChanged,
  });

  final CharacterType type;
  final CharacterSubclass value;
  final ValueChanged<CharacterSubclass> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = type.subclasses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Subclass'),
        const SizedBox(height: 6),
        Row(
          children: options.map((s) {
            final selected = s == value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: s == options.last ? 0 : 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onChanged(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? type.primaryColor.withValues(alpha: 0.18) : AppTheme.card2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? type.accentColor : AppTheme.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.displayName,
                          style: TextStyle(
                            color: selected ? AppTheme.textH : AppTheme.textB,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.itemDescription,
                          style: const TextStyle(color: AppTheme.textM, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  // Tiny helper so every field has the same caption styling.
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textB,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}
