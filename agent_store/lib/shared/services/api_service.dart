import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/legend/models/workflow_models.dart';
import '../models/agent_model.dart';
import '../models/mission_model.dart';
import '../models/guild_model.dart';
import '../../core/constants/api_constants.dart';
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
        final entries = (jsonDecode(res.body) as Map<String, dynamic>)['entries'] as List<dynamic>;
        final result = entries.map((e) =>
          AgentModel.fromJson((e as Map<String, dynamic>)['agent'] as Map<String, dynamic>)).toList();
        _setCache(cacheKey, result);
        return result;
      }
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

  Future<Map<String, dynamic>?> getLeaderboard() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.leaderboard), headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('getLeaderboard: $e'); }
    return null;
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

  Future<MissionModel?> saveMission(MissionModel mission) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.userMissions),
        headers: _headers,
        body: jsonEncode(mission.toJson()),
      );
      if (res.statusCode == 200) {
        return MissionModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      debugPrint('saveMission: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('saveMission: $e'); }
    return null;
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

  Future<LegendWorkflow?> saveLegendWorkflow(LegendWorkflow workflow) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.userLegendWorkflows),
        headers: _headers,
        body: jsonEncode(workflow.toJson()),
      );
      if (res.statusCode == 200) {
        return LegendWorkflow.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      debugPrint('saveLegendWorkflow: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('saveLegendWorkflow: $e'); }
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

      final res = await http.put(
        Uri.parse('${ApiConstants.agents}/$agentId'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        invalidateCache('agents');
        return jsonDecode(res.body) as Map<String, dynamic>;
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

  Future<Map<String, dynamic>?> suggestGuild(String problem) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.guildMaster}/suggest'),
        headers: _headers,
        body: jsonEncode({'problem': problem}),
      ).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('suggestGuild: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) { debugPrint('suggestGuild: $e'); }
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
}
