import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/legend/models/workflow_models.dart';
import '../models/agent_model.dart';
import '../models/mission_model.dart';
import '../models/guild_model.dart';
import '../../core/constants/api_constants.dart';
import 'conflict_resolver.dart';
import 'local_kv_store.dart';

const _kTokenKey = 'jwt_token';

class ApiService {
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  ApiService._();

  // ── In-memory TTL cache ──────────────────────────────────────────────────
  final Map<String, ({dynamic data, DateTime expiry})> _cache = {};

  T? _getCache<T>(String key) {
    final entry = _cache[key];
    if (entry == null || DateTime.now().isAfter(entry.expiry)) return null;
    return entry.data as T;
  }

  void _setCache(String key, dynamic data, {Duration ttl = const Duration(seconds: 60)}) {
    _cache[key] = (data: data, expiry: DateTime.now().add(ttl));
  }

  void invalidateCache([String? prefix]) {
    if (prefix == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((k, _) => k.startsWith(prefix));
    }
  }
  // ────────────────────────────────────────────────────────────────────────

  /// Exponential backoff retry helper.  3 attempts with 1s / 2s / 4s delays.
  Future<T> retry<T>(Future<T> Function() fn, {int maxAttempts = 3}) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }
    throw StateError('retry exhausted'); // unreachable
  }

  String? _token;
  void setToken(String t) {
    _token = t;
    LocalKvStore.instance.setString(_kTokenKey, t);
  }

  void clearToken() {
    _token = null;
    LocalKvStore.instance.remove(_kTokenKey);
    invalidateCache(); // wipe all caches on logout
  }

  bool get isAuthenticated => _token != null;

  /// Call once at app startup to restore a previously saved JWT.
  Future<void> init() async {
    _token = await LocalKvStore.instance.getString(_kTokenKey);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
  };

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String?> getNonce(String wallet) async {
    try {
      // Public endpoint: keep request simple to avoid browser preflight issues.
      final res = await http.get(Uri.parse('${ApiConstants.authNonce}/$wallet'));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as Map<String, dynamic>)['nonce'] as String?;
      }
    } catch (e) { debugPrint('getNonce: $e'); }
    return null;
  }

  Future<Map<String, dynamic>?> verifySignature({
    required String wallet, required String nonce, required String signature,
  }) async {
    try {
      final res = await http.post(Uri.parse(ApiConstants.authVerify), headers: _jsonHeaders,
        body: jsonEncode({'wallet': wallet, 'nonce': nonce, 'signature': signature}));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('verifySignature: $e'); }
    return null;
  }

  /// Notifies the backend that the user dropped a signing request (rejected
  /// the MetaMask popup, closed the tab, or otherwise abandoned the flow)
  /// so the stored nonce can be rotated. Best-effort fire-and-forget — a
  /// failure here is not user-facing because the next /auth/nonce call will
  /// rotate the value anyway. Pre-empting that race closes the small window
  /// where a leaked nonce could be replayed before the user retries.
  Future<void> abandonSignature(String wallet) async {
    try {
      await http.post(
        Uri.parse(ApiConstants.authAbandon),
        headers: _jsonHeaders,
        body: jsonEncode({'wallet': wallet}),
      );
    } catch (e) {
      debugPrint('abandonSignature: $e');
    }
  }

  // ── Categories ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async {
    const cacheKey = 'categories';
    final cached = _getCache<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

    try {
      final res = await http.get(
        Uri.parse(ApiConstants.agentCategories),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = (jsonDecode(res.body) as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _setCache(cacheKey, data, ttl: const Duration(seconds: 120));
        return data;
      }
    } catch (e) {
      debugPrint('getCategories: $e');
    }
    return [];
  }

  // ── Agents ────────────────────────────────────────────────────────────────

  Future<({List<AgentModel> agents, int total})> listAgents({
    String? category,
    String? search,
    String sort = 'newest',
    int page = 1,
    int limit = 20,
    double? minPrice,
    double? maxPrice,
    List<String>? tags,
    String? creatorWallet,
  }) async {
    final cacheKey = 'agents_${category ?? ''}_${search ?? ''}_${sort}_${page}_${limit}_${minPrice ?? 0}_${maxPrice ?? 0}_${tags?.join(',') ?? ''}_${creatorWallet ?? ''}';
    final cached = _getCache<({List<AgentModel> agents, int total})>(cacheKey);
    if (cached != null) return cached;
    try {
      final uri = Uri.parse(ApiConstants.agents).replace(queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
        'sort': sort,
        'page': '$page', 'limit': '$limit',
        if (minPrice != null) 'min_price': minPrice.toStringAsFixed(2),
        if (maxPrice != null) 'max_price': maxPrice.toStringAsFixed(2),
        if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
        if (creatorWallet != null && creatorWallet.isNotEmpty) 'creator_wallet': creatorWallet,
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['agents'] as List<dynamic>)
            .map((e) => AgentModel.fromJson(e as Map<String, dynamic>)).toList();
        final result = (agents: list, total: data['total'] as int? ?? 0);
        _setCache(cacheKey, result);
        return result;
      }
    } catch (e) { debugPrint('listAgents: $e'); }
    return (agents: <AgentModel>[], total: 0);
  }

  Future<AgentModel?> getAgent(int id) async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.agents}/$id'), headers: _headers);
      if (res.statusCode == 200) return AgentModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) { debugPrint('getAgent: $e'); }
    return null;
  }

  /// v3.11.1 — Returns up to [limit] agents that share the source agent's
  /// character_type, ranked by save_count DESC. The source agent itself is
  /// always excluded server-side. Empty list on any failure (silent fail —
  /// the UI hides the ribbon when the result is empty).
  Future<List<AgentModel>> getSimilarAgents(int id, {int limit = 5}) async {
    try {
      final uri = Uri.parse('${ApiConstants.agents}/$id/similar')
          .replace(queryParameters: {'limit': '$limit'});
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['agents'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('getSimilarAgents: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('getSimilarAgents: $e');
    }
    return const [];
  }

  Future<List<AgentModel>> batchGetAgents(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.agents}/batch'),
        headers: _headers,
        body: jsonEncode({'ids': ids}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['agents'] as List)
            .map((j) => AgentModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('batchGetAgents: $e');
    }
    return [];
  }

  Future<AgentModel?> createAgent({
    required String title,
    required String description,
    required String prompt,
  }) async {
    try {
      // Image generation can take up to 60s — give 120s total timeout
      final res = await http
          .post(
            Uri.parse(ApiConstants.agents),
            headers: _headers,
            body: jsonEncode({'title': title, 'description': description, 'prompt': prompt}),
          )
          .timeout(const Duration(seconds: 120));
      if (res.statusCode == 201) {
        invalidateCache('agents');
        return AgentModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      debugPrint('createAgent: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('createAgent: $e'); }
    return null;
  }

  // ── Library ───────────────────────────────────────────────────────────────

  Future<List<AgentModel>> getLibrary() async {
    const cacheKey = 'library';
    final cached = _getCache<List<AgentModel>>(cacheKey);
    if (cached != null) return cached;
    try {
      final res = await http.get(Uri.parse(ApiConstants.userLibrary), headers: _headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        // Be tolerant of `null` (legacy backend used to return {"entries":null}
        // for empty libraries) and of entries whose embedded `agent` field
        // got dropped due to a deleted FK row.
        final raw = (body['entries'] as List<dynamic>?) ?? const <dynamic>[];
        final result = <AgentModel>[];
        for (final e in raw) {
          if (e is! Map<String, dynamic>) continue;
          final agent = e['agent'];
          if (agent is! Map<String, dynamic>) continue;
          final id = (agent['id'] as num?)?.toInt() ?? 0;
          if (id == 0) continue; // dangling FK — skip
          result.add(AgentModel.fromJson(agent));
        }
        _setCache(cacheKey, result);
        return result;
      }
      debugPrint('getLibrary: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('getLibrary: $e'); }
    return [];
  }

  Future<bool> addToLibrary(int id) async {
    try {
      final res = await http.post(Uri.parse('${ApiConstants.userLibrary}/$id'), headers: _headers);
      if (res.statusCode == 200) { invalidateCache('library'); return true; }
      return false;
    } catch (e) { debugPrint('addToLibrary: $e'); return false; }
  }

  Future<bool> removeFromLibrary(int id) async {
    try {
      final res = await http.delete(Uri.parse('${ApiConstants.userLibrary}/$id'), headers: _headers);
      if (res.statusCode == 200) { invalidateCache('library'); return true; }
      return false;
    } catch (e) { debugPrint('removeFromLibrary: $e'); return false; }
  }

  Future<int> getCredits() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.userCredits), headers: _headers);
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as Map<String, dynamic>)['credits'] as int? ?? 0;
      }
    } catch (e) { debugPrint('getCredits: $e'); }
    return 0;
  }

  // ── Trending / Fork / Chat / Profile ─────────────────────────────────────

  Future<List<AgentModel>> getTrending() async {
    const cacheKey = 'trending';
    final cached = _getCache<List<AgentModel>>(cacheKey);
    if (cached != null) return cached;
    try {
      final res = await http.get(Uri.parse('${ApiConstants.agents}/trending'), headers: _headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['agents'] as List<dynamic>)
            .map((e) => AgentModel.fromJson(e as Map<String, dynamic>)).toList();
        _setCache(cacheKey, list, ttl: const Duration(seconds: 120));
        return list;
      }
    } catch (e) { debugPrint('getTrending: $e'); }
    return [];
  }

  Future<AgentModel?> forkAgent(int id) async {
    try {
      final res = await http.post(Uri.parse('${ApiConstants.agents}/$id/fork'), headers: _headers);
      if (res.statusCode == 201) return AgentModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      debugPrint('forkAgent: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('forkAgent: $e'); }
    return null;
  }

  Future<String?> chatWithAgent(int id, String message) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.agents}/$id/chat'),
        headers: _headers,
        body: jsonEncode({'message': message}),
      ).timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['reply'] as String?;
      }
      debugPrint('chatWithAgent: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('chatWithAgent: $e'); }
    return null;
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.userProfile), headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getUserProfile: $e'); }
    return null;
  }

  Future<Map<String, dynamic>?> getCreditHistory() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.userCreditHistory), headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getCreditHistory: $e'); }
    return null;
  }

  Future<Map<String, dynamic>?> getLeaderboard({String window = 'all'}) async {
    try {
      final uri = Uri.parse(ApiConstants.leaderboard).replace(
        queryParameters: {'window': window},
      );
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getLeaderboard: $e'); }
    return null;
  }

  // ── Social: Follow / Unfollow ────────────────────────────────────────────

  Future<bool> followUser(String wallet) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.apiV1}/users/$wallet/follow'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('followUser: $e'); return false; }
  }

  Future<bool> unfollowUser(String wallet) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiConstants.apiV1}/users/$wallet/follow'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('unfollowUser: $e'); return false; }
  }

  /// Returns {is_following, followers, following} or null on error.
  Future<Map<String, dynamic>?> getFollowStatus(String wallet) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.apiV1}/users/$wallet/follow-status'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getFollowStatus: $e'); }
    return null;
  }

  // ── Social: Activity Feed ────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getActivityFeed(
    String wallet, {
    int beforeId = 0,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.apiV1}/users/$wallet/feed').replace(
        queryParameters: {
          if (beforeId > 0) 'before_id': '$beforeId',
          'limit': '$limit',
        },
      );
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getActivityFeed: $e'); }
    return null;
  }

  // ── For You recommendations ──────────────────────────────────────────────

  Future<List<AgentModel>> getForYou() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.agents}/for-you'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['agents'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) { debugPrint('getForYou: $e'); }
    return [];
  }

  Future<Map<String, dynamic>?> getPublicProfile(String wallet) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.apiV1}/users/$wallet'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getPublicProfile: $e'); }
    return null;
  }

  Future<bool> updateProfile({required String username, required String bio}) async {
    try {
      final res = await http.patch(
        Uri.parse(ApiConstants.userProfile),
        headers: _headers,
        body: jsonEncode({'username': username, 'bio': bio}),
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('updateProfile: $e'); return false; }
  }

  Future<List<MissionModel>> getUserMissions() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.userMissions), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final missions = (data['missions'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => MissionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return missions;
      }
      if (res.statusCode == 502) {
        debugPrint('CRITICAL: getUserMissions — workspace service unreachable (502). Body: ${res.body}');
      } else {
        debugPrint('getUserMissions: HTTP ${res.statusCode} — ${res.body}');
      }
    } catch (e) { debugPrint('getUserMissions: $e'); }
    return [];
  }

  /// Saves [mission] with optimistic-concurrency support (v3.7-13.1). When
  /// the mission carries a non-zero revisionId, sends `If-Match: <rev>`;
  /// the server returns 409 + the current row when stored revision has
  /// advanced past ours.
  Future<MissionSaveResult> saveMissionWithRevision(MissionModel mission) async {
    try {
      final headers = Map<String, String>.from(_headers);
      if (mission.revisionId > 0) {
        headers['If-Match'] = '${mission.revisionId}';
      }
      final res = await http.post(
        Uri.parse(ApiConstants.userMissions),
        headers: headers,
        body: jsonEncode(mission.toJson()),
      );
      if (res.statusCode == 200) {
        return MissionSaveResult.ok(
          MissionModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>),
        );
      }
      if (res.statusCode == 409) {
        Map<String, dynamic>? body;
        try {
          body = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {}
        return MissionSaveResult.conflict(body ?? const {});
      }
      debugPrint('saveMission: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('saveMission: $e');
    }
    return const MissionSaveResult.error();
  }

  /// Backward-compatible wrapper for callers that don't yet handle 409.
  /// Discards conflict outcomes and returns null.
  Future<MissionModel?> saveMission(MissionModel mission) async {
    final r = await saveMissionWithRevision(mission);
    return r.saved;
  }

  Future<bool> deleteMission(String id) async {
    try {
      final res = await http.delete(Uri.parse('${ApiConstants.userMissions}/$id'), headers: _headers);
      return res.statusCode == 200;
    } catch (e) { debugPrint('deleteMission: $e'); }
    return false;
  }

  /// Sends all local missions to the backend in a single request. The backend
  /// upserts each one and returns the full list from the DB.
  Future<List<MissionModel>> batchSyncMissions(List<MissionModel> missions) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.userMissionsSync),
        headers: _headers,
        body: jsonEncode({'missions': missions.map((m) => m.toJson()).toList()}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['missions'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => MissionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (res.statusCode == 502) {
        debugPrint('CRITICAL: batchSyncMissions — workspace service unreachable (502). Body: ${res.body}');
      } else {
        debugPrint('batchSyncMissions: HTTP ${res.statusCode} — ${res.body}');
      }
    } catch (e) { debugPrint('batchSyncMissions: $e'); }
    return [];
  }

  Future<List<LegendWorkflow>> getLegendWorkflows() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.userLegendWorkflows), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['workflows'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => LegendWorkflow.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (res.statusCode == 502) {
        debugPrint('CRITICAL: getLegendWorkflows — workspace service unreachable (502). Body: ${res.body}');
      } else {
        debugPrint('getLegendWorkflows: HTTP ${res.statusCode} — ${res.body}');
      }
    } catch (e) { debugPrint('getLegendWorkflows: $e'); }
    return [];
  }

  /// Saves a workflow, optionally enforcing optimistic concurrency.
  ///
  /// If [workflow.revisionId] is > 0 and [enforceRevision] is true, an
  /// `If-Match` header is sent so the backend can reject stale writes with
  /// 409 Conflict. On 409 a [ConflictException] is thrown, carrying the
  /// server's current copy of the workflow JSON for the resolver to compare.
  /// All other failures return null (legacy contract preserved).
  Future<LegendWorkflow?> saveLegendWorkflow(
    LegendWorkflow workflow, {
    bool enforceRevision = true,
  }) async {
    try {
      final headers = Map<String, String>.from(_headers);
      if (enforceRevision && workflow.revisionId > 0) {
        headers['If-Match'] = '${workflow.revisionId}';
      }
      final res = await http.post(
        Uri.parse(ApiConstants.userLegendWorkflows),
        headers: headers,
        body: jsonEncode(workflow.toJson()),
      );
      if (res.statusCode == 200) {
        return LegendWorkflow.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      if (res.statusCode == 409) {
        // Body is the server's current workflow row; surface to ConflictResolver.
        final serverJson = jsonDecode(res.body) as Map<String, dynamic>;
        throw ConflictException(serverJson);
      }
      debugPrint('saveLegendWorkflow: HTTP ${res.statusCode} — ${res.body}');
    } on ConflictException {
      rethrow;
    } catch (e) {
      debugPrint('saveLegendWorkflow: $e');
    }
    return null;
  }

  Future<bool> deleteLegendWorkflow(String id) async {
    try {
      final res = await http.delete(Uri.parse('${ApiConstants.userLegendWorkflows}/$id'), headers: _headers);
      return res.statusCode == 200;
    } catch (e) { debugPrint('deleteLegendWorkflow: $e'); }
    return false;
  }

  /// Sends all local workflows to the backend in a single request. The backend
  /// upserts each one and returns the full list from the DB.
  Future<List<LegendWorkflow>> batchSyncLegendWorkflows(List<LegendWorkflow> workflows) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.userLegendWorkflowsSync),
        headers: _headers,
        body: jsonEncode({'workflows': workflows.map((w) => w.toJson()).toList()}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['workflows'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => LegendWorkflow.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (res.statusCode == 502) {
        debugPrint('CRITICAL: batchSyncLegendWorkflows — workspace service unreachable (502). Body: ${res.body}');
      } else {
        debugPrint('batchSyncLegendWorkflows: HTTP ${res.statusCode} — ${res.body}');
      }
    } catch (e) { debugPrint('batchSyncLegendWorkflows: $e'); }
    return [];
  }

  Future<WorkflowExecution?> executeWorkflow(String workflowId, String inputMessage) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.userLegendWorkflows}/$workflowId/execute'),
        headers: _headers,
        body: jsonEncode({'input_message': inputMessage}),
      ).timeout(const Duration(seconds: 180));
      if (res.statusCode == 200) {
        return WorkflowExecution.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      debugPrint('executeWorkflow: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('executeWorkflow: $e'); }
    return null;
  }

  Future<WorkflowExecution?> getExecution(int execId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.userLegendExecutions}/$execId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return WorkflowExecution.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) { debugPrint('getExecution: $e'); }
    return null;
  }

  Future<({List<WorkflowExecution> executions, int total})> listExecutions({
    String? workflowId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse(ApiConstants.userLegendExecutions).replace(queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (workflowId != null) 'workflow_id': workflowId,
      });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['executions'] as List<dynamic>? ?? [])
            .map((e) => WorkflowExecution.fromJson(e as Map<String, dynamic>))
            .toList();
        return (executions: list, total: data['total'] as int? ?? 0);
      }
    } catch (e) { debugPrint('listExecutions: $e'); }
    return (executions: <WorkflowExecution>[], total: 0);
  }

  // ── Trial ─────────────────────────────────────────────────────────────────

  /// Generates a one-time trial token and returns a CLI command that the user
  /// can paste into their terminal. The prompt is encrypted server-side and
  /// only decrypted by the local Node.js script with the user's own API key.
  Future<Map<String, dynamic>?> generateTrialToken(int agentId, String provider, String message) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.agents}/$agentId/trial'),
        headers: _headers,
        body: jsonEncode({'provider': provider, 'message': message}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      if (res.statusCode == 403) {
        final data = jsonDecode(res.body);
        throw Exception(data['error'] ?? 'Trial already used');
      }
      debugPrint('generateTrialToken: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('generateTrialToken: $e');
      rethrow;
    }
    return null;
  }

  // ── Ratings ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getRatings(int agentId) async {
    try {
      final r = await http.get(
        Uri.parse('${ApiConstants.agents}/$agentId/ratings'),
        headers: _headers,
      );
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getRatings: $e'); }
    return null;
  }

  Future<bool> rateAgent(int agentId, int rating, {String comment = ''}) async {
    try {
      final r = await http.post(
        Uri.parse('${ApiConstants.agents}/$agentId/rate'),
        headers: _headers,
        body: jsonEncode({'rating': rating, 'comment': comment}),
      );
      return r.statusCode == 200;
    } catch (e) { debugPrint('rateAgent: $e'); return false; }
  }

  /// Records a unique-per-wallet "helpful" upvote on a rating. Returns the
  /// new helpful count from the server, or null on failure (network, 4xx).
  /// Server-side dedup is authoritative — this method may safely be called
  /// repeatedly; the server returns the same count without double-counting.
  Future<int?> markRatingHelpful(int agentId, int ratingId) async {
    try {
      final r = await http.post(
        Uri.parse('${ApiConstants.agents}/$agentId/ratings/$ratingId/helpful'),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        return (body['helpful'] as num?)?.toInt();
      }
      debugPrint('markRatingHelpful: HTTP ${r.statusCode} — ${r.body}');
    } catch (e) {
      debugPrint('markRatingHelpful: $e');
    }
    return null;
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  Future<bool> purchaseAgent(int agentId, String txHash, {double amountMon = 0.0}) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.agents}/$agentId/purchase'),
        headers: _headers,
        body: jsonEncode({'tx_hash': txHash, 'amount_mon': amountMon}),
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('purchaseAgent: $e'); return false; }
  }

  Future<bool> getPurchaseStatus(int agentId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.agents}/$agentId/purchase-status'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as Map<String, dynamic>)['purchased'] as bool? ?? false;
      }
    } catch (e) { debugPrint('getPurchaseStatus: $e'); }
    return false;
  }

  /// Lightweight network probe used for startup preload tiering.
  Future<({int elapsedMs, bool success})> probeNetwork() async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse(ApiConstants.agents).replace(queryParameters: {
        'page': '1',
        'limit': '1',
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      sw.stop();
      return (elapsedMs: sw.elapsedMilliseconds, success: res.statusCode == 200);
    } catch (_) {
      sw.stop();
      return (elapsedMs: sw.elapsedMilliseconds, success: false);
    }
  }

  Future<bool> setAgentPrice(int agentId, double price) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiConstants.agents}/$agentId/price'),
        headers: _headers,
        body: jsonEncode({'price': price}),
      );
      if (res.statusCode == 200) {
        invalidateCache('agents');
        return true;
      }
      return false;
    } catch (e) { debugPrint('setAgentPrice: $e'); return false; }
  }

  /// Update agent metadata. All fields are optional — only the non-null ones
  /// are sent to the backend, which performs a whitelist patch.
  ///
  /// `traits`, `profileMood`, and `profileRolePurpose` are merged into the
  /// agent's `character_data` JSON blob server-side. Stats are deliberately
  /// not patchable here — they're owned by the analysis pipeline.
  Future<Map<String, dynamic>?> updateAgent(int agentId, {
    String? title,
    String? description,
    String? prompt,
    String? category,
    String? subclass,
    List<String>? tags,
    double? price,
    String? cardVersion,
    String? serviceDescription,
    String? profileMood,
    String? profileRolePurpose,
    List<String>? traits,
    /// v3.7-4.2 — when non-null, sent as `If-Match` so the server can
    /// reject (409) when the stored revision has advanced past ours.
    int? ifMatch,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (prompt != null) body['prompt'] = prompt;
      if (category != null) body['category'] = category;
      if (subclass != null) body['subclass'] = subclass;
      if (tags != null) body['tags'] = tags;
      if (price != null) body['price'] = price;
      if (cardVersion != null) body['card_version'] = cardVersion;
      if (serviceDescription != null) body['service_description'] = serviceDescription;
      if (profileMood != null) body['profile_mood'] = profileMood;
      if (profileRolePurpose != null) body['profile_role_purpose'] = profileRolePurpose;
      if (traits != null) body['traits'] = traits;

      if (body.isEmpty) return null; // nothing to do — don't waste a round-trip

      final headers = Map<String, String>.from(_headers);
      if (ifMatch != null && ifMatch > 0) {
        headers['If-Match'] = '$ifMatch';
      }
      final res = await http.put(
        Uri.parse('${ApiConstants.agents}/$agentId'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        invalidateCache('agents');
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      if (res.statusCode == 409) {
        // Surface as ConflictException so the [ConflictResolver] picks it up.
        Map<String, dynamic> serverRow;
        try {
          serverRow = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          serverRow = const {};
        }
        throw ConflictException(serverRow);
      }
      final err = jsonDecode(res.body);
      throw Exception(err['error'] ?? 'Failed to update agent');
    } catch (e) {
      rethrow;
    }
  }

  /// Regenerate agent avatar image (once per 24h).
  Future<Map<String, dynamic>?> regenerateImage(int agentId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.agents}/$agentId/regenerate-image'),
        headers: _headers,
      ).timeout(const Duration(seconds: 120));

      if (res.statusCode == 200) {
        invalidateCache('agents');
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      final err = jsonDecode(res.body);
      throw Exception(err['error'] ?? 'Failed to regenerate image');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> topUpCredits(String txHash, double amountMon) async {
    try {
      final r = await http.post(
        Uri.parse('${ApiConstants.apiV1}/user/credits/topup'),
        headers: _headers,
        body: jsonEncode({'tx_hash': txHash, 'amount_mon': amountMon}),
      );
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      final err = jsonDecode(r.body) as Map<String, dynamic>?;
      final msg = err?['error'] as String? ?? 'Top-up failed (HTTP ${r.statusCode})';
      debugPrint('topUpCredits: HTTP ${r.statusCode} — $msg');
      throw Exception(msg);
    } catch (e) {
      debugPrint('topUpCredits: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> devGrantCredits(int amount) async {
    try {
      final r = await http.post(
        Uri.parse('${ApiConstants.apiV1}/user/credits/dev-grant'),
        headers: _headers,
        body: jsonEncode({'amount': amount}),
      );
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      debugPrint('devGrantCredits: HTTP ${r.statusCode} — ${r.body}');
    } catch (e) { debugPrint('devGrantCredits: $e'); }
    return null;
  }

  // ── Guilds ────────────────────────────────────────────────────────────────

  Future<({List<GuildModel> guilds, int total})> listGuilds({int page = 1, int limit = 20}) async {
    final cacheKey = 'guilds_${page}_$limit';
    final cached = _getCache<({List<GuildModel> guilds, int total})>(cacheKey);
    if (cached != null) return cached;
    try {
      final uri = Uri.parse(ApiConstants.guilds).replace(queryParameters: {
        'page': '$page', 'limit': '$limit',
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['guilds'] as List<dynamic>)
            .map((e) => GuildModel.fromJson(e as Map<String, dynamic>)).toList();
        final result = (guilds: list, total: data['total'] as int? ?? 0);
        _setCache(cacheKey, result);
        return result;
      }
    } catch (e) { debugPrint('listGuilds: $e'); }
    return (guilds: <GuildModel>[], total: 0);
  }

  Future<GuildDetailModel?> getGuild(int id) async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.guilds}/$id'), headers: _headers);
      if (res.statusCode == 200) {
        return GuildDetailModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) { debugPrint('getGuild: $e'); }
    return null;
  }

  Future<GuildModel?> createGuild({required String name}) async {
    try {
      final res = await http.post(Uri.parse(ApiConstants.guilds), headers: _headers,
        body: jsonEncode({'name': name}));
      if (res.statusCode == 201) return GuildModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      debugPrint('createGuild: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('createGuild: $e'); }
    return null;
  }

  Future<bool> addGuildMember(int guildId, int agentId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.guilds}/$guildId/members'),
        headers: _headers,
        body: jsonEncode({'agent_id': agentId}),
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('addGuildMember: $e'); return false; }
  }

  Future<bool> removeGuildMember(int guildId, int agentId) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiConstants.guilds}/$guildId/members/$agentId'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('removeGuildMember: $e'); return false; }
  }

  Future<bool> joinGuild(int guildId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.guilds}/$guildId/join'),
        headers: _headers,
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) { debugPrint('joinGuild: $e'); return false; }
  }

  Future<bool> leaveGuild(int guildId) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiConstants.guilds}/$guildId/join'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('leaveGuild: $e'); return false; }
  }

  // ── Guild Master ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> suggestGuild(String problem, {int? sessionId}) async {
    try {
      final body = <String, dynamic>{'problem': problem};
      if (sessionId != null) body['session_id'] = sessionId;
      final res = await http.post(
        Uri.parse('${ApiConstants.guildMaster}/suggest'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('suggestGuild: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('suggestGuild: $e'); }
    return null;
  }

  // ── v3.8 Guild Master sessions + action bridges ────────────────────────

  /// Lists left-rail metadata for every Guild Master session owned by the
  /// authenticated wallet (id, title, problem, message_count, timestamps).
  /// Returns an empty list on transport failure so the UI doesn't have
  /// to special-case null.
  Future<List<Map<String, dynamic>>> listGuildMasterSessions() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.guildMaster}/sessions'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ((data['sessions'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      debugPrint('listGuildMasterSessions: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('listGuildMasterSessions: $e');
    }
    return const [];
  }

  /// Creates a new session row, optionally seeded with [problem] +
  /// initial messages. Returns the session detail or null on failure.
  Future<Map<String, dynamic>?> createGuildMasterSession({
    String? title,
    String? problem,
    List<Map<String, dynamic>>? messages,
  }) async {
    try {
      final body = <String, dynamic>{
        if (title != null) 'title': title,
        if (problem != null) 'problem': problem,
        if (messages != null) 'messages': messages,
      };
      final res = await http.post(
        Uri.parse('${ApiConstants.guildMaster}/sessions'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      debugPrint('createGuildMasterSession: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('createGuildMasterSession: $e');
    }
    return null;
  }

  /// Fetches the full session including messages and the last suggestion.
  Future<Map<String, dynamic>?> getGuildMasterSession(int sessionId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.guildMaster}/sessions/$sessionId'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('getGuildMasterSession: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('getGuildMasterSession: $e');
    }
    return null;
  }

  /// Appends one or more messages to a session and returns the refreshed
  /// detail payload. Each message must carry `role` (user/agent/system)
  /// and `content`; agent_id/agent_title/sent_at are optional.
  Future<Map<String, dynamic>?> appendGuildMasterMessages(
    int sessionId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.guildMaster}/sessions/$sessionId/messages'),
        headers: _headers,
        body: jsonEncode({'messages': messages}),
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('appendGuildMasterMessages: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('appendGuildMasterMessages: $e');
    }
    return null;
  }

  /// Hard-deletes a session. Returns true on 200, false otherwise.
  Future<bool> deleteGuildMasterSession(int sessionId) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiConstants.guildMaster}/sessions/$sessionId'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('deleteGuildMasterSession: $e');
      return false;
    }
  }

  /// Bridges a session's stored suggestion into a new UserMission. Returns
  /// the {mission, source} envelope on success, null on any failure path.
  Future<Map<String, dynamic>?> bridgeSessionToMission(int sessionId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.guildMaster}/sessions/$sessionId/to-mission'),
        headers: _headers,
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      debugPrint('bridgeSessionToMission: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('bridgeSessionToMission: $e');
    }
    return null;
  }

  /// Bridges a session's stored suggestion into a new LegendWorkflow draft.
  /// Returns {workflow_id, workflow_name, node_count, edge_count, source}.
  Future<Map<String, dynamic>?> bridgeSessionToLegend(int sessionId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.guildMaster}/sessions/$sessionId/to-legend'),
        headers: _headers,
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      debugPrint('bridgeSessionToLegend: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('bridgeSessionToLegend: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> teamChat(String message, List<int> agentIds) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.guildMaster}/chat'),
        headers: _headers,
        body: jsonEncode({'message': message, 'agent_ids': agentIds}),
      ).timeout(const Duration(seconds: 120));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['responses'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>).toList();
      }
      debugPrint('teamChat: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('teamChat: $e'); }
    return null;
  }

  // ── Legend preflight + versioning (v3.10) ───────────────────────────────

  Future<Map<String, dynamic>?> preflightWorkflow(String workflowId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.userLegendWorkflows}/$workflowId/preflight'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('preflightWorkflow: $e'); }
    return null;
  }

  Future<List<Map<String, dynamic>>> getWorkflowVersions(String workflowId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.userLegendWorkflows}/$workflowId/versions'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['versions'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
    } catch (e) { debugPrint('getWorkflowVersions: $e'); }
    return [];
  }

  Future<Map<String, dynamic>?> getWorkflowVersion(String workflowId, int versionId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.userLegendWorkflows}/$workflowId/versions/$versionId'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getWorkflowVersion: $e'); }
    return null;
  }

  // ── Mission marketplace (v3.10) ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPublicMissions({String? cat}) async {
    try {
      final uri = Uri.parse(ApiConstants.missionsPublic).replace(
        queryParameters: cat != null && cat.isNotEmpty ? {'cat': cat} : null,
      );
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['missions'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
    } catch (e) { debugPrint('getPublicMissions: $e'); }
    return [];
  }

  Future<Map<String, dynamic>?> importPublicMission(String missionId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.userMissions}/$missionId/import'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('importPublicMission: $e'); }
    return null;
  }

  /// v3.11.1 — Bridges a UserMission into a new LegendWorkflow draft.
  /// Returns the new workflow's numeric id, or 0 on failure.
  /// Backend: POST /api/v1/user/missions/:id/to-legend.
  Future<int> missionToLegend(String missionId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.userMissions}/$missionId/to-legend'),
        headers: _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return (body['id'] as num?)?.toInt() ?? 0;
      }
      debugPrint('missionToLegend: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('missionToLegend: $e');
    }
    return 0;
  }

  Future<bool> setMissionPublic(String missionId, {required bool public}) async {
    try {
      final res = await http.patch(
        Uri.parse('${ApiConstants.userMissions}/$missionId/public'),
        headers: _headers,
        body: jsonEncode({'public': public}),
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('setMissionPublic: $e'); return false; }
  }

  // ── Guild invite + permissions + explainability (v3.10) ──────────────────

  Future<Map<String, dynamic>?> createGuildInvite(
    String guildId, {
    int? maxUses,
    int? expiresInHours,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (maxUses != null) body['max_uses'] = maxUses;
      if (expiresInHours != null) body['expires_in_hours'] = expiresInHours;
      final res = await http.post(
        Uri.parse('${ApiConstants.guilds}/$guildId/invite'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('createGuildInvite: $e'); }
    return null;
  }

  Future<Map<String, dynamic>?> getGuildInvite(String token) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.guilds}/invite/$token'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getGuildInvite: $e'); }
    return null;
  }

  Future<bool> acceptGuildInvite(String token) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.guilds}/invite/$token/accept'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('acceptGuildInvite: $e'); return false; }
  }

  Future<bool> setMemberPermissions(
    String guildId,
    String memberId,
    List<String> permissions,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiConstants.guilds}/$guildId/members/$memberId/permissions'),
        headers: _headers,
        body: jsonEncode({'permissions': permissions}),
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('setMemberPermissions: $e'); return false; }
  }

  Future<Map<String, dynamic>?> explainCompatibility(String guildId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.guilds}/$guildId/explain'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('explainCompatibility: $e'); }
    return null;
  }

  // ── Creator analytics (v3.10) ────────────────────────────────────────────

  Future<Map<String, dynamic>?> getCreatorInsights({String since = '30d'}) async {
    try {
      final uri = Uri.parse(ApiConstants.creatorInsights)
          .replace(queryParameters: {'since': since});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getCreatorInsights: $e'); }
    return null;
  }

  // ── Notification Center (v3.11.2) ────────────────────────────────────────

  /// Lists the per-(channel, type) notification preferences for the
  /// authenticated wallet. Each row contains `channel`, `type`, `enabled`.
  /// Returns an empty list on transport failure so the UI can render the
  /// default-allow matrix instead of a hard error.
  Future<List<Map<String, dynamic>>> getNotificationPrefs() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.apiV1}/user/notifications/prefs'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return ((body['prefs'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      debugPrint('getNotificationPrefs: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('getNotificationPrefs: $e');
    }
    return const [];
  }

  /// Upserts a single (channel, type) preference. Returns true when the
  /// server acknowledged the change so the UI can roll back optimistic
  /// state on failure.
  Future<bool> updateNotificationPref(
    String channel,
    String type,
    bool enabled,
  ) async {
    try {
      final res = await http.patch(
        Uri.parse('${ApiConstants.apiV1}/user/notifications/prefs'),
        headers: _headers,
        body: jsonEncode({
          'channel': channel,
          'type': type,
          'enabled': enabled,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('updateNotificationPref: $e');
      return false;
    }
  }

  /// Returns inbox events, newest first. Pass [beforeId] for cursor
  /// pagination (the id of the last visible row).
  Future<List<Map<String, dynamic>>> getNotificationInbox({
    int? beforeId,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.apiV1}/user/notifications/inbox',
      ).replace(queryParameters: {
        if (beforeId != null && beforeId > 0) 'before': '$beforeId',
        'limit': '$limit',
      });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return ((body['events'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      debugPrint('getNotificationInbox: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('getNotificationInbox: $e');
    }
    return const [];
  }

  Future<bool> markNotificationRead(int id) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.apiV1}/user/notifications/inbox/$id/read'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('markNotificationRead: $e');
      return false;
    }
  }

  Future<bool> markAllNotificationsRead() async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.apiV1}/user/notifications/inbox/mark-all-read'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('markAllNotificationsRead: $e');
      return false;
    }
  }

  // ── Developer / API Keys (v3.11.2) ───────────────────────────────────────

  /// Creates a new API key. Server returns the plaintext value ONCE in the
  /// response body — callers must surface it to the user immediately. Subsequent
  /// list calls return only the masked prefix.
  Future<Map<String, dynamic>?> createApiKey(
    String name,
    List<String> scopes,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.apiV1}/user/api-keys'),
        headers: _headers,
        body: jsonEncode({'name': name, 'scopes': scopes}),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      debugPrint('createApiKey: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('createApiKey: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> listApiKeys() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.apiV1}/user/api-keys'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return ((body['keys'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      debugPrint('listApiKeys: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('listApiKeys: $e');
    }
    return const [];
  }

  Future<bool> revokeApiKey(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiConstants.apiV1}/user/api-keys/$id'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('revokeApiKey: $e');
      return false;
    }
  }

  // ── Bulk operations + agent versioning (v3.11.3) ────────────────────────

  /// Performs a bulk action across [ids]. [action] must match a backend-side
  /// handler (e.g. `remove_from_library`, `tag_add`, `tag_remove`,
  /// `regenerate_image`). Returns the parsed response body so callers can
  /// surface partial success / failure counts. Empty map on transport failure.
  Future<Map<String, dynamic>> bulkAgentAction(
    String action,
    List<int> ids, {
    Map<String, dynamic>? payload,
  }) async {
    if (ids.isEmpty) return const {};
    try {
      final body = <String, dynamic>{
        'action': action,
        'ids': ids,
        if (payload != null && payload.isNotEmpty) 'payload': payload,
      };
      final res = await http
          .post(
            Uri.parse('${ApiConstants.agents}/bulk'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        invalidateCache('agents');
        invalidateCache('library');
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      debugPrint('bulkAgentAction: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('bulkAgentAction: $e');
    }
    return const {};
  }

  /// Lists snapshot versions for [agentId] (newest first, max 20). Owner-only
  /// — server returns 403 for non-owners. Empty list on failure.
  Future<List<Map<String, dynamic>>> getAgentVersions(int agentId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.agents}/$agentId/versions'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ((data['versions'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      debugPrint('getAgentVersions: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('getAgentVersions: $e');
    }
    return const [];
  }

  Future<Map<String, dynamic>?> getAgentVersion(int agentId, int version) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.agents}/$agentId/versions/$version'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getAgentVersion: $e'); }
    return null;
  }

  /// Restores [agentId] to [version]. The backend snapshots the current row
  /// before applying the rollback so history is preserved. Returns the
  /// updated agent or null on failure.
  Future<Map<String, dynamic>?> rollbackAgentVersion(int agentId, int version) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.agents}/$agentId/versions/$version/rollback'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        invalidateCache('agents');
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      debugPrint('rollbackAgentVersion: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('rollbackAgentVersion: $e');
    }
    return null;
  }

  /// v3.11.3 — Returns funnel KPI metrics for the authed creator. [window]
  /// must be one of `7d`, `30d`, `90d`. Returns null on transport failure
  /// so the panel can render a friendly empty state.
  Future<Map<String, dynamic>?> getFunnelMetrics({String window = '30d'}) async {
    try {
      final uri = Uri.parse('${ApiConstants.apiV1}/admin/kpi/funnel')
          .replace(queryParameters: {'since': window});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('getFunnelMetrics: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('getFunnelMetrics: $e');
    }
    return null;
  }

  /// Downloads the OpenClaw-compatible SKILL.md for [agentId].
  /// Returns the raw Markdown text, or null on error / 403 (not purchased).
  Future<String?> fetchAgentSkillMd(int agentId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.agents}/$agentId/skill.md'),
        headers: _headers,
      );
      if (res.statusCode == 200) return res.body;
      debugPrint('fetchAgentSkillMd: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('fetchAgentSkillMd: $e');
    }
    return null;
  }
}

/// Outcome of a [ApiService.saveMissionWithRevision] call (v3.7-13.1).
/// Three-state result so callers can distinguish 200 success from 409
/// optimistic-concurrency conflict from a generic transport/server error.
class MissionSaveResult {
  /// Saved row returned by the server (with bumped revisionId). null on
  /// conflict or error.
  final MissionModel? saved;

  /// Server's current row when the response was 409. Empty map on success
  /// or generic error. Use [hasConflict] to test.
  final Map<String, dynamic> serverRow;

  /// True when the server rejected the save with 409 because the stored
  /// revision was newer than ours.
  final bool hasConflict;

  /// True when the request failed for any other reason (transport, 4xx,
  /// 5xx). Use this to surface a generic error to the user.
  final bool isError;

  const MissionSaveResult.ok(this.saved)
      : serverRow = const {},
        hasConflict = false,
        isError = false;

  const MissionSaveResult.conflict(Map<String, dynamic> server)
      : saved = null,
        serverRow = server,
        hasConflict = true,
        isError = false;

  const MissionSaveResult.error()
      : saved = null,
        serverRow = const {},
        hasConflict = false,
        isError = true;
}
