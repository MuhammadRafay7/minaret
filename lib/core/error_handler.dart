import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Secure error handling utility that prevents sensitive information disclosure
class SecureErrorHandler {
  // Private constructor to prevent instantiation
  SecureErrorHandler._();

  /// Handle and sanitize exceptions for user display
  static String getSafeErrorMessage(dynamic error, {String? context}) {
    if (error == null) {
      return _getDefaultErrorMessage(context);
    }

    // Handle specific error types
    if (error is FirebaseAuthException) {
      return _handleFirebaseAuthError(error);
    }

    if (error is DioException) {
      return _handleDioError(error);
    }

    if (error is FormatException) {
      return 'Invalid data format. Please try again.';
    }

    if (error is TimeoutException) {
      return 'Request timed out. Please check your connection and try again.';
    }

    // Generic error handling
    return _getGenericErrorMessage(error, context);
  }

  /// Handle Firebase Auth errors securely
  static String _handleFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'User account not found. Please check your credentials.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address. Please enter a valid email.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with different credentials.';
      case 'invalid-credential':
        return 'Invalid credentials provided. Please try again.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please check and try again.';
      case 'invalid-verification-id':
        return 'Invalid verification ID. Please request a new code.';
      case 'missing-verification-code':
        return 'Verification code is required.';
      case 'missing-verification-id':
        return 'Verification ID is missing. Please request a new code.';
      case 'quota-exceeded':
        return 'Service quota exceeded. Please try again later.';
      case 'session-expired':
        return 'Session expired. Please log in again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Handle Dio HTTP errors securely
  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.sendTimeout:
        return 'Request timeout. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Server response timeout. Please try again.';
      case DioExceptionType.badResponse:
        return _handleHttpError(error.response?.statusCode ?? 0);
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.connectionError:
        return 'Network connection error. Please check your internet connection.';
      case DioExceptionType.unknown:
      default:
        return 'Network error occurred. Please try again.';
    }
  }

  /// Handle HTTP status codes securely
  static String _handleHttpError(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input and try again.';
      case 401:
        return 'Authentication required. Please log in again.';
      case 403:
        return 'Access denied. You don\'t have permission to perform this action.';
      case 404:
        return 'Requested resource not found.';
      case 408:
        return 'Request timeout. Please try again.';
      case 429:
        return 'Too many requests. Please wait and try again later.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
        return 'Service temporarily unavailable. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      case 504:
        return 'Gateway timeout. Please try again later.';
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return 'Request error. Please check your input and try again.';
        } else if (statusCode >= 500) {
          return 'Server error. Please try again later.';
        } else {
          return 'Network error occurred. Please try again.';
        }
    }
  }

  /// Get generic error message without sensitive details
  static String _getGenericErrorMessage(dynamic error, String? context) {
    // Log the full error for debugging in debug mode only
    if (kDebugMode) {
      debugPrint('Error in $context: $error');
    }

    // Return safe message for users
    if (context != null) {
      return 'An error occurred in $context. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get default error message
  static String _getDefaultErrorMessage(String? context) {
    if (context != null) {
      return 'Something went wrong in $context. Please try again.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Log error securely (without sensitive data)
  static void logError(dynamic error, {String? context, Map<String, dynamic>? extra}) {
    if (kDebugMode) {
      final buffer = StringBuffer();
      
      if (context != null) {
        buffer.write('[$context] ');
      }
      
      buffer.write('Error: ${error.runtimeType}');
      
      if (error is Exception) {
        buffer.write(' - ${error.toString()}');
      }
      
      if (extra != null && extra.isNotEmpty) {
        buffer.write(' | Extra: ${_sanitizeExtraData(extra)}');
      }
      
      debugPrint(buffer.toString());
    }
  }

  /// Sanitize extra data for logging (remove sensitive information)
  static Map<String, dynamic> _sanitizeExtraData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      
      // Skip sensitive fields
      if (_isSensitiveField(key)) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    
    return sanitized;
  }

  /// Check if a field contains sensitive information
  static bool _isSensitiveField(String fieldName) {
    final sensitivePatterns = [
      'password',
      'token',
      'secret',
      'key',
      'auth',
      'credential',
      'session',
      'cookie',
      'authorization',
      'bearer',
      'api_key',
      'private',
      'confidential',
    ];
    
    return sensitivePatterns.any((pattern) => fieldName.contains(pattern));
  }

  /// Create user-friendly error message for specific operations
  static String getOperationErrorMessage(String operation, dynamic error) {
    switch (operation.toLowerCase()) {
      case 'login':
      case 'signin':
        return 'Login failed. Please check your credentials and try again.';
      case 'register':
      case 'signup':
        return 'Registration failed. Please check your information and try again.';
      case 'save':
      case 'update':
        return 'Failed to save changes. Please try again.';
      case 'delete':
        return 'Failed to delete item. Please try again.';
      case 'upload':
        return 'Upload failed. Please check your file and connection.';
      case 'download':
        return 'Download failed. Please check your connection.';
      case 'network':
      case 'api':
        return 'Network error. Please check your internet connection.';
      default:
        return getSafeErrorMessage(error, context: operation);
    }
  }

  /// Check if error is retryable
  static bool isRetryableError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode ?? 0;
          return statusCode >= 500 || statusCode == 408 || statusCode == 429;
        default:
          return false;
      }
    }

    if (error is FirebaseAuthException) {
      return error.code == 'too-many-requests' || 
             error.code == 'quota-exceeded' ||
             error.code == 'network-request-failed';
    }

    return false;
  }

  /// Get retry suggestion message
  static String getRetryMessage() {
    return 'Please wait a moment and try again.';
  }

  /// Get contact support message
  static String getContactSupportMessage() {
    return 'If the problem persists, please contact support.';
  }
}

/// Custom exception for application-specific errors
class AppException implements Exception {
  final String message;
  final String? context;
  final dynamic originalError;
  final bool isRetryable;

  const AppException(
    this.message, {
    this.context,
    this.originalError,
    this.isRetryable = false,
  });

  @override
  String toString() {
    return 'AppException: $message';
  }

  /// Get safe error message for users
  String getSafeMessage() {
    return SecureErrorHandler.getSafeErrorMessage(this, context: context);
  }
}

/// Network-specific exception
class NetworkException extends AppException {
  const NetworkException(
    String message, {
    String? context,
    dynamic originalError,
    bool isRetryable = true,
  }) : super(
          message,
          context: context,
          originalError: originalError,
          isRetryable: isRetryable,
        );
}

/// Validation-specific exception
class ValidationException extends AppException {
  final String field;

  const ValidationException(
    String message,
    this.field, {
    String? context,
  }) : super(
          message,
          context: context,
          isRetryable: false,
        );

  @override
  String getSafeMessage() {
    return '$field: $message';
  }
}
