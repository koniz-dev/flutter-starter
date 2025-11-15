import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/dio_exception_mapper.dart';

/// Interceptor for converting DioException to domain exceptions
///
/// This interceptor should be added FIRST in the interceptor chain
/// (before auth and logging interceptors) to ensure all DioExceptions
/// are converted to domain exceptions before other interceptors process them.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
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
