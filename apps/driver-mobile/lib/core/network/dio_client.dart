// Planned: add the auth interceptor attaching the Supabase JWT once auth is
// live.
// Planned: add retry and offline-queue interceptors in a later sprint.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';

/// Provides the shared Dio HTTP client. No real requests are made yet.
final dioProvider = Provider<Dio>((ref) {
  final logger = Logger();
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: <String, dynamic>{'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        logger.d('${options.method} ${options.uri}');
        handler.next(options);
      },
      onError: (error, handler) {
        logger.e('Request failed: ${error.message}');
        handler.next(error);
      },
    ),
  );
  return dio;
});
