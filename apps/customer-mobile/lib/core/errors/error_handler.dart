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
    _logger.e(
      'SafeShift operation failed',
      error: error,
      stackTrace: stackTrace,
    );

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
      final domainMessage = _friendlyDomainMessage(error.message);
      if (domainMessage != null) return ServerFailure(domainMessage);
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
      return const AuthFailure(
        'Your session has expired. Please sign in again.',
      );
    }
    if (error.status == 429) {
      return const ServerFailure('Too many requests. Please wait and retry.');
    }
    return const ServerFailure('The service is unavailable right now.');
  }

  /// Turns known database domain errors into actionable copy.
  ///
  /// The quote engine raises SQLSTATE 22023 for business-rule failures (for
  /// example an out-of-area pickup). Without this mapping PostgREST surfaces
  /// them as the generic "server could not complete that request" message.
  static String? _friendlyDomainMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('destination point is outside every active service city')) {
      return 'That destination is outside our service area. Choose a drop-off '
          'inside Dar es Salaam and try again.';
    }
    if (lower.contains('pickup point is outside every active service city') ||
        lower.contains('outside every active service city')) {
      return 'That pickup is outside our service area. Choose a pickup inside '
          'Dar es Salaam and try again.';
    }
    // The quote engine already writes actionable copy for these; pass it
    // through instead of replacing it with the generic server error.
    if (lower.contains('choose a larger vehicle') ||
        lower.contains('choose an allowed vehicle') ||
        lower.contains('choose another vehicle') ||
        lower.contains('add an approximate value') ||
        lower.contains('declared value exceeds') ||
        lower.contains('route distance is too long') ||
        lower.contains('scheduled time is in the past') ||
        lower.contains('scheduled at most 60 days ahead') ||
        lower.contains('at most 8 parcel photos') ||
        lower.contains('parcel photos can only be changed') ||
        lower.contains('distance_km must be') ||
        lower.contains('duration_min must be') ||
        lower.contains('cargo_description must be') ||
        lower.contains('scheduled time') ||
        lower.contains('declared_value_tzs must be')) {
      return raw.trim();
    }
    if (lower.contains('no active pricing plan') ||
        lower.contains('no active published version')) {
      return 'Bookings are not open for that vehicle right now. Try another '
          'vehicle or check back shortly.';
    }
    if (lower.contains('vehicle type') &&
        (lower.contains('not available') || lower.contains('not found'))) {
      return 'That vehicle is not available at this pickup. Try another vehicle.';
    }
    if (lower.contains('cargo type') && lower.contains('not available')) {
      return 'That cargo type is not available at this pickup. Try another option.';
    }
    if (lower.contains('quote') && lower.contains('has expired')) {
      return 'That quote expired. Please request a fresh quote.';
    }
    if (lower.contains('quote') && lower.contains('has already been used')) {
      return 'That quote was already used. Please request a fresh quote.';
    }
    if (lower.contains('promo code') && lower.contains('not valid')) {
      return 'That promo code is not valid for this quote.';
    }
    return null;
  }

  static String _friendlyServerMessage(String raw) {
    final domainMessage = _friendlyDomainMessage(raw);
    if (domainMessage != null) return domainMessage;

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
