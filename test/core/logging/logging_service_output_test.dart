import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

/// Records every event the logger emits.
class _RecordingOutput extends LogOutput {
  final events = <OutputEvent>[];

  @override
  void output(OutputEvent event) => events.add(event);
}

// koniz-dev/flutter-starter#576: through the injected output a test sees the
// level and the formatted text each call produced, so logging an error as a
// warning (or any other level swap) fails here.
void main() {
  late _RecordingOutput output;
  late LoggingService service;

  setUp(() {
    output = _RecordingOutput();
    service = LoggingService(enableLogging: true, output: output);
  });

  OutputEvent single() {
    expect(output.events, hasLength(1));
    return output.events.single;
  }

  test('the injected output replaces every built-in output', () {
    expect(service.outputs, [same(output)]);
  });

  test('debug logs at Level.debug with the context appended', () {
    service.debug('d-msg', context: {'k': 'v'});

    final event = single();
    expect(event.level, Level.debug);
    expect(event.origin.message, 'd-msg | Context: {"k":"v"}');
    expect(event.lines.join('\n'), contains('d-msg | Context: {"k":"v"}'));
  });

  test('info logs at Level.info with the bare message', () {
    service.info('i-msg');

    final event = single();
    expect(event.level, Level.info);
    expect(event.origin.message, 'i-msg');
    expect(event.lines.join('\n'), contains('i-msg'));
  });

  test('warning logs at Level.warning and carries the error', () {
    final error = StateError('w-err');
    service.warning('w-msg', error: error);

    final event = single();
    expect(event.level, Level.warning);
    expect(event.origin.message, 'w-msg');
    expect(event.origin.error, same(error));
    final text = event.lines.join('\n');
    expect(text, contains('w-msg'));
    expect(text, contains('w-err'));
  });

  test('error logs at Level.error and carries the error', () {
    final error = StateError('e-err');
    service.error('e-msg', context: {'n': 1}, error: error);

    final event = single();
    expect(event.level, Level.error);
    expect(event.origin.message, 'e-msg | Context: {"n":1}');
    expect(event.origin.error, same(error));
    final text = event.lines.join('\n');
    expect(text, contains('e-msg | Context: {"n":1}'));
    expect(text, contains('e-err'));
  });

  test('a disabled service never reaches the injected output', () {
    LoggingService(enableLogging: false, output: output)
      ..debug('x')
      ..info('x')
      ..warning('x')
      ..error('x');

    expect(output.events, isEmpty);
  });
}
