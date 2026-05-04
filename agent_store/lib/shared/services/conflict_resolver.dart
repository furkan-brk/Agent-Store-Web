// Centralized 409 (optimistic concurrency) handling for any PATCH that
// uses an If-Match revision header.
//
// The project uses `package:http` (not Dio), so the spec's
// `DioException(statusCode: 409)` contract is replaced with a sentinel
// [ConflictException] that the request callback throws when it sees a 409
// response. Callers wrap their PATCH like so:
//
//   final updated = await ConflictResolver().resolve<AgentModel>(
//     context: context,
//     currentRevision: card.revision,
//     parseResource: AgentModel.fromJson,
//     resourceTypeLabel: 'agent card',
//     localLabel: 'Your draft',
//     mergePreviewBuilder: (mine, theirs) => MyMergePreview(mine, theirs),
//     request: (ifMatch) async {
//       final r = await http.patch(uri, headers: { 'If-Match': '$ifMatch' }, body: jsonEncode(payload));
//       if (r.statusCode == 409) {
//         throw ConflictException(jsonDecode(r.body) as Map<String, dynamic>);
//       }
//       if (r.statusCode != 200) throw Exception('PATCH failed');
//       return AgentModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
//     },
//   );

import 'package:flutter/widgets.dart';

import '../widgets/conflict_dialog.dart';

/// Thrown by the [ConflictResolver.resolve] request callback when the server
/// returns 409. Carries the latest server resource (from the response body)
/// so the resolver can compare and merge.
class ConflictException implements Exception {
  final Map<String, dynamic> latestServerJson;
  final DateTime? serverUpdatedAt;
  ConflictException(this.latestServerJson, {this.serverUpdatedAt});
}

/// Thrown when the user picks "Cancel" in the conflict dialog. Callers should
/// catch this and revert to the un-PATCHed local state.
class ConflictCancelled implements Exception {
  const ConflictCancelled();
  @override
  String toString() => 'ConflictCancelled';
}

/// User's choice in the conflict dialog. Returned by [showConflictDialog],
/// consumed by [ConflictResolver.resolve].
enum ConflictResolution { keepMine, takeTheirs, merge, cancel }

/// Wraps an optimistic-concurrency PATCH and routes 409 responses through
/// the [ConflictDialog]. Pure dispatch — no network or state of its own.
class ConflictResolver {
  /// Calls [request] with [currentRevision]. On [ConflictException] opens the
  /// dialog and resolves based on the user's choice:
  ///
  ///   * keepMine    -> re-PATCH with the latest revision from the server
  ///   * takeTheirs  -> return the server's resource, drop local edits
  ///   * merge       -> show [mergePreviewBuilder]; user re-runs the request
  ///                    against the merged version (today: same as keepMine,
  ///                    consumers can layer richer merging on top)
  ///   * cancel      -> throw [ConflictCancelled]
  ///
  /// [parseResource] turns the server JSON into [T] for both the take-theirs
  /// path and the new revision used by keep-mine.
  Future<T> resolve<T>({
    required BuildContext context,
    required Future<T> Function(int? ifMatch) request,
    required int currentRevision,
    required T Function(Map<String, dynamic>) parseResource,
    required String localLabel,
    required String resourceTypeLabel,
    Widget Function(T mine, T theirs)? mergePreviewBuilder,
    int Function(Map<String, dynamic>)? extractRevision,
  }) async {
    try {
      return await request(currentRevision);
    } on ConflictException catch (e) {
      final theirs = parseResource(e.latestServerJson);
      final newRevision = extractRevision != null
          ? extractRevision(e.latestServerJson)
          : (e.latestServerJson['revision'] as int?) ?? currentRevision + 1;

      if (!context.mounted) {
        // Caller's BuildContext was unmounted while we waited on the network.
        // Surface as cancellation — there's nowhere to render the dialog.
        throw const ConflictCancelled();
      }

      final choice = await showConflictDialog(
        context,
        resourceTypeLabel: resourceTypeLabel,
        localLabel: localLabel,
        serverUpdatedAt: e.serverUpdatedAt,
      );

      switch (choice) {
        case ConflictResolution.keepMine:
          // Re-issue the PATCH using the server's latest revision so the
          // If-Match header passes this time.
          return await request(newRevision);
        case ConflictResolution.takeTheirs:
          return theirs;
        case ConflictResolution.merge:
          // For now merge is treated like keepMine; the preview builder is
          // a hook for richer per-feature merging in v3.7-4.2 (Card Editor).
          if (mergePreviewBuilder == null) {
            return await request(newRevision);
          }
          // Future enhancement: render mergePreviewBuilder(mine, theirs) and
          // let the user assemble a merged payload before re-PATCHing.
          return await request(newRevision);
        case ConflictResolution.cancel:
          throw const ConflictCancelled();
      }
    }
  }
}
