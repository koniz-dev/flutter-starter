@TestOn('!windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _SecureStorage extends Mock implements SecureStorageService {}

class _ProxyOverrides extends HttpOverrides {
  _ProxyOverrides(this.port);

  final int port;

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) =>
      'PROXY 127.0.0.1:$port';
}

/// A CONNECT proxy: answers 200 and then pipes bytes both ways.
Future<(ServerSocket, List<String>)> _connectProxy() async {
  final requests = <String>[];
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((client) {
    var piped = false;
    final buffer = <int>[];
    Socket? upstream;
    client.listen((data) async {
      if (piped) {
        upstream!.add(data);
        return;
      }
      buffer.addAll(data);
      final head = latin1.decode(buffer);
      if (!head.contains('\r\n\r\n')) return;
      piped = true;
      final line = head.split('\r\n').first;
      requests.add(line);
      final target = line.split(' ')[1].split(':');
      upstream = await Socket.connect(target[0], int.parse(target[1]));
      upstream!.listen(client.add, onDone: client.destroy);
      client.add(latin1.encode('HTTP/1.1 200 Connection established\r\n\r\n'));
    }, onDone: () => upstream?.destroy());
  });
  return (server, requests);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late HttpServer secure;
  late HttpServer target;
  late HttpServer plain;
  late String fingerprint;
  var plainRequests = 0;
  var loads = 0;

  Future<void> loadEnv(String environment) async {
    final name = 'api_redirect_env_${loads++}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          if (utf8.decode(message!.buffer.asUint8List()) != name) return null;
          final bytes = Uint8List.fromList(
            utf8.encode('ENVIRONMENT=$environment\n'),
          );
          return ByteData.view(bytes.buffer);
        });
    await EnvConfig.load(fileName: name);
  }

  ApiClient client({bool releaseMode = true, bool pin = true}) {
    final tokenStore = InMemoryTokenStore();
    final api = ApiClient(
      storageService: InMemoryStorage(),
      secureStorageService: _SecureStorage(),
      authInterceptor: AuthInterceptor(
        tokenStore: tokenStore,
        refreshToken: () async => const Success('token'),
      ),
      sslPinning: SslPinning(enabled: pin, fingerprints: [fingerprint]),
      releaseMode: releaseMode,
      retryInitialDelay: Duration.zero,
      retryMaxJitter: Duration.zero,
    );
    addTearDown(() => api.dio.close(force: true));
    return api;
  }

  setUpAll(() async {
    HttpOverrides.global = null;
    dir = Directory.systemTemp.createTempSync('api_redirect_');
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
      '-addext',
      'subjectAltName=IP:127.0.0.1',
      '-keyout',
      '${dir.path}/key.pem',
      '-out',
      '${dir.path}/cert.pem',
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    final pem = File('${dir.path}/cert.pem')
        .readAsStringSync()
        .split('\n')
        .where((line) => line.isNotEmpty && !line.startsWith('-----'))
        .join();
    fingerprint = sha256.convert(base64.decode(pem)).toString();
    final context = SecurityContext()
      ..useCertificateChain('${dir.path}/cert.pem')
      ..usePrivateKey('${dir.path}/key.pem');
    plain = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((request) async {
        plainRequests++;
        request.response.write('cleartext');
        await request.response.close();
      });
    target =
        await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context)
          ..listen((request) async {
            request.response.write('TLS');
            await request.response.close();
          });
    secure =
        await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context)
          ..listen((request) async {
            final destination = request.uri.path == '/downgrade'
                ? 'http://127.0.0.1:${plain.port}/body'
                : 'https://127.0.0.1:${target.port}/body';
            await request.response.redirect(Uri.parse(destination));
          });
  });

  tearDownAll(() async {
    await secure.close(force: true);
    await target.close(force: true);
    await plain.close(force: true);
    dir.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    HttpOverrides.global = null;
  });

  for (final environment in ['production', 'staging']) {
    test(
      '$environment release rejects HTTPS to HTTP before the plain request',
      () async {
        await loadEnv(environment);
        plainRequests = 0;
        await expectLater(
          client().get('https://127.0.0.1:${secure.port}/downgrade'),
          throwsA(isA<Exception>()),
        );
        expect(plainRequests, 0);
      },
    );
  }
  test(
    'production release follows HTTPS to HTTPS with the same pins',
    () async {
      await loadEnv('production');
      final response = await client().get(
        'https://127.0.0.1:${secure.port}/secure',
      );
      expect(response.statusCode, 200);
      expect(response.data, 'TLS');
    },
  );
  test('debug retains HTTP redirect behavior', () async {
    await loadEnv('production');
    plainRequests = 0;
    final response = await client(releaseMode: false)
        .get('https://127.0.0.1:${secure.port}/downgrade');
    expect(response.data, 'cleartext');
    expect(plainRequests, 1);
  });
  test(
    'HTTPS through CONNECT retains pinning and redirect scheme checks',
    () async {
      await loadEnv('production');
      final (proxy, requests) = await _connectProxy();
      addTearDown(proxy.close);
      HttpOverrides.global = _ProxyOverrides(proxy.port);
      addTearDown(() => HttpOverrides.global = null);
      final api = client();
      expect(
        (await api.get('https://127.0.0.1:${secure.port}/secure')).data,
        'TLS',
      );
      plainRequests = 0;
      await expectLater(
        api.get('https://127.0.0.1:${secure.port}/downgrade'),
        throwsA(isA<Exception>()),
      );
      expect(plainRequests, 0);
      expect(requests, contains('CONNECT 127.0.0.1:${target.port} HTTP/1.1'));
    },
  );
  test(
    'scheme guard also applies without pinning to an initial HTTP URL',
    () async {
      await loadEnv('production');
      plainRequests = 0;
      await expectLater(
        client(pin: false).get('http://127.0.0.1:${plain.port}/body'),
        throwsA(isA<Exception>()),
      );
      expect(plainRequests, 0);
    },
  );
}
