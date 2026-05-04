// test/unit/openclaw_export_test.dart
//
// Tests for ClaudeExportService OpenClaw methods:
//   generateOpenclawSkill, parseOpenclawSkill, isOpenclawSkill,
//   generateOpenclawWorkspace.
//
// Does NOT import dart:js_interop or package:web — safe for `flutter test`.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_store/features/legend/services/claude_export_service.dart';
import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/shared/models/agent_model.dart';
import 'package:agent_store/features/legend/models/workflow_models.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

AgentModel _makeAgent({
  int id = 42,
  String title = 'My Test Agent',
  String description = 'A helpful test agent.',
  String prompt = 'You are a test agent.\nBe helpful.',
  String category = 'Development',
  String? serviceDescription,
  List<String> tags = const ['test', 'dev'],
}) {
  return AgentModel(
    id: id,
    title: title,
    description: description,
    prompt: prompt,
    category: category,
    creatorWallet: '0xdeadbeef',
    characterType: CharacterType.wizard,
    subclass: CharacterSubclass.archmage,
    rarity: CharacterRarity.epic,
    stats: const {},
    traits: const [],
    tags: tags,
    useCount: 0,
    saveCount: 0,
    price: 0,
    createdAt: DateTime(2024),
    serviceDescription: serviceDescription,
  );
}

LegendWorkflow _makeWorkflow(List<AgentModel> agents) {
  final nodes = <WorkflowNode>[
    WorkflowNode(id: 'start_0', type: WorkflowNodeType.start, label: 'START', x: 50, y: 200),
    ...agents.asMap().entries.map((e) => WorkflowNode(
          id: 'agent_${e.key}',
          type: WorkflowNodeType.agent,
          label: e.value.title,
          refId: e.value.id.toString(),
          x: 300.0 + e.key * 200,
          y: 200,
        )),
    WorkflowNode(id: 'end_0', type: WorkflowNodeType.end, label: 'END', x: 800, y: 200),
  ];
  return LegendWorkflow(
    id: 'test-wf',
    name: 'Test Workflow',
    nodes: nodes,
    edges: const [],
    updatedAt: DateTime(2024),
  );
}

// ── generateOpenclawSkill ─────────────────────────────────────────────────────

