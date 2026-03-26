#!/usr/bin/env dart
// Script uses print for CLI output
// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  print('--- GitHub Actions Configuration ---');
  print(
    'Do you want to enable automatic CI/CD triggers on push/pull_request? (y/N)',
  );

  final input = stdin.readLineSync()?.toLowerCase();
  // Assume yes if running with --yes argument
  if (input == 'y' || input == 'yes' || args.contains('--yes')) {
    enableCI();
  } else {
    print('Setup cancelled. CI defaults to manual dispatch.');
  }
}

void enableCI() {
  final dir = Directory('.github/workflows');
  if (!dir.existsSync()) {
    print(
      'Error: .github/workflows not found. Run this script from the project root.',
    );
    return;
  }

  final files = dir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.yml'),
  );
  for (final file in files) {
    var content = file.readAsStringSync();

    // Uncomment push and pull_request
    content = content.replaceAll(RegExp(r'#\s*push:'), 'push:');
    content = content.replaceAll(
      RegExp(r'#\s*branches: \[ main, develop \]  # Uncomment'),
      'branches: [ main, develop ]  # Uncomment',
    );
    content = content.replaceAll(RegExp(r'#\s*pull_request:'), 'pull_request:');

    file.writeAsStringSync(content);
    print('Enabled triggers for: ${file.uri.pathSegments.last}');
  }
  print('Done! Commit these changes to activate CI/CD.');
}
