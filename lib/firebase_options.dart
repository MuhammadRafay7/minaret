// ============================================================================
// FIREBASE CONFIGURATION MANAGER
// ============================================================================

/// 
/// Firebase Configuration Manager
/// 
/// Provides enterprise-grade Firebase configuration management with:
/// - Environment-based configuration loading
/// - Validation and error handling
/// - Platform-specific optimization
/// - Security best practices
/// 
/// @author Senior Development Team
/// @version 2.0.0
/// @since 1.0.0
/// 

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, kDebugMode, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration validation result
class ConfigurationValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  
  const ConfigurationValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
  
  factory ConfigurationValidationResult.success() {
    return const ConfigurationValidationResult(
      isValid: true,
      errors: [],
      warnings: [],
    );
  }
  
  factory ConfigurationValidationResult.failure(List<String> errors) {
    return ConfigurationValidationResult(
      isValid: false,
      errors: errors,
      warnings: [],
    );
  }
  
  factory ConfigurationValidationResult.warning(List<String> warnings) {
    return ConfigurationValidationResult(
      isValid: true,
      errors: [],
      warnings: warnings,
    );
  }
}

/// Firebase configuration manager with enterprise-grade features
class DefaultFirebaseOptions {
  
  // ============================================================================
  // PRIVATE CONSTANTS
  // ============================================================================
  
  /// Required environment variables for Firebase configuration
  static const List<String> _requiredVars = [
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
  ];
  
  /// Optional environment variables
  static const List<String> _optionalVars = [
    'FIREBASE_AUTH_DOMAIN',
    'FIREBASE_STORAGE_BUCKET',
    'FIREBASE_MEASUREMENT_ID',
  ];
  
  /// Platform-specific required variables
  static const Map<TargetPlatform, List<String>> _platformSpecificVars = {
    TargetPlatform.android: [
      'FIREBASE_ANDROID_API_KEY',
      'FIREBASE_ANDROID_APP_ID',
    ],
    TargetPlatform.iOS: [
      'FIREBASE_IOS_API_KEY',
      'FIREBASE_IOS_APP_ID',
      'FIREBASE_IOS_BUNDLE_ID',
    ],
    TargetPlatform.macOS: [
      'FIREBASE_IOS_API_KEY',
      'FIREBASE_IOS_APP_ID',
      'FIREBASE_IOS_BUNDLE_ID',
    ],
    TargetPlatform.windows: [
      'FIREBASE_API_KEY',
      'FIREBASE_APP_ID',
    ],
  };
  
  // ============================================================================
  // PUBLIC API
  // ============================================================================
  
