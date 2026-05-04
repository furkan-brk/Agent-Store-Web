import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/conflict_resolver.dart';
import '../../character/character_types.dart';

/// Sync status states surfaced in the toolbar badge (mirrors v3.2 Mission/Legend pattern).
/// `conflict` indicates the server returned 409 — the screen layer should open
/// [showConflictDialog] (v3.7-4.2) and call [resolveConflictWith*] based on
/// the user's choice.
enum SyncStatus { idle, dirty, saving, saved, error, conflict }

/// Reactive controller backing the Card Editor screen.
///
/// Holds two AgentModel snapshots: [_original] (last server-confirmed state)
/// and [draft] (live edits). Each [updateField] call snapshots the current
/// draft into [_history] and schedules a debounced PATCH to the backend.
///
/// Undo/redo walk [_history] in v3.3 Legend style.
class CardEditorController extends GetxController {
  CardEditorController({required AgentModel initial})
      : _original = initial,
        draft = Rx<AgentModel>(initial),
        _history = <AgentModel>[initial],
        _historyIndex = 0;

  // ── Public reactive state ───────────────────────────────────────────────
  final Rx<AgentModel> draft;
  final syncStatus = Rx<SyncStatus>(SyncStatus.idle);
  final lastError = RxnString();
  final isRegeneratingImage = false.obs;

  // ── Private state ───────────────────────────────────────────────────────
  AgentModel _original;
  final List<AgentModel> _history;
  int _historyIndex;
  Timer? _debounce;

  static const _historyLimit = 50;
  static const _debounceMs = 600;

  // ── Conflict state ──────────────────────────────────────────────────────
  /// When the last save returned 409, holds the server's current row so the
  /// screen layer can render diffs / take-theirs without re-fetching. Null
  /// when no conflict is pending.
  AgentModel? _conflictServer;
  AgentModel? get conflictServer => _conflictServer;
  bool get hasPendingConflict => _conflictServer != null;

  // ── Selectors ────────────────────────────────────────────────────────────
  bool get isDirty => !_isSameContent(draft.value, _original);
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  AgentModel get original => _original;

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  // ── Field updates ────────────────────────────────────────────────────────

  /// Apply [mutation] to the current draft, push to history, and schedule
  /// a debounced backend save. Snapshots are coalesced — repeated typing
  /// inside the debounce window only produces one history entry.
  void updateField(AgentModel Function(AgentModel) mutation) {
    final next = mutation(draft.value);
    if (_isSameContent(draft.value, next)) return;
    draft.value = next;
    _pushHistory(next);
    syncStatus.value = SyncStatus.dirty;
    _scheduleSave();
  }

  void _pushHistory(AgentModel snapshot) {
    // Drop any redo tail before appending.
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(snapshot);
    if (_history.length > _historyLimit) {
      _history.removeAt(0);
    }
    _historyIndex = _history.length - 1;
  }

  void undo() {
    if (!canUndo) return;
    _historyIndex--;
    draft.value = _history[_historyIndex];
    syncStatus.value = SyncStatus.dirty;
    _scheduleSave();
  }

  void redo() {
    if (!canRedo) return;
    _historyIndex++;
    draft.value = _history[_historyIndex];
    syncStatus.value = SyncStatus.dirty;
    _scheduleSave();
  }

