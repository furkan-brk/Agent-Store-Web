// Pure-Dart helpers for the @-mention dropdown. Lives in its own file so
// unit tests can import it without pulling MonacoEditorWidget (which
// transitively imports dart:js_interop and won't compile under
// flutter_test on non-web targets).

import '../../../shared/models/agent_model.dart';

/// Per-section caps for the @-mention dropdown: library wins 6 slots that
/// store results can never crowd out.
const int kMentionLibraryLimit = 6;
const int kMentionStoreLimit = 8;

/// Splits [agents] into "owned" (library) and "not owned" (store) buckets,
/// case-insensitively filters by [query], sorts each bucket by use count,
/// and concatenates with library first (up to the per-section caps).
List<AgentModel> filterAgentSuggestions(
  List<AgentModel> agents,
  String query,
) {
  final q = query.toLowerCase();
  final filtered =
      agents.where((a) => q.isEmpty || a.title.toLowerCase().contains(q));
  final lib = filtered.where((a) => a.owned).toList()
    ..sort((a, b) => b.useCount.compareTo(a.useCount));
  final str = filtered.where((a) => !a.owned).toList()
    ..sort((a, b) => b.useCount.compareTo(a.useCount));
  return [
    ...lib.take(kMentionLibraryLimit),
    ...str.take(kMentionStoreLimit),
  ];
}
