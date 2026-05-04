// lib/shared/widgets/monaco_editor_widget.dart
//
// Flutter HtmlElementView wrapper around the Monaco Editor JS bridge.
// Works only on Flutter Web (dart:ui_web + package:web).
// Communicates with web/monaco_bridge.js via dart:js_interop.

import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

// ── JS interop declarations ───────────────────────────────────────────────────

@JS('monacoApi.init')
external void _jsInit(
  JSString containerId,
  JSString instanceId,
  JSFunction onChange,
  JSFunction onTrigger,
  JSFunction onMentionKey,
  JSFunction onSubmit,
  JSBoolean submitOnEnter,
  JSBoolean readOnly,
);

@JS('monacoApi.getValue')
external JSString _jsGetValue(JSString id);

@JS('monacoApi.clear')
external void _jsClear(JSString id);

@JS('monacoApi.insertMention')
external void _jsInsertMention(JSString id, JSString displayText, JSBoolean isAgent);

@JS('monacoApi.setMentionsVisible')
external void _jsSetMentionsVisible(JSString id, JSBoolean visible);

@JS('monacoApi.focus')
external void _jsFocus(JSString id);

@JS('monacoApi.layout')
external void _jsLayout(JSString id);

@JS('monacoApi.setValue')
external void _jsSetValue(JSString id, JSString val);

@JS('monacoApi.dispose')
external void _jsDispose(JSString id);

// ── Widget ────────────────────────────────────────────────────────────────────

class MonacoEditorWidget extends StatefulWidget {
  final double height;

  /// If true, pressing Enter submits the text (calls [onSubmit]) and clears
  /// the editor. Shift+Enter always inserts a newline regardless.
  final bool submitOnEnter;

  final ValueChanged<String>? onChange;

  /// Called when the user types `@` or `#` followed by a query.
  /// [trigger] is `'@'` or `'#'`; empty string means no active trigger.
  final void Function(String trigger, String query)? onTrigger;

  /// Called when a mention-navigation key is pressed while the dropdown is
  /// visible: `'up'`, `'down'`, `'enter'`, `'escape'`.
  final void Function(String key)? onMentionKey;

  /// Called when the editor content is submitted (Enter in submit mode).
  final ValueChanged<String>? onSubmit;

  /// If true, the editor is rendered in read-only mode (no edits possible).
  /// Useful for preview / output panels. Defaults to `false`.
  final bool readOnly;

  /// Optional initial text to seed the editor with after mount.
  final String? initialValue;

  const MonacoEditorWidget({
    super.key,
    this.height = 80,
    this.submitOnEnter = false,
    this.onChange,
    this.onTrigger,
    this.onMentionKey,
    this.onSubmit,
    this.readOnly = false,
    this.initialValue,
  });

  @override
  State<MonacoEditorWidget> createState() => MonacoEditorWidgetState();
}

class MonacoEditorWidgetState extends State<MonacoEditorWidget> {
  static int _counter = 0;
  static final _registered = <String>{};

  late final String _instanceId;
  late final String _viewType;
  late final web.HTMLDivElement _container;

  @override
  void initState() {
    super.initState();
    _instanceId = 'gm-monaco-${++_counter}';
    _viewType = 'monaco-view-$_instanceId';

    _container = web.document.createElement('div') as web.HTMLDivElement;
    _container.id = 'mc-$_instanceId';
    _container.style.width = '100%';
    _container.style.height = '100%';
    _container.style.background = '#1A1710';

    if (!_registered.contains(_viewType)) {
      _registered.add(_viewType);
      ui.platformViewRegistry.registerViewFactory(
        _viewType,
        (_) => _container,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _initMonaco());
  }

  void _initMonaco() {
    final onChangeCb =
        ((JSString v) => widget.onChange?.call(v.toDart)).toJS;
    final onTriggerCb =
        ((JSString t, JSString q) => widget.onTrigger?.call(t.toDart, q.toDart))
            .toJS;
    final onMentionKeyCb =
        ((JSString k) => widget.onMentionKey?.call(k.toDart)).toJS;
    final onSubmitCb =
        ((JSString v) => widget.onSubmit?.call(v.toDart)).toJS;

    _jsInit(
      ('mc-$_instanceId').toJS,
      _instanceId.toJS,
      onChangeCb,
      onTriggerCb,
      onMentionKeyCb,
      onSubmitCb,
      widget.submitOnEnter.toJS,
      widget.readOnly.toJS,
    );

    // Seed initial value once the JS editor is actually created. The JS side
    // polls for a laid-out container, so we retry a few times before giving up.
    final seed = widget.initialValue;
    if (seed != null && seed.isNotEmpty) {
      _applyInitialValue(seed, attempts: 0);
    }
  }

  void _applyInitialValue(String value, {required int attempts}) {
    if (!mounted) return;
    if (attempts > 30) return;
    // Ask JS: was the initial value applied? setValue is a no-op if the
    // editor isn't registered yet — we verify via getValue.
    _jsSetValue(_instanceId.toJS, value.toJS);
    final current = _jsGetValue(_instanceId.toJS).toDart;
    if (current == value) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      _applyInitialValue(value, attempts: attempts + 1);
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  String getValue() => _jsGetValue(_instanceId.toJS).toDart;

  void setValue(String text) => _jsSetValue(_instanceId.toJS, text.toJS);

  void clear() => _jsClear(_instanceId.toJS);

  void insertMention(String displayText, {required bool isAgent}) =>
      _jsInsertMention(_instanceId.toJS, displayText.toJS, isAgent.toJS);

  void setMentionsVisible(bool visible) =>
      _jsSetMentionsVisible(_instanceId.toJS, visible.toJS);

  void focus() => _jsFocus(_instanceId.toJS);

  void relayout() => _jsLayout(_instanceId.toJS);

  @override
  void dispose() {
    _jsDispose(_instanceId.toJS);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
