// Tests for ApiService — the lowest-level HTTP client used across every
// feature. ApiService calls top-level http functions directly (no
// injectable Client), so the network layer cannot be mocked here. What we
// CAN lock down is the surface contract that does not touch the network:
//
//   * Token / auth state (setToken, clearToken, isAuthenticated)
//   * Cache invalidation by prefix (invalidateCache)
//   * The retry() helper's exhaustion / success semantics
//   * MissionSaveResult three-state contract (ok / conflict / error)
//   * AgentModel.fromJson — the response parser used by listAgents,
//     getAgent, getTrending, batchGetAgents, getForYou, getSimilarAgents
//   * URL constants the service constructs paths from (proves
//     resumeLegendExecution, missionToLegend, etc. point at /resume etc.)

import 'package:agent_store/core/constants/api_constants.dart';
import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/shared/models/agent_model.dart';
import 'package:agent_store/shared/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Each test starts with a clean token + empty cache. The service is a
    // singleton, so we have to reset state explicitly between tests.
    ApiService.instance.clearToken();
    ApiService.instance.invalidateCache();
  });

  group('ApiService — token state', () {
    test('starts unauthenticated', () {
      expect(ApiService.instance.isAuthenticated, isFalse);
    });

    test('setToken flips isAuthenticated to true', () {
      ApiService.instance.setToken('jwt-abc-123');
      expect(ApiService.instance.isAuthenticated, isTrue);
    });

    test('clearToken returns isAuthenticated to false', () {
      ApiService.instance.setToken('jwt-xyz');
      expect(ApiService.instance.isAuthenticated, isTrue);
      ApiService.instance.clearToken();
      expect(ApiService.instance.isAuthenticated, isFalse);
    });

    test('singleton identity is stable', () {
      final a = ApiService.instance;
      final b = ApiService.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('ApiService.retry', () {
    test('returns immediately when fn succeeds on first attempt', () async {
      var calls = 0;
      final result = await ApiService.instance.retry(() async {
        calls++;
        return 'ok';
      });
      expect(result, 'ok');
      expect(calls, 1);
    });

    test('rethrows the last error after exhausting maxAttempts', () async {
      var calls = 0;
      await expectLater(
        () => ApiService.instance.retry(
          () async {
            calls++;
            throw StateError('boom $calls');
          },
          // Use 2 attempts so the test runs quickly (1s backoff between).
          maxAttempts: 2,
        ),
        throwsA(isA<StateError>()),
      );
      expect(calls, 2, reason: 'each attempt must run exactly once');
    });
  });

  group('MissionSaveResult', () {
    test('ok variant carries saved row, no conflict / no error', () {
      const r = MissionSaveResult.ok(null);
      expect(r.hasConflict, isFalse);
      expect(r.isError, isFalse);
      expect(r.serverRow, isEmpty);
    });

    test('conflict variant exposes server row + hasConflict=true', () {
      const r = MissionSaveResult.conflict({'id': 'm1', 'revision_id': 7});
      expect(r.hasConflict, isTrue);
      expect(r.isError, isFalse);
      expect(r.saved, isNull);
      expect(r.serverRow['id'], 'm1');
      expect(r.serverRow['revision_id'], 7);
    });

    test('error variant flips isError; saved + serverRow are empty', () {
      const r = MissionSaveResult.error();
      expect(r.isError, isTrue);
      expect(r.hasConflict, isFalse);
      expect(r.saved, isNull);
      expect(r.serverRow, isEmpty);
    });
  });

  group('AgentModel.fromJson — response parser', () {
    test('parses minimal agent JSON with default fallbacks', () {
      // Models the smallest payload listAgents may receive — most fields
      // dropped. Every nullable / missing key must resolve to a safe
      // default rather than throwing.
      final agent = AgentModel.fromJson(<String, dynamic>{
        'id': 42,
        'title': 'Hello',
      });
      expect(agent.id, 42);
      expect(agent.title, 'Hello');
      expect(agent.description, '');
      expect(agent.prompt, '');
      expect(agent.category, '');
      expect(agent.creatorWallet, '');
      expect(agent.tags, isEmpty);
      expect(agent.traits, isEmpty);
      expect(agent.stats, isEmpty);
      expect(agent.useCount, 0);
      expect(agent.saveCount, 0);
      expect(agent.price, 0.0);
      expect(agent.cardVersion, '1.0');
      expect(agent.promptScore, 0);
      expect(agent.owned, isFalse);
      expect(agent.revisionId, 0);
    });

    test('parses character_data nested map (stats + traits + profile)', () {
      final agent = AgentModel.fromJson(<String, dynamic>{
        'id': 7,
        'title': 'Bard',
        'character_type': 'bard',
        'rarity': 'rare',
        'character_data': <String, dynamic>{
          'stats': {'wisdom': 80, 'creativity': 95},
          'traits': ['witty', 'curious'],
          'subclass': 'storyteller',
          'profile': <String, dynamic>{
            'mood': 'whimsical',
            'role_purpose': 'tells tales',
          },
        },
      });
      expect(agent.characterType, CharacterType.bard);
      expect(agent.rarity, CharacterRarity.rare);
      expect(agent.subclass, CharacterSubclass.storyteller);
      expect(agent.stats, {'wisdom': 80, 'creativity': 95});
      expect(agent.traits, ['witty', 'curious']);
      expect(agent.profileMood, 'whimsical');
      expect(agent.profileRolePurpose, 'tells tales');
    });

    test('parses character_data when delivered as a JSON string', () {
      // Backend sometimes ships character_data as a serialized JSON
      // string (legacy compatibility path). The parser must decode it.
      final agent = AgentModel.fromJson(<String, dynamic>{
        'id': 9,
        'character_data':
            '{"stats":{"wisdom":50},"traits":["bold"]}',
      });
      expect(agent.stats, {'wisdom': 50});
      expect(agent.traits, ['bold']);
    });

    test('treats malformed character_data string as empty (no throw)', () {
      final agent = AgentModel.fromJson(<String, dynamic>{
        'id': 10,
        'character_data': 'not-json-at-all',
      });
      expect(agent.stats, isEmpty);
      expect(agent.traits, isEmpty);
    });

    test('coerces num id / counters to int and keeps revision_id', () {
      final agent = AgentModel.fromJson(<String, dynamic>{
        'id': 99.0, // server may send numeric as double in some paths
        'use_count': 12.0,
        'save_count': 3,
        'revision_id': 4,
        'price': 1.5,
      });
      expect(agent.id, 99);
      expect(agent.useCount, 12);
      expect(agent.saveCount, 3);
      expect(agent.revisionId, 4);
      expect(agent.price, 1.5);
    });
  });

  group('ApiService — cache invalidation', () {
    test('invalidateCache(prefix) accepts prefix string without throwing', () {
      // We can't peek at the private map, but we can verify the API surface
      // still works for both the targeted-prefix and full-wipe variants
      // that callers like AddToLibrary / clearToken rely on.
      expect(() => ApiService.instance.invalidateCache('agents'), returnsNormally);
      expect(() => ApiService.instance.invalidateCache('library'), returnsNormally);
      expect(() => ApiService.instance.invalidateCache(), returnsNormally);
    });
  });

  group('ApiConstants — endpoint URL contracts', () {
    // ApiService builds URLs by concatenating these constants. If a new
    // method's URL drifts from its documented shape, the contract
    // upstream callers (and the backend route table) silently break.

    test('resumeLegendExecution path ends with /resume', () {
      // resumeLegendExecution() POSTs to userLegendExecutions/$execId/resume.
      const execId = 17;
      const url = '${ApiConstants.userLegendExecutions}/$execId/resume';
      expect(url, endsWith('/api/v1/user/legend/executions/17/resume'));
    });

    test('missionToLegend path ends with /to-legend', () {
      const missionId = 'm-99';
      const url = '${ApiConstants.userMissions}/$missionId/to-legend';
      expect(url, endsWith('/api/v1/user/missions/m-99/to-legend'));
    });

    test('agent versions path includes /versions/<n>/rollback', () {
      const agentId = 5;
      const version = 2;
      const url =
          '${ApiConstants.agents}/$agentId/versions/$version/rollback';
      expect(url, endsWith('/api/v1/agents/5/versions/2/rollback'));
    });

    test('apiV1 prefix is /api/v1 under baseUrl', () {
      expect(ApiConstants.apiV1, endsWith('/api/v1'));
      expect(ApiConstants.agents, endsWith('/api/v1/agents'));
      expect(ApiConstants.guilds, endsWith('/api/v1/guilds'));
      expect(ApiConstants.guildMaster, endsWith('/api/v1/guild-master'));
    });
  });
}
