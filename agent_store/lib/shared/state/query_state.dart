// Bidirectional sync between GoRouter URL query params and a controller's
// reactive state. Mix into any GetxController whose state should round-trip
// through the URL (Store filters, Library tabs, etc.).
//
// Usage:
//   class StoreController extends GetxController with QueryStatePersistence {
//     @override Map<String, QueryFieldSpec> get queryFields => {
//       'q':    QueryFieldSpec.string(read: () => search.value, write: (v) => search.value = v),
//       'cat':  QueryFieldSpec.string(read: () => category.value, write: (v) => category.value = v),
//       'sort': QueryFieldSpec.string(read: () => sort.value, write: (v) => sort.value = v, defaultValue: 'newest'),
//     };
//
//     @override
//     void onReady() {
//       super.onReady();
//       hydrateFromQuery(/* current uri params */);
//       ever(search, (_) => persistToQuery());
//     }
//   }
//
// Key constraints:
//   - Empty / default-equal values are omitted from the URL (clean URLs).
//   - persistToQuery is debounced 200 ms; rapid edits coalesce into one push.
//   - hydrateFromQuery is guarded against re-entry while persistToQuery is
//     mid-push, so the round-trip never loops.

import 'dart:async';

import 'package:get/get.dart';

/// Describes a single URL query field: how to read it from controller state,
/// how to encode/decode it, and what its absent-value default is.
///
/// Construct directly for custom value types, or use the [QueryFieldSpecs]
/// helpers for the common String / int / List<String> cases.
class QueryFieldSpec<T> {
  final T Function() read;
  final void Function(T) write;
  final String Function(T) encode;
  final T Function(String) decode;
  final T defaultValue;

  const QueryFieldSpec({
    required this.read,
    required this.write,
    required this.encode,
    required this.decode,
    required this.defaultValue,
  });

  /// Encodes the current value of [read] to a URL string. Defined on the
  /// spec (rather than inline at the call site) so the typed `encode(T)`
  /// closure isn't forced through the dynamic boundary of
  /// `Map<String, QueryFieldSpec>` — Dart's generic erasure would otherwise
  /// turn the typed parameter into `dynamic` and crash at runtime.
  String encodeCurrent() => encode(read());

  /// Decodes [raw] (a URL string) and writes the typed result via [write].
  /// Same dynamic-boundary rationale as [encodeCurrent].
  void writeFromString(String raw) => write(decode(raw));
}

/// Convenience builders for the typical query field shapes.
class QueryFieldSpecs {
  /// String field. A value equal to [defaultValue] is omitted from the URL.
  static QueryFieldSpec<String> string({
    required String Function() read,
    required void Function(String) write,
    String defaultValue = '',
  }) {
    return QueryFieldSpec<String>(
      read: read,
      write: write,
      defaultValue: defaultValue,
      encode: (v) => v == defaultValue ? '' : v,
      decode: (s) => s.isEmpty ? defaultValue : s,
    );
  }

  /// Int field. Malformed input falls back to [defaultValue].
  static QueryFieldSpec<int> int_({
    required int Function() read,
    required void Function(int) write,
    int defaultValue = 0,
  }) {
    return QueryFieldSpec<int>(
      read: read,
      write: write,
      defaultValue: defaultValue,
      encode: (v) => v == defaultValue ? '' : '$v',
      decode: (s) {
        if (s.isEmpty) return defaultValue;
        return int.tryParse(s) ?? defaultValue;
      },
    );
  }

  /// Comma-separated string list. Empty list is omitted from the URL.
  static QueryFieldSpec<List<String>> stringList({
    required List<String> Function() read,
    required void Function(List<String>) write,
  }) {
    return QueryFieldSpec<List<String>>(
      read: read,
      write: write,
      defaultValue: const <String>[],
      encode: (v) => v.isEmpty ? '' : v.join(','),
      decode: (s) {
        if (s.isEmpty) return const <String>[];
        return s.split(',').where((e) => e.isNotEmpty).toList();
      },
    );
  }
}

mixin QueryStatePersistence on GetxController {
  /// Override to declare which keys persist.
  Map<String, QueryFieldSpec> get queryFields;

  /// Returns the current URI as a string. Consumers (Store, Library, ...)
  /// override this to read from `AppRouter.router.routerDelegate.currentConfiguration`.
  /// Tests inject a fake. Kept abstract here so the mixin's compile graph
  /// stays free of `package:web` / `dart:js_interop` (which `flutter test`
  /// can't load on non-web targets).
  String currentUriString();

  /// Pushes a new URL. Consumers typically wire this to
  /// `AppRouter.router.replace(uri)` so the back stack stays clean.
  void pushUri(String uri);

  Timer? _debounceTimer;
  bool _suppressHydrate = false;

  static const _debounceDuration = Duration(milliseconds: 200);

  /// Reads [queryParameters] (typically from `GoRouterState.uri.queryParameters`)
  /// and seeds matching controller fields via their decoders. Missing keys use
  /// the spec's default. Should be called once during `onReady`.
  void hydrateFromQuery(Map<String, String> queryParameters) {
    if (_suppressHydrate) return;
    queryFields.forEach((key, spec) {
      final raw = queryParameters[key] ?? '';
      spec.writeFromString(raw);
    });
  }

  /// Schedules a debounced write of all tracked fields to the URL. Successive
  /// calls within 200 ms collapse into a single push.
  void persistToQuery() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _flushToQuery);
  }

  /// Bypasses the debounce timer and pushes immediately. Useful for
  /// "clear filters" or any action that should land in the URL synchronously.
  void persistToQueryNow() {
    _debounceTimer?.cancel();
    _flushToQuery();
  }

  void _flushToQuery() {
    final newParams = <String, String>{};
    queryFields.forEach((key, spec) {
      final encoded = spec.encodeCurrent();
      if (encoded.isNotEmpty) {
        newParams[key] = encoded;
      }
    });

    final currentUri = Uri.parse(currentUriString());
    if (_paramsMatch(currentUri.queryParameters, newParams)) {
      // No-op write — URL already reflects state, don't trigger a navigation.
      return;
    }

    final nextUri = currentUri.replace(
      queryParameters: newParams.isEmpty ? null : newParams,
    );

    _suppressHydrate = true;
    try {
      pushUri(nextUri.toString());
    } finally {
      _suppressHydrate = false;
    }
  }

  bool _paramsMatch(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }
}
