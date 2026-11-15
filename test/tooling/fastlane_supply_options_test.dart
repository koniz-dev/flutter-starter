@TestOn('!windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Options used by these lanes and their credential examples; extend this
// reviewed list when adding a documented option. Verified 2026-11-15:
// https://docs.fastlane.tools/actions/upload_to_play_store/#parameters
const _supplyOptions = {
  'package_name',
  'release_status',
  'track',
  'metadata_path',
  'json_key',
  'json_key_data',
  'aab',
  'skip_upload_apk',
  'skip_upload_aab',
  'skip_upload_metadata',
  'skip_upload_changelogs',
  'skip_upload_images',
  'skip_upload_screenshots',
};

// Evaluate the real lane bodies, recording action arguments while builds and
// uploads are inert. Registering every lane does not execute its block.
const _captureUploads = r'''
require 'json'
$lanes = {}
$uploads = []
def default_platform(*) end
def platform(*) yield end
def desc(*) end
def lane(name, &body) $lanes[name] = body end
def build_bundle(**options) 'fixture.aab' end
def upload_to_play_store(**options) $uploads << options end
module UI
  def self.success(*) end
end
load ARGV.fetch(0)
$lanes.each do |name, body|
  next unless name.to_s.start_with?('upload')
  body.call(environment: 'production', base_url: 'https://api.release.test',
            track: 'beta', ssl_pinning: 'false')
end
puts JSON.generate($uploads)
''';

void main() {
  final hasRuby = () {
    try {
      return Process.runSync('ruby', ['--version']).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }();
  final skip = hasRuby ? null : 'Ruby is not installed';
  late List<Map<String, dynamic>> uploads;

  setUpAll(() async {
    if (!hasRuby) return;
    final result = await Process.run('ruby', [
      '-e',
      _captureUploads,
      File('fastlane/Fastfile').absolute.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    uploads = (jsonDecode('${result.stdout}') as List<dynamic>)
        .map(
          (entry) => Map<String, dynamic>.from(entry as Map<dynamic, dynamic>),
        )
        .toList();
  });

  test('every Play upload call uses documented supply options', () {
    final calls = RegExp(r'\bupload_to_play_store\s*\(')
        .allMatches(File('fastlane/Fastfile').readAsStringSync())
        .length;
    expect(calls, 5);
    expect(uploads, hasLength(calls));
    for (final upload in uploads) {
      expect(upload.keys.toSet().difference(_supplyOptions), isEmpty);
      expect(upload['aab'], 'fixture.aab');
      expect(upload['package_name'], isNotEmpty);
    }
  }, skip: skip);

  test('the generic upload points supply at the Android metadata root', () {
    final metadataUploads = uploads.where(
      (u) => u.containsKey('metadata_path'),
    );
    expect(metadataUploads, hasLength(1));
    final upload = metadataUploads.single;
    expect(
      upload['metadata_path'],
      Directory('fastlane/metadata/android').absolute.path,
    );
    expect(upload['skip_upload_metadata'], isTrue);
    // Supply treats changelogs separately from listing metadata.
    expect(upload['skip_upload_changelogs'], isNot(true));
  }, skip: skip);
}
