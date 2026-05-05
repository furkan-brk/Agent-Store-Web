// lib/shared/state/bulk_select_state.dart
//
// v3.11.3 — T10 — Pure helper backing the multi-select toolbar across
// Library and Creator Dashboard. Lives outside the widget tree so the
// state machine can be unit-tested without booting Flutter.

import 'package:flutter/foundation.dart';

class BulkSelectState extends ChangeNotifier {
  final Set<int> _ids = <int>{};
  bool _active = false;

  /// True when the user has activated select mode (Checkbox overlay visible).
  bool get isActive => _active;

  /// Defensive read-only view of the selected ids.
  Set<int> get selectedIds => Set.unmodifiable(_ids);

  /// Convenience for the bottom action bar copy.
  int get selectedCount => _ids.length;

  bool isSelected(int id) => _ids.contains(id);

  void enter() {
    if (_active) return;
    _active = true;
    notifyListeners();
  }

  void exit() {
    if (!_active && _ids.isEmpty) return;
    _active = false;
    _ids.clear();
    notifyListeners();
  }

  void toggle(int id) {
    if (!_active) _active = true;
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    notifyListeners();
  }

  void selectAll(Iterable<int> ids) {
    _active = true;
    _ids
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void deselectAll() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}
