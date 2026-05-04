// Monaco Editor Bridge — Guild Master
// Initialised once per page. Provides window.monacoApi for Dart to call.
(function () {
  'use strict';
  if (window.monacoApi) return;

  const _eds = {}; // editorInstanceId → state

  // ── Decoration helpers ────────────────────────────────────────────────────

  function _applyDecorations(state) {
    const model = state.editor.getModel();
    if (!model) return;
    const decs = state.mentions.map(function (m) {
      const sp = model.getPositionAt(m.s);
      const ep = model.getPositionAt(m.e);
      return {
        range: new monaco.Range(sp.lineNumber, sp.column, ep.lineNumber, ep.column),
        options: {
          inlineClassName: m.a ? 'gm-agent-mention' : 'gm-mission-mention',
          stickiness: monaco.editor.TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
        },
      };
    });
    state.decorations = state.editor.deltaDecorations(state.decorations, decs);
  }

  function _shiftMentions(state, changes) {
    for (const ch of changes) {
      const cs = ch.rangeOffset;
      const removed = ch.rangeLength;
      const added = ch.text.length;
      const delta = added - removed;
      const toRemove = [];
      for (let i = 0; i < state.mentions.length; i++) {
        const m = state.mentions[i];
        // change overlaps mention → invalidate
        if (cs < m.e && cs + removed > m.s) { toRemove.push(i); continue; }
        if (m.s >= cs + removed) { m.s += delta; m.e += delta; }
      }
      for (let i = toRemove.length - 1; i >= 0; i--) state.mentions.splice(toRemove[i], 1);
    }
  }

  function _detectTrigger(state) {
    const pos = state.editor.getPosition();
    if (!pos) { state.onTrigger('', ''); return; }
    const model = state.editor.getModel();
    if (!model) return;
    const offset = model.getOffsetAt(pos);
    const prefix = model.getValue().substring(0, offset);
    const ai = prefix.lastIndexOf('@');
    const hi = prefix.lastIndexOf('#');
    const best = ai > hi ? ai : hi;
    const trig = ai > hi ? '@' : '#';
    if (best < 0) { state.onTrigger('', ''); return; }
    if (best > 0 && !/\s/.test(prefix[best - 1])) { state.onTrigger('', ''); return; }
    const q = prefix.substring(best + 1);
    if (/\s/.test(q)) { state.onTrigger('', ''); return; }
    state.onTrigger(trig, q);
  }

  // ── Core init ─────────────────────────────────────────────────────────────

  function _initEditor(containerId, instanceId, onChange, onTrigger, onMentionKey, onSubmit, submitOnEnter, readOnly) {
    require(['vs/editor/editor.main'], function () {
      var _retries = 0;
      const tryInit = function () {
        if (_retries++ > 20) {
          console.warn('Monaco: container "' + containerId + '" never rendered — giving up.');
          return;
        }
        const container = document.getElementById(containerId);
        if (!container || container.clientWidth === 0 || container.clientHeight === 0) {
          setTimeout(tryInit, 60);
          return;
        }

        if (!monaco.editor.getTheme || !monaco.editor._themeService) {
          // defineTheme is safe to call multiple times with same name
        }
        monaco.editor.defineTheme('gm-dark', {
          base: 'vs-dark',
          inherit: true,
          rules: [],
          colors: {
            'editor.background': '#1A1710',
            'editor.foreground': '#E8DCC8',
            'editor.lineHighlightBackground': '#1A1710',
            'editor.selectionBackground': '#C1392B40',
            'editorCursor.foreground': '#C1392B',
            'editor.inactiveSelectionBackground': '#1A1710',
            'scrollbarSlider.background': '#3D3020AA',
            'scrollbarSlider.hoverBackground': '#5A4A30',
          },
        });

        const isReadOnly = !!readOnly;
        const editor = monaco.editor.create(container, {
          value: '',
          language: 'plaintext',
          theme: 'gm-dark',
          minimap: { enabled: false },
          scrollBeyondLastLine: false,
          wordWrap: 'on',
          lineNumbers: 'off',
          glyphMargin: false,
          folding: false,
          lineDecorationsWidth: 0,
          lineNumbersMinChars: 0,
          renderLineHighlight: 'none',
          overviewRulerBorder: false,
          overviewRulerLanes: 0,
          hideCursorInOverviewRuler: true,
          scrollbar: { vertical: 'auto', horizontal: 'hidden', verticalScrollbarSize: 5 },
          fontSize: 14,
          fontFamily: '"Inter", ui-sans-serif, system-ui, sans-serif',
          padding: { top: 10, bottom: 10 },
          contextmenu: false,
          automaticLayout: true,
          suggest: { showWords: false, showSnippets: false },
          quickSuggestions: false,
          acceptSuggestionOnEnter: 'off',
          tabCompletion: 'off',
          wordBasedSuggestions: 'off',
          readOnly: isReadOnly,
          cursorStyle: 'line',
          domReadOnly: isReadOnly,
        });

        const state = {
          editor,
          mentions: [],
          decorations: [],
          mentionsVisible: false,
          submitOnEnter: !!submitOnEnter,
          readOnly: isReadOnly,
          onChange,
          onTrigger,
          onMentionKey,
          onSubmit,
        };
        _eds[instanceId] = state;

        // Content change
        editor.onDidChangeModelContent(function (e) {
          _shiftMentions(state, e.changes);
          _applyDecorations(state);
          state.onChange(editor.getValue());
          _detectTrigger(state);
        });

        // Key handler — overrides backspace / mention nav / submit
        editor.onKeyDown(function (e) {
          const kb = e.keyCode;
          const pos = editor.getPosition();
          if (!pos) return;
          const model = editor.getModel();
          if (!model) return;
          const offset = model.getOffsetAt(pos);

          // Atomic backspace: delete entire mention if cursor is at its end
          if (kb === monaco.KeyCode.Backspace && !e.shiftKey && !e.ctrlKey && !e.altKey && !e.metaKey) {
            for (const m of state.mentions) {
              if (offset === m.e) {
                e.preventDefault();
                const sp = model.getPositionAt(m.s);
                editor.executeEdits('del-mention', [{
                  range: new monaco.Range(sp.lineNumber, sp.column, pos.lineNumber, pos.column),
                  text: '',
                }]);
                return;
              }
            }
          }

          // Atomic forward-delete: delete entire mention if cursor is at its start
          if (kb === monaco.KeyCode.Delete && !e.shiftKey && !e.ctrlKey && !e.altKey && !e.metaKey) {
            for (const m of state.mentions) {
              if (offset === m.s) {
                e.preventDefault();
                const ep = model.getPositionAt(m.e);
                editor.executeEdits('del-mention-fwd', [{
                  range: new monaco.Range(pos.lineNumber, pos.column, ep.lineNumber, ep.column),
                  text: '',
                }]);
                return;
              }
            }
          }

          // Mention dropdown key navigation
          if (state.mentionsVisible) {
            if (kb === monaco.KeyCode.UpArrow) {
              e.preventDefault(); state.onMentionKey('up'); return;
            }
            if (kb === monaco.KeyCode.DownArrow) {
              e.preventDefault(); state.onMentionKey('down'); return;
            }
            if (kb === monaco.KeyCode.Escape) {
              e.preventDefault(); state.onMentionKey('escape'); return;
            }
            if (kb === monaco.KeyCode.Enter && !e.shiftKey) {
              e.preventDefault(); state.onMentionKey('enter'); return;
            }
          }

          // Submit on Enter (chat input mode)
          if (kb === monaco.KeyCode.Enter && !e.shiftKey && state.submitOnEnter) {
            e.preventDefault();
            const val = editor.getValue().trim();
            if (val) {
              state.onSubmit(val);
              editor.setValue('');
              state.mentions.length = 0;
              _applyDecorations(state);
            }
          }
        });

        // Mention CSS (injected once)
        if (!document.getElementById('gm-mention-css')) {
          const s = document.createElement('style');
          s.id = 'gm-mention-css';
          s.textContent =
            '.gm-agent-mention{background:rgba(193,57,43,.2);border-radius:3px;color:#E8896B!important;font-weight:600;}' +
            '.gm-mission-mention{background:rgba(212,168,67,.2);border-radius:3px;color:#D4A843!important;font-weight:600;}' +
            '.monaco-editor .view-lines{padding-left:10px!important;}';
          document.head.appendChild(s);
        }
      };
      tryInit();
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  window.monacoApi = {

    init: _initEditor,

    getValue: function (id) {
      return _eds[id] ? _eds[id].editor.getValue() : '';
    },

    clear: function (id) {
      const s = _eds[id];
      if (!s) return;
      s.editor.setValue('');
      s.mentions.length = 0;
      s.decorations = s.editor.deltaDecorations(s.decorations, []);
    },

    insertMention: function (id, displayText, isAgent) {
      const s = _eds[id];
      if (!s) return;
      const editor = s.editor;
      const model = editor.getModel();
      if (!model) return;
      const pos = editor.getPosition();
      if (!pos) return;
      const offset = model.getOffsetAt(pos);
      const prefix = model.getValue().substring(0, offset);
      const trig = isAgent ? '@' : '#';
      const ti = prefix.lastIndexOf(trig);
      if (ti < 0) return;
      const sp = model.getPositionAt(ti);
      const mentionText = displayText + ' ';
      editor.executeEdits('insert-mention', [{
        range: new monaco.Range(sp.lineNumber, sp.column, pos.lineNumber, pos.column),
        text: mentionText,
      }]);
      s.mentions.push({ s: ti, e: ti + mentionText.length, a: !!isAgent });
      _applyDecorations(s);
      const newPos = editor.getModel().getPositionAt(ti + mentionText.length);
      editor.setPosition(newPos);
      editor.focus();
    },

    setMentionsVisible: function (id, visible) {
      if (_eds[id]) _eds[id].mentionsVisible = !!visible;
    },

    focus: function (id) { if (_eds[id]) _eds[id].editor.focus(); },

    layout: function (id) { if (_eds[id]) _eds[id].editor.layout(); },

    setValue: function (id, val) {
      if (_eds[id]) _eds[id].editor.setValue(val);
    },

    dispose: function (id) {
      if (_eds[id]) { _eds[id].editor.dispose(); delete _eds[id]; }
    },
  };

})();
