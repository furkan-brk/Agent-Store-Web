// lib/features/agent_detail/widgets/prompt_redaction.dart
//
// Pure-Dart helpers for the prompt preview/full toggle on the agent detail
// page. Lives in its own file so unit tests can exercise the logic
// without mounting the full screen (which imports dart:js_interop via
// `package:web`).

/// Threshold above which the prompt is preview-truncated. Below this we
/// always show the full body (no toggle).
const int kPromptPreviewThreshold = 500;

/// Returns true when [prompt] is long enough to warrant a preview/full toggle.
bool shouldOfferPromptToggle(String prompt) =>
    prompt.length > kPromptPreviewThreshold;

/// Returns the displayable body for the given [prompt]. When [showFull] is
/// true OR the prompt is short, returns it verbatim. Otherwise returns the
/// first [kPromptPreviewThreshold] characters trimmed of trailing whitespace
/// followed by an ellipsis.
String displayedPromptBody(String prompt, {required bool showFull}) {
  if (showFull || !shouldOfferPromptToggle(prompt)) return prompt;
  return '${prompt.substring(0, kPromptPreviewThreshold).trim()}…';
}
