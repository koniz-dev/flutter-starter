// Fenced code blocks in markdown, opened and closed by CommonMark's rules for
// the fence itself.
//
// The docs scanners toggled their "inside a fence" state on every line that
// started with three backticks or tildes. A ``` line inside a `~~~` block, or
// inside a four-backtick block, flipped them, and every command after it was
// read as prose and every paragraph as a command.
//
// Indentation is not modelled: a fence inside a list item is indented by the
// item's content, which only a full CommonMark parser could measure, so any
// indent is accepted.

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
      final run = match.group(1)!;
      // A backtick fence's info string cannot hold a backtick: "```dart```"
      // is inline code, not a fence.
      if (run[0] == '`' && line.substring(match.end).contains('`')) {
        return false;
      }
      _open = run;
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
