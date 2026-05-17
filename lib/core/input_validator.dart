import 'dart:core';
import 'package:flutter/material.dart';

/// Comprehensive input validation utility for security
class InputValidator {
  // Private constructor to prevent instantiation
  InputValidator._();

  /// Email validation with strict security rules
  static ValidationResult validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return const ValidationResult(false, 'Email is required');
    }

    final trimmedEmail = email.trim();
    
    // Basic email format validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(trimmedEmail)) {
      return const ValidationResult(false, 'Invalid email format');
    }

    // Length validation
    if (trimmedEmail.length > 254) {
      return const ValidationResult(false, 'Email too long');
    }

    // Prevent dangerous characters
    if (trimmedEmail.contains('<') || 
        trimmedEmail.contains('>') || 
        trimmedEmail.contains('"') ||
        trimmedEmail.contains("'") ||
        trimmedEmail.contains('\\')) {
      return const ValidationResult(false, 'Invalid characters in email');
    }

    return ValidationResult.success();
  }

  /// Password validation with security requirements
  static ValidationResult validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return const ValidationResult(false, 'Password is required');
    }

    // Length requirements
    if (password.length < 8) {
      return const ValidationResult(false, 'Password must be at least 8 characters');
    }

    if (password.length > 128) {
      return const ValidationResult(false, 'Password too long');
    }

    // Complexity requirements
    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasLowerCase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (!hasUpperCase) {
      return const ValidationResult(false, 'Password must contain uppercase letter');
    }

    if (!hasLowerCase) {
      return const ValidationResult(false, 'Password must contain lowercase letter');
    }

    if (!hasDigits) {
      return const ValidationResult(false, 'Password must contain number');
    }

    if (!hasSpecialCharacters) {
      return const ValidationResult(false, 'Password must contain special character');
    }

    // Prevent common patterns
    final commonPatterns = [
      'password',
      '123456',
      'qwerty',
      'admin',
      'letmein',
      'welcome',
    ];

    final lowerPassword = password.toLowerCase();
    for (final pattern in commonPatterns) {
      if (lowerPassword.contains(pattern)) {
        return const ValidationResult(false, 'Password contains common pattern');
      }
    }

    return ValidationResult.success();
  }

  /// Name validation (for person names, mosque names, etc.)
  static ValidationResult validateName(String? name, {int maxLength = 100}) {
    if (name == null || name.trim().isEmpty) {
      return const ValidationResult(false, 'Name is required');
    }

    final trimmedName = name.trim();
    
    if (trimmedName.length < 2) {
      return const ValidationResult(false, 'Name too short');
    }

    if (trimmedName.length > maxLength) {
      return ValidationResult(false, 'Name too long (max $maxLength characters)');
    }

    // Allow letters, spaces, and common name characters
    final nameRegex = RegExp(r'^[a-zA-Z\u0600-\u06FF\s\-\.]+$');
    if (!nameRegex.hasMatch(trimmedName)) {
      return const ValidationResult(false, 'Invalid characters in name');
    }

    // Prevent script injection
    if (_containsScriptTags(trimmedName)) {
      return const ValidationResult(false, 'Invalid input');
    }

    return ValidationResult.success();
  }

  /// Phone number validation
  static ValidationResult validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return const ValidationResult(false, 'Phone number is required');
    }

    final trimmedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Basic phone validation (10-15 digits)
    final phoneRegex = RegExp(r'^\+?[1-9]\d{9,14}$');
    if (!phoneRegex.hasMatch(trimmedPhone)) {
      return const ValidationResult(false, 'Invalid phone number format');
    }

    return ValidationResult.success();
  }

  /// Text field validation for general text input
  static ValidationResult validateText(String? text, {
    int minLength = 1,
    int maxLength = 500,
    bool allowEmpty = false,
  }) {
    if (text == null || text.trim().isEmpty) {
      if (allowEmpty) {
        return ValidationResult.success();
      }
      return const ValidationResult(false, 'Field is required');
    }

    final trimmedText = text.trim();
    
    if (trimmedText.length < minLength) {
      return ValidationResult(false, 'Text too short (min $minLength characters)');
    }

    if (trimmedText.length > maxLength) {
      return ValidationResult(false, 'Text too long (max $maxLength characters)');
    }

    // Prevent script/HTML injection — Firestore is NoSQL so SQL keywords are harmless
    if (_containsScriptTags(trimmedText)) {
      return const ValidationResult(false, 'Invalid input');
    }

    return ValidationResult.success();
  }

  /// URL validation
  static ValidationResult validateUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return const ValidationResult(false, 'URL is required');
    }

    final trimmedUrl = url.trim();
    
    try {
      final uri = Uri.parse(trimmedUrl);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return const ValidationResult(false, 'Invalid URL format');
      }
      
      if (uri.host.isEmpty) {
        return const ValidationResult(false, 'Invalid URL');
      }

      // Prevent dangerous protocols
      final dangerousSchemes = ['javascript', 'data', 'vbscript', 'file'];
      if (dangerousSchemes.contains(uri.scheme.toLowerCase())) {
        return const ValidationResult(false, 'Invalid URL protocol');
      }

    } catch (e) {
      return const ValidationResult(false, 'Invalid URL format');
    }

    return ValidationResult.success();
  }

  /// Sanitize text input by removing dangerous characters
  static String sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'&[^;]+;'), '') // Remove HTML entities
        .replaceAll(RegExp(r'javascript:'), '') // Remove javascript protocol
        .replaceAll(RegExp(r'on\w+\s*='), '') // Remove event handlers
        .trim();
  }

  /// Check for script tags in input
  static bool _containsScriptTags(String input) {
    final scriptPatterns = [
      RegExp(r'<script[^>]*>', caseSensitive: false),
      RegExp(r'</script>', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false),
    ];

    for (final pattern in scriptPatterns) {
      if (pattern.hasMatch(input)) {
        return true;
      }
    }

    return false;
  }

  /// Validate mosque-specific fields
  static ValidationResult validateMosqueName(String? name) {
    return validateName(name, maxLength: 150);
  }

  static ValidationResult validateMosqueAddress(String? address) {
    return validateText(address, minLength: 5, maxLength: 300);
  }

  static ValidationResult validateMosqueDescription(String? description) {
    return validateText(description, minLength: 0, maxLength: 1000, allowEmpty: true);
  }

  /// Validate prayer time format
  static ValidationResult validatePrayerTime(String? time) {
    if (time == null || time.trim().isEmpty) {
      return const ValidationResult(false, 'Prayer time is required');
    }

    final trimmedTime = time.trim();
    
    // Check for --:-- placeholder
    if (trimmedTime == '--:--') {
      return ValidationResult.success(); // Allow placeholder
    }

    // Validate time format (HH:MM AM/PM)
    final timeRegex = RegExp(r'^(0[1-9]|1[0-2]):[0-5][0-9]\s?(AM|PM)$', caseSensitive: false);
    if (!timeRegex.hasMatch(trimmedTime)) {
      return const ValidationResult(false, 'Invalid time format (use HH:MM AM/PM)');
    }

    return ValidationResult.success();
  }
}

/// Validation result class
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult(this.isValid, this.errorMessage);

  const ValidationResult.success() : isValid = true, errorMessage = null;

  bool get hasError => !isValid && errorMessage != null;
}
