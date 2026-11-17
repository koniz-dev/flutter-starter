// dio 5.11 delivers a rejected certificate - an SSL-pinning mismatch from
// SslPinning's badCertificateCallback, or an untrusted certificate - as
// DioExceptionType.unknown with a HandshakeException and a null message, not
// as badCertificate. The mapper turned it into UNKNOWN_NETWORK_ERROR, so the
// user read "Can't reach the server. Check your connection" instead of the
// insecure-connection message. This drives a real TLS handshake.
@TestOn('vm')
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/dio_exception_mapper.dart';
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_starter/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

final bool _hasOpenssl = () {
  try {
    return Process.runSync('openssl', ['version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

void main() {
  final skip = _hasOpenssl ? null : 'openssl is not installed';
  final l10n = AppLocalizationsEn();
  late Directory dir;
  late HttpServer server;
  late String url;

  setUpAll(() async {
    if (skip != null) return;
    dir = Directory.systemTemp.createTempSync('tls_mapping_');
    final made = Process.runSync('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-days',
      '1',
      '-subj',
      '/CN=127.0.0.1',
      '-keyout',
      '${dir.path}/key.pem',
      '-out',
      '${dir.path}/cert.pem',
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    final context = SecurityContext()
      ..useCertificateChain('${dir.path}/cert.pem')
      ..usePrivateKey('${dir.path}/key.pem');
    server =
        await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context)
          ..listen((request) async {
            request.response.write('{}');
            await request.response.close();
          });
    url = 'https://127.0.0.1:${server.port}/x';
  });

  tearDownAll(() async {
    if (skip != null) return;
    await server.close(force: true);
    dir.deleteSync(recursive: true);
  });

  Future<DioException> failure(Dio dio) async {
    try {
      await dio.get<dynamic>(url);
    } on DioException catch (e) {
      return e;
    }
    fail('the request succeeded');
  }

  for (final (label, makeDio) in <(String, Dio Function())>[
    (
      'a pinning mismatch',
      () => Dio()
        ..httpClientAdapter = const SslPinning(
          enabled: true,
          fingerprints: ['AA:BB'],
        ).createAdapter()!,
    ),
    ('an untrusted certificate', Dio.new),
  ]) {
    test(
      '$label is an insecure connection, not a connectivity problem',
      () async {
        final error = await failure(makeDio());
        final mapped = DioExceptionMapper.map(error);

        expect(mapped.code, 'BAD_CERTIFICATE');
        expect(
          ExceptionToFailureMapper.map(mapped).localizedMessage(l10n),
          l10n.failureInsecureConnection,
        );
      },
      skip: skip,
    );
  }

  test('a socket error with a null message is a connection error', () {
    final mapped = DioExceptionMapper.map(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const SocketException('Connection refused'),
      ),
    );

    expect(mapped.code, 'NETWORK_ERROR');
  });
}