void main() {
  group('generateOpenclawSkill', () {
    test('starts with --- frontmatter', () {
      final a = _makeAgent();
      final md = ClaudeExportService.generateOpenclawSkill(a);
      expect(md, startsWith('---\n'));
    });

    test('frontmatter is closed by ---', () {
      final a = _makeAgent();
      final md = ClaudeExportService.generateOpenclawSkill(a);
      // After the opening ---, there should be a second ---
      final rest = md.substring(4);
      expect(rest, contains('---\n'));
    });

    test('name field is slug of title', () {
      final a = _makeAgent(title: 'My Test Agent!');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      expect(md, contains('name: my-test-agent\n'));
    });

    test('contains required frontmatter fields', () {
      final a = _makeAgent();
      final md = ClaudeExportService.generateOpenclawSkill(a);
      for (final field in [
        'version: 1.0.0',
        'when_to_use: |',
        'model: opus',
        'metadata:',
        '  openclaw:',
        'agent_store:',
        '  id: 42',
        '  character_type: wizard',
        '  subclass: archmage',
        '  rarity: epic',
        '  category: Development',
      ]) {
        expect(md, contains(field), reason: 'Missing field: $field');
      }
    });

    test('tags rendered as YAML inline list', () {
      final a = _makeAgent(tags: ['alpha', 'beta']);
      final md = ClaudeExportService.generateOpenclawSkill(a);
      expect(md, contains('  tags: ["alpha", "beta"]'));
    });

    test('empty tags render as []', () {
      final a = _makeAgent(tags: []);
      final md = ClaudeExportService.generateOpenclawSkill(a);
      expect(md, contains('  tags: []'));
    });

    test('prompt is preserved verbatim in body', () {
      final a = _makeAgent(prompt: 'Line 1\nLine 2\nLine 3');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final parts = md.split('---\n');
      expect(parts.length, greaterThanOrEqualTo(3));
      final body = parts.sublist(2).join('---\n');
      expect(body, contains('Line 1\nLine 2\nLine 3'));
    });

    test('body contains # Title heading', () {
      final a = _makeAgent(title: 'My Test Agent');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      expect(md, contains('# My Test Agent\n'));
    });

    test('ends with newline even when prompt has none', () {
      final a = _makeAgent(prompt: 'No trailing newline');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      expect(md, endsWith('\n'));
    });

    test('description is single-line', () {
      final a = _makeAgent(description: 'Line 1\nLine 2\nLine 3');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final descLine = md.split('\n').firstWhere((l) => l.startsWith('description:'));
      expect(descLine, isNot(contains('\n')));
    });

    test('description truncated at 200 chars', () {
      final a = _makeAgent(description: 'x' * 300);
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final descLine = md.split('\n').firstWhere((l) => l.startsWith('description:'));
      // description: "<200-or-less chars>..."
      expect(descLine.length, lessThanOrEqualTo(220));
    });

    test('uses serviceDescription as when_to_use when present', () {
      final a = _makeAgent(serviceDescription: 'Use when you need A or B.');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      expect(md, contains('  Use when you need A or B.'));
    });

    test('falls back to generated when_to_use when serviceDescription empty', () {
      final a = _makeAgent(serviceDescription: '');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      // Fallback: 'Use for <category> tasks...'
      expect(md, contains('  Use for development tasks'));
    });
  });

  // ── isOpenclawSkill ──────────────────────────────────────────────────────────

  group('isOpenclawSkill', () {
    test('returns true for valid SKILL.md content', () {
      final a = _makeAgent();
      final md = ClaudeExportService.generateOpenclawSkill(a);
      expect(ClaudeExportService.isOpenclawSkill(md), isTrue);
    });

    test('returns false for plain Claude agent .md', () {
      const plain = '---\nname: my-agent\nmodel: sonnet\n---\n\nPrompt';
      expect(ClaudeExportService.isOpenclawSkill(plain), isFalse);
    });

    test('returns false for workflow JSON', () {
      const json = '{"nodes": [], "edges": []}';
      expect(ClaudeExportService.isOpenclawSkill(json), isFalse);
    });
  });

  // ── parseOpenclawSkill ────────────────────────────────────────────────────────

  group('parseOpenclawSkill', () {
    test('round-trip: parse recovers prompt', () {
      final a = _makeAgent(prompt: 'You are a round-trip test agent.');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final result = ClaudeExportService.parseOpenclawSkill(md);
      expect(result, isNotNull);
      expect(result!.prompt, contains('You are a round-trip test agent.'));
    });

    test('round-trip: node metadata contains model', () {
      final a = _makeAgent();
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final result = ClaudeExportService.parseOpenclawSkill(md);
      expect(result, isNotNull);
      expect(result!.node.metadata?['model'], equals('opus'));
    });

    test('round-trip: heading stripped from prompt', () {
      final a = _makeAgent(title: 'My Test Agent', prompt: 'Pure prompt here.');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final result = ClaudeExportService.parseOpenclawSkill(md);
      expect(result, isNotNull);
      // The # My Test Agent heading should NOT appear in the extracted prompt
      expect(result!.prompt, isNot(contains('# My Test Agent')));
      expect(result.prompt, contains('Pure prompt here.'));
    });

    test('round-trip: character_type passed to node metadata', () {
      final a = _makeAgent();
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final result = ClaudeExportService.parseOpenclawSkill(md);
      expect(result, isNotNull);
      // characterType.name for wizard = 'wizard'
      expect(result!.node.metadata?['character_type'], equals('wizard'));
    });

    test('round-trip: category passed to node metadata', () {
      final a = _makeAgent(category: 'Development');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final result = ClaudeExportService.parseOpenclawSkill(md);
      expect(result, isNotNull);
      expect(result!.node.metadata?['category'], equals('Development'));
    });

    test('node type is agent', () {
      final a = _makeAgent();
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final result = ClaudeExportService.parseOpenclawSkill(md);
      expect(result!.node.type, equals(WorkflowNodeType.agent));
    });

    test('prompt with --- preserved', () {
      final a = _makeAgent(prompt: 'Step 1\n---\nStep 2');
      final md = ClaudeExportService.generateOpenclawSkill(a);
      final result = ClaudeExportService.parseOpenclawSkill(md);
      expect(result, isNotNull);
      // The --- inside the prompt should survive
      expect(result!.prompt, contains('Step 1'));
      expect(result.prompt, contains('Step 2'));
    });

    test('returns null for invalid content', () {
      expect(ClaudeExportService.parseOpenclawSkill('not a skill'), isNull);
      expect(ClaudeExportService.parseOpenclawSkill('---\nonly one block'), isNull);
    });
  });

  // ── generateOpenclawWorkspace ─────────────────────────────────────────────────

  group('generateOpenclawWorkspace', () {
    test('returns valid JSON', () {
      final a = _makeAgent();
      final wf = _makeWorkflow([a]);
      final json = ClaudeExportService.generateOpenclawWorkspace(wf, [a]);
      expect(() => jsonDecode(json), returnsNormally);
    });

    test('JSON has format field openclaw-workspace', () {
      final a = _makeAgent();
      final wf = _makeWorkflow([a]);
      final decoded = jsonDecode(
          ClaudeExportService.generateOpenclawWorkspace(wf, [a])) as Map<String, dynamic>;
      expect(decoded['format'], equals('openclaw-workspace'));
    });

    test('files map contains SKILL.md for agent', () {
      final a = _makeAgent(title: 'My Test Agent');
      final wf = _makeWorkflow([a]);
      final decoded = jsonDecode(
          ClaudeExportService.generateOpenclawWorkspace(wf, [a])) as Map<String, dynamic>;
      final files = decoded['files'] as Map<String, dynamic>;
      final skillKey = files.keys
          .firstWhere((k) => k.endsWith('SKILL.md'), orElse: () => '');
      expect(skillKey, isNotEmpty);
      expect(skillKey, contains('my-test-agent'));
    });

    test('files map contains team.json', () {
      final a = _makeAgent();
      final wf = _makeWorkflow([a]);
      final decoded = jsonDecode(
          ClaudeExportService.generateOpenclawWorkspace(wf, [a])) as Map<String, dynamic>;
      final files = decoded['files'] as Map<String, dynamic>;
      expect(files.keys, contains('~/.openclaw/workspace/team.json'));
    });

    test('team.json references skill slug', () {
      final a = _makeAgent(title: 'My Test Agent');
      final wf = _makeWorkflow([a]);
      final decoded = jsonDecode(
          ClaudeExportService.generateOpenclawWorkspace(wf, [a])) as Map<String, dynamic>;
      final files = decoded['files'] as Map<String, dynamic>;
      final teamJson = jsonDecode(files['~/.openclaw/workspace/team.json'] as String)
          as Map<String, dynamic>;
      final skills = teamJson['skills'] as List<dynamic>;
      expect(skills, contains('my-test-agent'));
    });

    test('agents without prompts are excluded', () {
      final withPrompt = _makeAgent(id: 1, title: 'Agent With Prompt', prompt: 'Hello');
      final noPrompt = _makeAgent(id: 2, title: 'Agent No Prompt', prompt: '');
      final wf = _makeWorkflow([withPrompt, noPrompt]);
      final decoded = jsonDecode(
          ClaudeExportService.generateOpenclawWorkspace(wf, [withPrompt, noPrompt]))
          as Map<String, dynamic>;
      final files = decoded['files'] as Map<String, dynamic>;
      final skillKeys = files.keys.where((k) => k.endsWith('SKILL.md')).toList();
      expect(skillKeys.length, equals(1));
      expect(skillKeys.first, contains('agent-with-prompt'));
    });
  });
}
