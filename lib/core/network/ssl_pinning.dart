import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';

/// Resolved SSL certificate pinning policy for a Dio transport.
///
/// Pinning has two independent inputs - a flag and a fingerprint list - and
/// being "enabled" with an empty list silently pins nothing. This type makes
/// that distinction explicit ([isEffective] vs [enabled]) and refuses to fail
/// quietly: [createAdapter] logs and asserts when pinning is requested but
/// unenforceable.
@immutable
class SslPinning {
  /// Creates a policy from an explicit flag and fingerprint list.
  const SslPinning({required this.enabled, required this.fingerprints});

  /// Reads the policy from [AppConfig] (`ENABLE_SSL_PINNING` and
  /// `API_SSL_FINGERPRINTS`).
  factory SslPinning.fromConfig() => SslPinning(
    enabled: AppConfig.enableSslPinning,
    fingerprints: AppConfig.apiSslFingerprints,
  );

  /// Whether pinning was requested.
  final bool enabled;

  /// Accepted SHA-256 certificate fingerprints, lowercase and colon-free.
  final List<String> fingerprints;

  /// Whether pinning is actually enforced on the socket.
  ///
  /// Requesting pinning without fingerprints enforces nothing.
  bool get isEffective => enabled && fingerprints.isNotEmpty;

  /// Whether pinning was requested but cannot be enforced.
  bool get isMisconfigured => enabled && fingerprints.isEmpty;

  /// Message describing a misconfigured policy.
  static const String misconfiguredMessage =
      'SSL pinning is enabled (ENABLE_SSL_PINNING=true) but '
      'API_SSL_FINGERPRINTS is empty. Nothing is pinned: every certificate '
      'the system trust store accepts would be accepted. Configure '
      'API_SSL_FINGERPRINTS or set ENABLE_SSL_PINNING=false.';

  /// Builds the pinned [HttpClientAdapter], or `null` when pinning is not
  /// effective and the default transport should be used.
  ///
  /// When [isMisconfigured], this logs an error and trips an assertion in
  /// debug builds rather than degrading to an unpinned client in silence.
  HttpClientAdapter? createAdapter() {
    if (!enabled) {
      return null;
    }

    if (fingerprints.isEmpty) {
      debugPrint('SSL PINNING MISCONFIGURED: $misconfiguredMessage');
      assert(false, misconfiguredMessage);
      return null;
    }

    final accepted = List<String>.unmodifiable(fingerprints);
    return IOHttpClientAdapter(
      createHttpClient: () {
        // Empty trusted roots force every connection through
        // badCertificateCallback, so the fingerprint check cannot be skipped.
        return HttpClient(context: SecurityContext())
          ..badCertificateCallback = (cert, host, port) =>
              _accepts(cert, host, accepted);
      },
    );
  }

  /// Whether [cert] matches one of [fingerprints].
  ///
  /// This is the exact decision the pinned adapter installs on its
  /// [HttpClient]. It is exposed because `HttpClient.badCertificateCallback`
  /// is setter-only in `dart:io`: once installed, the check cannot be read
  /// back off the client, so there is no other way for a host-VM test to
  /// assert that a mismatched fingerprint is rejected.
  @visibleForTesting
  bool acceptsCertificate(X509Certificate cert, {String host = ''}) =>
      _accepts(cert, host, fingerprints);

  static bool _accepts(
    X509Certificate cert,
    String host,
    List<String> accepted,
  ) {
    final certHash = sha256
        .convert(cert.der)
        .toString()
        .replaceAll(':', '')
        .toLowerCase();
    final isPinned = accepted.contains(certHash);

    if (!isPinned && AppConfig.isDebugMode) {
      debugPrint(
        'SSL Pinning failure for $host: \n'
        'Expected one of: $accepted\n'
        'Got: $certHash',
      );
    }
    return isPinned;
  }
}
