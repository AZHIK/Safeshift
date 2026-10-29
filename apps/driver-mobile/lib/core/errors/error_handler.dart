import 'dart:async';

import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'failures.dart';

/// Maps backend, auth, and network errors to user-safe [Failure] messages.
///
/// Raw error details are logged locally for diagnostics but never rendered.
abstract final class ErrorHandler {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 8),
  );

  static Failure map(Object error, {StackTrace? stackTrace}) {
    _logger.e('SafeShift operation failed', error: error, stackTrace: stackTrace);

    if (error is Failure) return error;

    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid') || message.contains('token')) {
        return const AuthFailure('That code is invalid or has expired.');
      }
      if (message.contains('rate') || message.contains('too many')) {
        return const AuthFailure(
          'Too many attempts. Please wait a moment and try again.',
        );
      }
      if (message.contains('phone')) {
        return const AuthFailure(
          'We could not send a code to that number. Check it and try again.',
        );
      }
      return const AuthFailure('Sign-in failed. Please try again.');
    }

    if (error is FunctionException) {
      return _mapFunctionError(error);
    }

    if (error is PostgrestException) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        return const AuthFailure('You do not have permission to do that.');
      }
      if (error.code == 'PGRST116') {
        return const ServerFailure('That record could not be found.');
      }
      return const ServerFailure('The server could not complete that request.');
    }

    if (error is TimeoutException) {
      return const NetworkFailure(
        'The request timed out. Check your connection and try again.',
      );
    }

    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('connection') ||
        text.contains('failed host lookup')) {
      return const NetworkFailure(
        'You appear to be offline. Showing saved data where available.',
      );
    }

    return const ServerFailure('Something went wrong. Please try again.');
  }

  static Failure _mapFunctionError(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final nested = details['error'];
      if (nested is Map) {
        final message = nested['message'];
        if (message is String && message.trim().isNotEmpty) {
          return ServerFailure(_friendlyServerMessage(message));
        }
      }
      final message = details['message'];
      if (message is String && message.trim().isNotEmpty) {
        return ServerFailure(_friendlyServerMessage(message));
      }
    }
    if (error.status == 401 || error.status == 403) {
      return const AuthFailure('Your session has expired. Please sign in again.');
    }
    if (error.status == 429) {
      return const ServerFailure('Too many requests. Please wait and retry.');
    }
    return const ServerFailure('The service is unavailable right now.');
  }

  static String _friendlyServerMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid otp') || lower.contains('otp')) {
      return 'That delivery code is invalid or has expired.';
    }
    if (lower.contains('expired')) {
      return 'That request has expired. Please try again.';
    }
    if (lower.contains('not found')) {
      return 'We could not find that record.';
    }
    if (lower.contains('not authorised') ||
        lower.contains('not authorized') ||
        lower.contains('permission')) {
      return 'You do not have permission to do that.';
    }
    return 'The server could not complete that request.';
  }
}
