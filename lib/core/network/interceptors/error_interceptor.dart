import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/dio_exception_mapper.dart';

/// Interceptor for converting DioException to domain exceptions
///
/// This interceptor must be added LAST in the interceptor chain. Its
/// [onError] terminates the chain with `handler.reject(...)`, and dio runs
/// error handlers in registration order, so any interceptor registered after
/// it never sees the error - that would disable retry, 401 token refresh,
/// performance trace teardown and error logging.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Convert DioException to domain exception
    final domainException = DioExceptionMapper.map(err);

    // Reject with a DioException that contains the domain exception
    // This allows the domain exception to be extracted later in catch blocks
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: domainException,
        type: err.type,
        response: err.response,
        message: domainException.message,
      ),
    );
  }
}
