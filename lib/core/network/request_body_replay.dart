import 'package:dio/dio.dart';

/// What a replayed request may send as its body.
///
/// Two interceptors send a request a second time: `AuthInterceptor` after a
/// successful 401 refresh, and `RetryInterceptor` after a transient failure.
/// Both used to pass the original body object straight back to dio. That is
/// fine for a `Map`, a `String`, a `List` or bytes, which dio encodes afresh on
/// every send. It is not fine for:
///
/// * a [FormData]: dio finalizes it on the first send, and a second send
///   throws `StateError('The FormData has already been finalized ...')`.
///   Every file upload made with an expired access token failed this way,
///   although the refresh had succeeded. [bodyFor] sends a
///   [FormData.clone] instead; a clone re-reads each [MultipartFile] from its
///   source (bytes, a string, a file path, or a `fromStream` factory).
/// * a [Stream]: it can be listened to once, and nothing here can rewind it.
///   [canReplay] is false for one, so the replay fails with [reason] - or is
///   not attempted at all - instead of a bare `StateError`.
///
/// One case a clone cannot rescue: a `MultipartFile` built with the
/// deprecated `MultipartFile(stream, length)` constructor wraps a single
/// stream, so its clone fails on send. Build multipart files with
/// `MultipartFile.fromBytes`, `fromString`, `fromFile`, or `fromStream` with a
/// factory that returns a new stream each call.
abstract final class RequestBodyReplay {
  /// Error code carried by the exception a non-replayable body fails with.
  static const String notReplayableCode = 'REQUEST_BODY_NOT_REPLAYABLE';

  /// Whether a request with body [data] can be sent again.
  static bool canReplay(Object? data) => data is! Stream;

  /// The body to send on a replay of a request whose body was [data].
  ///
  /// Call only when [canReplay] is true.
  static Object? bodyFor(Object? data) =>
      data is FormData ? data.clone() : data;

  /// Why a request with body [data] cannot be sent again.
  static String reason(Object? data) =>
      'The request could not be sent again: its ${data.runtimeType} body can '
      'be read only once. Send the body as bytes, a String, a Map or a '
      'FormData to let it be retried.';
}
