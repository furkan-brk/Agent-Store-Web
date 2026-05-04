import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../../shared/models/agent_model.dart';

/// Client-side export helpers for the card editor.
///
/// JSON export is a simple `agent.toJson()` blob download. PNG export
/// reads a [RepaintBoundary] into a `ui.Image` at 3× DPR for crisp output,
/// then triggers a browser download. Both helpers are Web-only — they rely
/// on `dart:js_interop` + `package:web` and will throw on other platforms.
class CardExportService {
  const CardExportService._();

  /// Download the agent's full JSON shape (matches the backend `Agent` model).
  static void exportJson(AgentModel agent) {
    final pretty = const JsonEncoder.withIndent('  ').convert(agent.toJson());
    _download(
      bytes: Uint8List.fromList(utf8.encode(pretty)),
      filename: '${_safeName(agent.title, fallback: 'agent_${agent.id}')}.json',
      mimeType: 'application/json',
    );
  }

  /// Capture the widget tree under [boundaryKey] and download as PNG.
  /// Returns true on success. The caller passes the `GlobalKey` attached
  /// to the [RepaintBoundary] wrapping the preview card.
  static Future<bool> exportPng(
    GlobalKey boundaryKey,
    AgentModel agent, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final ctx = boundaryKey.currentContext;
      if (ctx == null) return false;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return false;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      final bytes = byteData.buffer.asUint8List();
      _download(
        bytes: bytes,
        filename: '${_safeName(agent.title, fallback: 'agent_${agent.id}')}.png',
        mimeType: 'image/png',
      );
      return true;
    } catch (e) {
      debugPrint('[CardExportService] PNG export failed: $e');
      return false;
    }
  }

  // ── Internals ───────────────────────────────────────────────────────────

  static void _download({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    // Revoke after a tick so the browser has time to start the download.
    Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  }

  static final _unsafeChars = RegExp(r'[^A-Za-z0-9._-]+');

  static String _safeName(String title, {required String fallback}) {
    final cleaned = title.trim().replaceAll(_unsafeChars, '_');
    if (cleaned.isEmpty) return fallback;
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }
}