  // ── Save flow ────────────────────────────────────────────────────────────

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), forceSyncToBackend);
  }

  /// Push the current draft to the backend immediately. Used by Ctrl+S
  /// and by the unsaved-changes guard on close.
  Future<void> forceSyncToBackend() async {
    _debounce?.cancel();
    if (!isDirty) {
      syncStatus.value = SyncStatus.saved;
      return;
    }
    final pending = draft.value;
    syncStatus.value = SyncStatus.saving;
    lastError.value = null;
    try {
      final result = await ApiService.instance.retry(() => ApiService.instance.updateAgent(
            pending.id,
            title: pending.title,
            description: pending.description,
            prompt: pending.prompt,
            category: pending.category,
            subclass: pending.subclass.name,
            tags: pending.tags,
            price: pending.price,
            cardVersion: pending.cardVersion,
            serviceDescription: pending.serviceDescription,
            profileMood: pending.profileMood,
            profileRolePurpose: pending.profileRolePurpose,
            traits: pending.traits,
            // v3.7-4.2: send last server-confirmed revision so the backend
            // can reject (409) when somebody else edited the row first.
            ifMatch: pending.revisionId,
          ));
      if (result == null) {
        syncStatus.value = SyncStatus.saved; // empty body — nothing to do
        _original = pending;
        return;
      }
      // Backend echoes the merged record. Re-parse to absorb any server-side
      // normalisation (trimmed whitespace, sorted tags, etc.).
      final fresh = AgentModel.fromJson(result);
      _original = fresh;
      _conflictServer = null;
      // Only reset the draft if the user hasn't typed something newer.
      // The new revisionId still needs to land in the draft so the next
      // save sends the right If-Match header.
      if (_isSameContent(draft.value, pending)) {
        draft.value = fresh;
      } else {
        draft.value = draft.value.copyWith(revisionId: fresh.revisionId);
      }
      syncStatus.value = SyncStatus.saved;
    } on ConflictException catch (e) {
      // Server's stored revision was newer than ours — store its row so
      // the screen can diff. Mark draft.revisionId with the new server
      // value so a subsequent "keep mine" save passes the If-Match check.
      try {
        _conflictServer = AgentModel.fromJson(e.latestServerJson);
      } catch (_) {
        _conflictServer = null;
      }
      if (_conflictServer != null) {
        draft.value = draft.value.copyWith(revisionId: _conflictServer!.revisionId);
      }
      syncStatus.value = SyncStatus.conflict;
      lastError.value = 'This card was edited elsewhere.';
    } catch (e) {
      debugPrint('[CardEditorController] save failed: $e');
      syncStatus.value = SyncStatus.error;
      lastError.value = e.toString();
    }
  }

  /// Conflict resolution: discard local edits and accept the server's row.
  /// Called from the screen layer after [showConflictDialog] returns
  /// `ConflictResolution.takeTheirs`.
  void resolveConflictWithTheirs() {
    final theirs = _conflictServer;
    if (theirs == null) return;
    _original = theirs;
    draft.value = theirs;
    _pushHistory(theirs);
    _conflictServer = null;
    syncStatus.value = SyncStatus.saved;
  }

  /// Conflict resolution: keep the local edits. Returns a future that
  /// resolves once the re-PATCH lands. The draft already carries the
  /// server's new revisionId (set in the conflict catch block) so the
  /// retried request will pass If-Match.
  Future<void> resolveConflictKeepMine() async {
    _conflictServer = null;
    syncStatus.value = SyncStatus.dirty;
    await forceSyncToBackend();
  }

  // ── Re-detect type/rarity from prompt ───────────────────────────────────

  /// Re-runs the keyword-scoring detection used during agent creation. We
  /// don't allow manual override of `characterType` or `rarity` per the
  /// product decision; the only path is "edit the prompt + re-detect".
  ///
  /// Note: rarity stays as-is (it comes from the analysis pipeline at
  /// creation time and isn't keyword-derivable here). Only [characterType]
  /// — and by extension the default subclass — gets recomputed locally.
  void reDetectFromPrompt() {
    final detected = _scorePrompt(draft.value.prompt);
    if (detected == draft.value.characterType) return;
    // Reset subclass to the first variant of the new type to avoid an
    // invalid (type, subclass) pair.
    final newSubclass = detected.subclasses.first;
    updateField((a) => a.copyWith(
          characterType: detected,
          subclass: newSubclass,
        ));
  }

  // ── Image regeneration ──────────────────────────────────────────────────

  Future<({bool ok, String? message})> regenerateImage() async {
    if (isRegeneratingImage.value) return (ok: false, message: 'Already regenerating');
    isRegeneratingImage.value = true;
    try {
      final res = await ApiService.instance.regenerateImage(draft.value.id);
      if (res == null) {
        return (ok: false, message: 'No response from server');
      }
      final fresh = AgentModel.fromJson(res);
      _original = fresh;
      // Force-replace: the user can't have typed faster than this 90s call.
      draft.value = fresh;
      _pushHistory(fresh);
      return (ok: true, message: 'Art regenerated');
    } catch (e) {
      return (ok: false, message: e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isRegeneratingImage.value = false;
    }
  }

  // ── Equality helper ─────────────────────────────────────────────────────

  /// Editable-field equality. Identifiers and counters (id, wallet,
  /// useCount, etc.) are intentionally excluded — they can't change via
  /// the editor.
  static bool _isSameContent(AgentModel a, AgentModel b) {
    return a.title == b.title &&
        a.description == b.description &&
        a.prompt == b.prompt &&
        a.category == b.category &&
        a.characterType == b.characterType &&
        a.subclass == b.subclass &&
        a.rarity == b.rarity &&
        a.cardVersion == b.cardVersion &&
        a.price == b.price &&
        a.serviceDescription == b.serviceDescription &&
        a.profileMood == b.profileMood &&
        a.profileRolePurpose == b.profileRolePurpose &&
        listEquals(a.tags, b.tags) &&
        listEquals(a.traits, b.traits) &&
        mapEquals(a.stats, b.stats);
  }

  // ── Keyword scoring (mirrored from CreateAgentController) ───────────────

  static final _rng = Random();

  CharacterType _scorePrompt(String promptText) {
    final p = promptText.toLowerCase();
    final scores = <CharacterType, int>{};
    for (final entry in _keywords.entries) {
      int score = 0;
      for (final kw in entry.value) {
        if (p.contains(kw)) score++;
      }
      if (score > 0) scores[entry.key] = score;
    }
    if (scores.isNotEmpty) {
      return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    return CharacterType.values[_rng.nextInt(CharacterType.values.length)];
  }

  static const _keywords = <CharacterType, List<String>>{
    CharacterType.wizard: [
      'backend', 'golang', 'python', 'api', 'database', 'server', 'code',
      'developer', 'sql', 'java', 'programmer', 'rust', 'typescript',
      'javascript', 'node', 'docker', 'kubernetes', 'microservice', 'cli',
      'script', 'algorithm', 'compiler', 'debug', 'refactor', 'git',
      'deploy', 'terraform', 'lambda', 'redis', 'mongodb', 'graphql',
      'grpc', 'yazılım', 'programlama',
    ],
    CharacterType.strategist: [
      'plan', 'strategy', 'project', 'manager', 'roadmap', 'agile',
      'scrum', 'task', 'lead', 'coordinate', 'prioritize', 'deadline',
      'sprint', 'okr', 'milestone', 'kanban', 'delegate', 'decision',
      'stakeholder', 'timeline', 'objective', 'organize', 'schedule',
      'workflow', 'yönetim', 'hedef', 'planlama',
    ],
    CharacterType.oracle: [
      'data', 'analytics', 'insight', 'statistics', 'machine learning',
      'neural', 'deep learning', 'dataset', 'visualization', 'prediction',
      'tableau', 'pandas', 'numpy', 'tensorflow', 'pytorch', 'regression',
      'classification', 'clustering', 'nlp', 'llm', 'embedding', 'vector',
      'rag', 'model', 'forecast', 'metric', 'dashboard', 'bigquery',
      'analiz', 'veri', 'tahmin',
    ],
    CharacterType.guardian: [
      'security', 'firewall', 'pentest', 'infra', 'hacker', 'encrypt',
      'auth', 'vulnerability', 'devops', 'cloud', 'aws', 'azure',
      'monitoring', 'backup', 'ssl', 'tls', 'oauth', 'jwt',
      'compliance', 'audit', 'sre', 'incident', 'malware', 'phishing',
      'vpn', 'proxy', 'sandbox', 'güvenlik', 'koruma', 'şifre',
    ],
    CharacterType.artisan: [
      'frontend', 'ui', 'ux', 'design', 'flutter', 'react', 'css',
      'figma', 'prototype', 'responsive', 'layout', 'animation',
      'tailwind', 'component', 'widget', 'wireframe', 'pixel',
      'typography', 'icon', 'illustration', 'accessibility', 'swiftui',
      'html', 'sass', 'bootstrap', 'tasarım', 'arayüz', 'görsel',
    ],
    CharacterType.bard: [
      'write', 'story', 'creative', 'content', 'blog', 'copy', 'poem',
      'translate', 'email', 'summarize', 'tone', 'chat', 'conversation',
      'dialogue', 'screenplay', 'novel', 'fiction', 'essay', 'slogan',
      'headline', 'caption', 'speech', 'presentation', 'pitch',
      'narrative', 'persona', 'roleplay', 'letter', 'hikaye', 'çeviri',
      'şiir', 'metin',
    ],
    CharacterType.scholar: [
      'research', 'study', 'academic', 'science', 'learn', 'explain',
      'teach', 'tutor', 'knowledge', 'history', 'math', 'physics',
      'chemistry', 'biology', 'philosophy', 'literature', 'encyclopedia',
      'thesis', 'paper', 'journal', 'lecture', 'curriculum', 'exam',
      'university', 'professor', 'textbook', 'quiz', 'homework',
      'eğitim', 'öğren', 'bilim', 'ders', 'araştır',
    ],
    CharacterType.merchant: [
      'business', 'sales', 'marketing', 'growth', 'revenue', 'startup',
      'finance', 'ecommerce', 'pricing', 'customer', 'roi', 'brand',
      'negotiate', 'profit', 'investment', 'stock', 'crypto', 'blockchain',
      'seo', 'ads', 'campaign', 'funnel', 'conversion', 'churn',
      'retention', 'b2b', 'saas', 'ticaret', 'pazarlama', 'müşteri',
      'gelir', 'fiyat', 'satış',
    ],
  };
}
