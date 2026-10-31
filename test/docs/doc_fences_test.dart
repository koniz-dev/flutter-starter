// The fence rules the docs scanners share: a fence closes only on a line of
// the opening character, at least as long as the opening run, with nothing
// else on it; a backtick opener cannot carry a backtick in its info string.

import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_fences.dart';

/// For each line of [text], whether it is content inside a fence.
List<bool> _inside(String text) {
  final fences = FenceTracker();
  return [
    for (final line in text.split('\n'))
      !fences.isFence(line) && fences.inFence,
  ];
}

void main() {
  test('a fence closes on the same character and at least its length', () {
    expect(_inside('````\na\n```\nb\n````\nc'), [
      false, true, true, true, false, false, //
    ]);
    expect(_inside('~~~\na\n```\nb\n~~~\nc'), [
      false, true, true, true, false, false, //
    ]);
  });

  test('a closing line carries nothing else', () {
    expect(_inside('```\na\n``` text\nb\n```\nc'), [
      false, true, true, true, false, false, //
    ]);
  });

  test('a backtick opener with a backtick in its info string is no fence', () {
    expect(_inside('```dart``` is inline\na'), [false, false]);
    expect(_inside('~~~ a`b\nc\n~~~'), [false, true, false]);
  });

  test('a fence inside a list item is still a fence', () {
    expect(_inside('1. step:\n     ```bash\n     run\n     ```\nafter'), [
      false, false, true, false, false, //
    ]);
  });
}