  /// Get Firebase options for current platform with validation
  static FirebaseOptions get currentPlatform {
    final result = validateConfiguration();
    
    if (!result.isValid) {
      if (kDebugMode) {
        debugPrint('Firebase Configuration Errors:');
        for (final error in result.errors) {
          debugPrint('  - $error');
        }
      }
      
      // Fallback to hardcoded configuration for critical failures
      if (kDebugMode) {
        debugPrint('Using fallback Firebase configuration');
      }
      return _getFallbackConfiguration();
    }
    
    if (result.warnings.isNotEmpty && kDebugMode) {
      debugPrint('Firebase Configuration Warnings:');
      for (final warning in result.warnings) {
        debugPrint('  - $warning');
      }
    }
    
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
  
  /// Validate Firebase configuration
  static ConfigurationValidationResult validateConfiguration() {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Check required variables
    for (final varName in _requiredVars) {
      final value = dotenv.env[varName];
      if (value == null || value.isEmpty) {
        errors.add('Missing required environment variable: $varName');
      } else if (_isInvalidFormat(varName, value)) {
        errors.add('Invalid format for $varName: $value');
      }
    }
    
    // Check platform-specific variables
    if (!kIsWeb) {
      final platformVars = _platformSpecificVars[defaultTargetPlatform];
      if (platformVars != null) {
        for (final varName in platformVars) {
          final value = dotenv.env[varName];
          if (value == null || value.isEmpty) {
            errors.add('Missing platform-specific environment variable: $varName');
          }
        }
      }
    }
    
    // Check optional variables and add warnings
    for (final varName in _optionalVars) {
      final value = dotenv.env[varName];
      if (value == null || value.isEmpty) {
        warnings.add('Missing optional environment variable: $varName');
      }
    }
    
    // Validate project ID format
    final projectId = dotenv.env['FIREBASE_PROJECT_ID'];
    if (projectId != null && !_isValidProjectId(projectId)) {
      errors.add('Invalid Firebase project ID format: $projectId');
    }
    
    // Security warnings
    if (dotenv.env['FIREBASE_API_KEY']?.contains('test') == true) {
      warnings.add('Using test API key in production');
    }
    
    if (errors.isNotEmpty) {
      return ConfigurationValidationResult.failure(errors);
    }
    
    if (warnings.isNotEmpty) {
      return ConfigurationValidationResult.warning(warnings);
    }
    
    return ConfigurationValidationResult.success();
  }
  
  /// Get configuration summary for debugging
  static Map<String, dynamic> getConfigurationSummary() {
    return {
      'platform': defaultTargetPlatform.toString(),
      'isWeb': kIsWeb,
      'projectId': dotenv.env['FIREBASE_PROJECT_ID'],
      'appId': dotenv.env['FIREBASE_APP_ID'],
      'hasApiKey': dotenv.env['FIREBASE_API_KEY']?.isNotEmpty == true,
      'hasStorageBucket': dotenv.env['FIREBASE_STORAGE_BUCKET']?.isNotEmpty == true,
      'hasMeasurementId': dotenv.env['FIREBASE_MEASUREMENT_ID']?.isNotEmpty == true,
      'validation': validateConfiguration().isValid,
    };
  }
  
  // ============================================================================
  // PLATFORM CONFIGURATIONS
  // ============================================================================
  
  /// Web platform configuration
  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_API_KEY'),
    appId: _getEnvVar('FIREBASE_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    authDomain: _getEnvVar('FIREBASE_AUTH_DOMAIN'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
    measurementId: _getEnvVar('FIREBASE_MEASUREMENT_ID'),
  );

  /// Android platform configuration
  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_ANDROID_API_KEY'),
    appId: _getEnvVar('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
  );

  /// iOS platform configuration
  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_IOS_API_KEY'),
    appId: _getEnvVar('FIREBASE_IOS_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: _getEnvVar('FIREBASE_IOS_BUNDLE_ID'),
  );

  /// macOS platform configuration
  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_IOS_API_KEY'),
    appId: _getEnvVar('FIREBASE_IOS_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: _getEnvVar('FIREBASE_IOS_BUNDLE_ID'),
  );

  /// Windows platform configuration
  static FirebaseOptions get windows => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_API_KEY'),
    appId: _getEnvVar('FIREBASE_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    authDomain: _getEnvVar('FIREBASE_AUTH_DOMAIN'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
    measurementId: _getEnvVar('FIREBASE_MEASUREMENT_ID'),
  );
  
  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================
  
  /// Get a required environment variable — throws if absent so secrets are
  /// never silently replaced by hardcoded fallbacks.
  static String _getEnvVar(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception(
        'Missing Firebase configuration: $key. '
        'Ensure .env is present and contains this key.',
      );
    }
    return value;
  }
  
  /// Validate environment variable format
  static bool _isInvalidFormat(String varName, String value) {
    switch (varName) {
      case 'FIREBASE_PROJECT_ID':
        return !_isValidProjectId(value);
      case 'FIREBASE_API_KEY':
        return !_isValidApiKey(value);
      case 'FIREBASE_APP_ID':
        return !_isValidAppId(value);
      case 'FIREBASE_MESSAGING_SENDER_ID':
        return !_isValidSenderId(value);
      default:
        return false;
    }
  }
  
  /// Validate Firebase project ID format
  static bool _isValidProjectId(String projectId) {
    // Project ID must be 6-30 characters, lowercase letters, digits, and hyphens
    // Cannot start or end with hyphen, cannot have consecutive hyphens
    final regex = RegExp(r'^[a-z0-9][a-z0-9-]{4,28}[a-z0-9]$');
    return regex.hasMatch(projectId) && !projectId.contains('--');
  }
  
  /// Validate API key format (basic validation)
  static bool _isValidApiKey(String apiKey) {
    // Basic validation: should be alphanumeric and reasonable length
    return apiKey.length >= 20 && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(apiKey);
  }
  
  /// Validate app ID format
  static bool _isValidAppId(String appId) {
    // App ID format: 1:1234567890:android:abcdef...
    final regex = RegExp(r'^1:\d+:[a-z]+:[a-f0-9]+$');
    return regex.hasMatch(appId);
  }
  
  /// Validate sender ID format
  static bool _isValidSenderId(String senderId) {
    // Sender ID should be numeric
    return RegExp(r'^\d+$').hasMatch(senderId);
  }
  
  /// Get fallback configuration for critical failures
  static FirebaseOptions _getFallbackConfiguration() {
    if (kDebugMode) {
      debugPrint('Configuration validation failed - cannot proceed without proper API keys');
    }
    
    // Throw error instead of using hardcoded keys for security
    throw Exception(
      'Firebase configuration is invalid. Please ensure all required environment variables are set:\n'
      '- FIREBASE_API_KEY\n'
      '- FIREBASE_APP_ID\n'
      '- FIREBASE_MESSAGING_SENDER_ID\n'
      '- FIREBASE_PROJECT_ID'
    );
  }
}
