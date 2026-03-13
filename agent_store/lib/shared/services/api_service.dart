import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_model.dart';
import '../models/guild_model.dart';
import '../../core/constants/api_constants.dart';

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

  String? _token;
  void setToken(String t) {
    _token = t;
    SharedPreferences.getInstance().then((p) => p.setString(_kTokenKey, t));
  }

  void clearToken() {
    _token = null;
    SharedPreferences.getInstance().then((p) => p.remove(_kTokenKey));
    invalidateCache(); // wipe all caches on logout
  }

  bool get isAuthenticated => _token != null;

  /// Call once at app startup to restore a previously saved JWT.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kTokenKey);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String?> getNonce(String wallet) async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.authNonce}/$wallet'), headers: _headers);
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
      final res = await http.post(Uri.parse(ApiConstants.authVerify), headers: _headers,
        body: jsonEncode({'wallet': wallet, 'nonce': nonce, 'signature': signature}));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('verifySignature: $e'); }
    return null;
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
  }) async {
    final cacheKey = 'agents_${category ?? ''}_${search ?? ''}_${sort}_${page}_${limit}_${minPrice ?? 0}_${maxPrice ?? 0}_${tags?.join(',') ?? ''}';
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

  Future<bool> setAgentPrice(int agentId, double price) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiConstants.agents}/$agentId/price'),
        headers: _headers,
        body: jsonEncode({'price': price}),
      );
      return res.statusCode == 200;
    } catch (e) { debugPrint('setAgentPrice: $e'); return false; }
  }

  Future<Map<String, dynamic>?> topUpCredits(String txHash, double amountMon) async {
    try {
      final r = await http.post(
        Uri.parse('${ApiConstants.apiV1}/user/credits/topup'),
        headers: _headers,
        body: jsonEncode({'tx_hash': txHash, 'amount_mon': amountMon}),
      );
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      debugPrint('topUpCredits: HTTP ${r.statusCode} — ${r.body}');
    } catch (e) { debugPrint('topUpCredits: $e'); }
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
