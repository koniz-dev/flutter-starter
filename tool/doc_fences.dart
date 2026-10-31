// Fenced code blocks in markdown, tracked the way CommonMark does.
//
// The docs scanners toggled their "inside a fence" state on every line that
// started with three backticks or tildes. A ``` line inside a `~~~` block, or
// inside a four-backtick block, flipped them, and every command after it was
// read as prose and every paragraph as a command.

/// A line that looks like a fence: three or more backticks or tildes.
final RegExp fenceLike = RegExp(r'^\s*(`{3,}|~{3,})');

final RegExp _closing = RegExp(r'^\s*(`{3,}|~{3,})\s*$');

/// Follows the fences of one markdown file, line by line.
///
/// A fence closes only on a line of the opening character, at least as long
/// as the opening run, with nothing else on it.
class FenceTracker {
  String? _open;

  /// Whether the last line fed to [isFence] left a fence open.
  bool get inFence => _open != null;

  /// Feeds [line]: whether it opens or closes a fence, and so is not content.
  bool isFence(String line) {
    final open = _open;
    if (open == null) {
      final match = fenceLike.firstMatch(line);
      if (match == null) return false;
      _open = match.group(1);
      return true;
    }
    final run = _closing.firstMatch(line)?.group(1);
    if (run == null || run[0] != open[0] || run.length < open.length) {
      return false;
    }
    _open = null;
    return true;
  }
}
