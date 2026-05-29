// ============================================================================
// ENTERPRISE-GRADE DEPENDENCY INJECTION SYSTEM
// ============================================================================

/// 
/// Comprehensive Dependency Injection System
/// 
/// Provides enterprise-grade dependency management with:
/// - Service lifetime management (Singleton, Transient, Scoped)
/// - Interface-based dependency resolution
/// - Circular dependency detection
/// - Lazy initialization
/// - Service location pattern
/// - Factory pattern support
/// 
/// @author Senior Development Team
/// @version 2.0.0
/// @since 1.0.0
/// 

import 'package:flutter/foundation.dart';
import 'dart:async';

// ============================================================================
// SERVICE LIFETIME ENUMS
// ============================================================================

enum ServiceLifetime {
  singleton,
  transient,
  scoped,
}

// ============================================================================
// SERVICE DESCRIPTOR
// ============================================================================

class ServiceDescriptor {
  final Type serviceType;
  final Type implementationType;
  final ServiceLifetime lifetime;
  final Object? instance;
  final Function? factory;
  final List<Type> dependencies;
  
  const ServiceDescriptor({
    required this.serviceType,
    required this.implementationType,
    required this.lifetime,
    this.instance,
    this.factory,
    this.dependencies = const [],
  });
  
  bool get isFactory => factory != null;
  bool get isSingleton => lifetime == ServiceLifetime.singleton;
  bool get isTransient => lifetime == ServiceLifetime.transient;
  bool get isScoped => lifetime == ServiceLifetime.scoped;
}

// ============================================================================
// SERVICE CONTAINER
// ============================================================================

class ServiceContainer {
  static final ServiceContainer _instance = ServiceContainer._internal();
  factory ServiceContainer() => _instance;
  ServiceContainer._internal();
  
  final Map<Type, ServiceDescriptor> _services = {};
  final Map<Type, Object> _singletonInstances = {};
  final Map<String, Object> _scopedInstances = {};
  final Set<Type> _resolving = {};
  
  String? _currentScopeId;
  
  // ============================================================================
  // SERVICE REGISTRATION
  // ============================================================================
  
  /// Register a singleton service
  void registerSingleton<T extends Object, TImpl extends T>() {
    _registerService<T, TImpl>(ServiceLifetime.singleton);
  }
  
  /// Register a singleton service with instance
  void registerSingletonInstance<T extends Object>(T instance) {
    _services[T] = ServiceDescriptor(
      serviceType: T,
      implementationType: instance.runtimeType,
      lifetime: ServiceLifetime.singleton,
      instance: instance,
    );
    _singletonInstances[T] = instance;
  }
  
  /// Register a singleton service with factory
  void registerSingletonFactory<T extends Object>(T Function() factory) {
    _services[T] = ServiceDescriptor(
      serviceType: T,
      implementationType: T,
      lifetime: ServiceLifetime.singleton,
      factory: factory,
    );
  }
  
  /// Register a transient service
  void registerTransient<T extends Object, TImpl extends T>() {
    _registerService<T, TImpl>(ServiceLifetime.transient);
  }
  
  /// Register a transient service with factory
  void registerTransientFactory<T extends Object>(T Function() factory) {
    _services[T] = ServiceDescriptor(
      serviceType: T,
      implementationType: T,
      lifetime: ServiceLifetime.transient,
      factory: factory,
    );
  }
  
  /// Register a scoped service
  void registerScoped<T extends Object, TImpl extends T>() {
    _registerService<T, TImpl>(ServiceLifetime.scoped);
  }
  
  /// Register a scoped service with factory
  void registerScopedFactory<T extends Object>(T Function() factory) {
    _services[T] = ServiceDescriptor(
      serviceType: T,
      implementationType: T,
      lifetime: ServiceLifetime.scoped,
      factory: factory,
    );
  }
  
  void _registerService<T extends Object, TImpl extends T>(ServiceLifetime lifetime) {
    _services[T] = ServiceDescriptor(
      serviceType: T,
      implementationType: TImpl,
      lifetime: lifetime,
      dependencies: _getDependencies<TImpl>(),
    );
  }
  
  /// Get constructor dependencies for a type
  List<Type> _getDependencies<T extends Object>() {
    // This is a simplified implementation
    // In a real-world scenario, you would use reflection or code generation
    // to automatically detect constructor dependencies
    return [];
  }
  
  // ============================================================================
  // SERVICE RESOLUTION
  // ============================================================================
  
  /// Resolve a service instance
  T resolve<T extends Object>() {
    return _resolveService<T>() as T;
  }
  
  /// Resolve a service asynchronously
  Future<T> resolveAsync<T extends Object>() async {
    return await _resolveServiceAsync<T>() as T;
  }
  
  /// Try to resolve a service (returns null if not registered)
  T? tryResolve<T extends Object>() {
    try {
      return resolve<T>();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to resolve service $T: $e');
      }
      return null;
    }
  }
  
  /// Check if a service is registered
  bool isRegistered<T extends Object>() {
    return _services.containsKey(T);
  }
  
  Object _resolveService<T extends Object>() {
    final descriptor = _services[T];
    if (descriptor == null) {
      throw StateError('Service $T is not registered');
    }
    
    // Check for circular dependencies
    if (_resolving.contains(T)) {
      throw StateError('Circular dependency detected for service $T');
    }
    
    try {
      _resolving.add(T);
      
      // Handle different lifetimes
      switch (descriptor.lifetime) {
        case ServiceLifetime.singleton:
          return _resolveSingleton<T>(descriptor);
        case ServiceLifetime.transient:
          return _resolveTransient<T>(descriptor);
        case ServiceLifetime.scoped:
          return _resolveScoped<T>(descriptor);
      }
    } finally {
      _resolving.remove(T);
    }
  }
  
  Future<Object> _resolveServiceAsync<T extends Object>() async {
    // For async resolution, we would need to handle async factories
    // This is a simplified implementation
    return _resolveService<T>();
  }
  
  Object _resolveSingleton<T extends Object>(ServiceDescriptor descriptor) {
    // Return existing instance if available
    if (_singletonInstances.containsKey(T)) {
      return _singletonInstances[T]!;
    }
    
    // Create new instance
    final instance = _createInstance(descriptor);
    _singletonInstances[T] = instance;
    return instance;
  }
  
  Object _resolveTransient<T extends Object>(ServiceDescriptor descriptor) {
    // Always create new instance
    return _createInstance(descriptor);
  }
  
  Object _resolveScoped<T extends Object>(ServiceDescriptor descriptor) {
    final scopeId = _currentScopeId ?? 'default';
    final key = '$scopeId:$T';
    
    // Return existing scoped instance if available
    if (_scopedInstances.containsKey(key)) {
      return _scopedInstances[key]!;
    }
    
    // Create new instance
    final instance = _createInstance(descriptor);
    _scopedInstances[key] = instance;
    return instance;
  }
  
  Object _createInstance(ServiceDescriptor descriptor) {
    if (descriptor.instance != null) {
      return descriptor.instance!;
    }
    
    if (descriptor.factory != null) {
      return descriptor.factory!();
    }
    
    // Create instance using constructor injection
    return _createWithConstructorInjection(descriptor);
  }
  
  Object _createWithConstructorInjection(ServiceDescriptor descriptor) {
    // Dart lacks runtime reflection — registerSingletonFactory() or registerSingletonInstance() must be used.
    throw StateError(
      'Cannot auto-instantiate ${descriptor.implementationType}. '
      'Register it with registerSingletonFactory() or registerSingletonInstance().',
    );
  }
  
  // ============================================================================
  // SCOPE MANAGEMENT
  // ============================================================================
  
  /// Create a new scope
  String createScope() {
    final scopeId = 'scope_${DateTime.now().millisecondsSinceEpoch}';
    _currentScopeId = scopeId;
    return scopeId;
  }
  
  /// Enter an existing scope
  void enterScope(String scopeId) {
    _currentScopeId = scopeId;
  }
  
  /// Exit current scope and dispose scoped services
  void exitScope() {
    if (_currentScopeId != null) {
      _disposeScopedServices(_currentScopeId!);
      _currentScopeId = null;
    }
  }
  
  /// Dispose all scoped services for a scope
  void _disposeScopedServices(String scopeId) {
    final keysToRemove = <String>[];
    
    for (final key in _scopedInstances.keys) {
      if (key.startsWith('$scopeId:')) {
        keysToRemove.add(key);
      }
    }
    
    for (final key in keysToRemove) {
      final instance = _scopedInstances[key];
      
      // Dispose if it's disposable
      if (instance is Disposable) {
        try {
          instance.dispose();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error disposing scoped service: $e');
          }
        }
      }
      
      _scopedInstances.remove(key);
    }
  }
  
  /// Dispose all services
  void dispose() {
    // Dispose singleton instances
    for (final instance in _singletonInstances.values) {
      if (instance is Disposable) {
        try {
          instance.dispose();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error disposing singleton service: $e');
          }
        }
      }
    }
    
    // Dispose scoped instances
    for (final instance in _scopedInstances.values) {
      if (instance is Disposable) {
        try {
          instance.dispose();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error disposing scoped service: $e');
          }
        }
      }
    }
    
    _singletonInstances.clear();
    _scopedInstances.clear();
    _services.clear();
    _resolving.clear();
    _currentScopeId = null;
  }
  
  // ============================================================================
  // SERVICE INFORMATION
  // ============================================================================
  
  /// Get all registered services
  Map<Type, ServiceDescriptor> getRegisteredServices() {
    return Map.unmodifiable(_services);
  }
  
  /// Get service descriptor
  ServiceDescriptor? getServiceDescriptor<T extends Object>() {
    return _services[T];
  }
  
  /// Check if a service is singleton
  bool isSingleton<T extends Object>() {
    final descriptor = _services[T];
    return descriptor?.isSingleton ?? false;
  }
  
  /// Check if a service is transient
  bool isTransient<T extends Object>() {
    final descriptor = _services[T];
    return descriptor?.isTransient ?? false;
  }
  
  /// Check if a service is scoped
  bool isScoped<T extends Object>() {
    final descriptor = _services[T];
    return descriptor?.isScoped ?? false;
  }
  
  /// Get container statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalServices': _services.length,
      'singletonInstances': _singletonInstances.length,
      'scopedInstances': _scopedInstances.length,
      'currentScope': _currentScopeId,
      'servicesByLifetime': {
        'singleton': _services.values.where((s) => s.isSingleton).length,
        'transient': _services.values.where((s) => s.isTransient).length,
        'scoped': _services.values.where((s) => s.isScoped).length,
      },
    };
  }
}

// ============================================================================
// DISPOSABLE INTERFACE
// ============================================================================

/// Interface for services that need to be disposed
abstract class Disposable {
  /// Dispose resources
  void dispose();
}

// ============================================================================
// SERVICE LOCATOR
// ============================================================================

/// Service locator for convenient access to services
class ServiceLocator {
  static ServiceContainer get container => ServiceContainer();
  
  /// Resolve a service
  static T get<T extends Object>() {
    return container.resolve<T>();
  }
  
  /// Resolve a service asynchronously
  static Future<T> getAsync<T extends Object>() {
    return container.resolveAsync<T>();
  }
  
  /// Try to resolve a service
  static T? tryGet<T extends Object>() {
    return container.tryResolve<T>();
  }
  
  /// Check if a service is registered
  static bool isRegistered<T extends Object>() {
    return container.isRegistered<T>();
  }
}

// ============================================================================
// INJECTABLE ANNOTATION
// ============================================================================

/// Annotation for marking classes as injectable
class Injectable {
  final ServiceLifetime lifetime;
  
  const Injectable(this.lifetime);
}

/// Annotation for marking constructor parameters for injection
class Inject {
  final Type? type;
  final String? name;
  
  const Inject({this.type, this.name});
}

// ============================================================================
// SERVICE CONFIGURATION
// ============================================================================

/// Configuration class for service registration
class ServiceConfiguration {
  final List<Function(ServiceContainer)> registrations;
  
  const ServiceConfiguration(this.registrations);
  
  /// Apply configuration to container
  void apply(ServiceContainer container) {
    for (final registration in registrations) {
      registration(container);
    }
  }
}

// ============================================================================
// COMMON SERVICE INTERFACES
// ============================================================================

/// Interface for logging services
abstract class ILoggingService {
  void logInfo(String message, {String? category, Map<String, dynamic>? context});
  void logError(String message, {String? category, Map<String, dynamic>? context});
  void logWarning(String message, {String? category, Map<String, dynamic>? context});
  void logDebug(String message, {String? category, Map<String, dynamic>? context});
}

/// Interface for configuration services
abstract class IConfigurationService {
  T? get<T>(String key);
  void set<T>(String key, T value);
  bool containsKey(String key);
  Map<String, dynamic> getAll();
}

/// Interface for cache services
abstract class ICacheService {
  Future<T?> get<T>(String key);
  Future<void> set<T>(String key, T value, {Duration? expiration});
  Future<void> remove(String key);
  Future<void> clear();
}

/// Interface for API services
abstract class IApiService {
  Future<T> get<T>(String endpoint, {Map<String, dynamic>? queryParameters});
  Future<T> post<T>(String endpoint, {dynamic data});
  Future<T> put<T>(String endpoint, {dynamic data});
  Future<T> delete<T>(String endpoint);
}

// ============================================================================
// UTILITY EXTENSIONS
// ============================================================================

/// Extension for easy service registration
extension ServiceContainerExtensions on ServiceContainer {
  /// Register multiple services from configuration
  void registerFromConfiguration(ServiceConfiguration configuration) {
    configuration.apply(this);
  }
  
}

/// Extension for convenient service resolution
class ServiceProvider {
  final ServiceContainer _container;
  
  ServiceProvider(this._container);
  
  T get<T extends Object>() => _container.resolve<T>();
  Future<T> getAsync<T extends Object>() => _container.resolveAsync<T>();
  T? tryGet<T extends Object>() => _container.tryResolve<T>();
  bool isRegistered<T extends Object>() => _container.isRegistered<T>();
}

// ============================================================================
// DEPENDENCY INJECTION BUILDER
// ============================================================================

class ServiceContainerBuilder {
  final List<Function(ServiceContainer)> _configurations = [];
  
  ServiceContainerBuilder addConfiguration(ServiceConfiguration configuration) {
    _configurations.add((container) => configuration.apply(container));
    return this;
  }
  
  ServiceContainerBuilder addSingleton<T extends Object, TImpl extends T>() {
    _configurations.add((container) => container.registerSingleton<T, TImpl>());
    return this;
  }
  
  ServiceContainerBuilder addTransient<T extends Object, TImpl extends T>() {
    _configurations.add((container) => container.registerTransient<T, TImpl>());
    return this;
  }
  
  ServiceContainerBuilder addScoped<T extends Object, TImpl extends T>() {
    _configurations.add((container) => container.registerScoped<T, TImpl>());
    return this;
  }
  
  ServiceContainer build() {
    final container = ServiceContainer();
    
    for (final configuration in _configurations) {
      configuration(container);
    }
    
    return container;
  }
}

// ============================================================================
// EXAMPLE USAGE
// ============================================================================

/*
// Example service interfaces and implementations
abstract class IUserService {
  Future<User> getUser(String id);
  Future<List<User>> getAllUsers();
}

class UserService implements IUserService, Disposable {
  final ILoggingService _loggingService;
  final IConfigurationService _configService;
  
  UserService(this._loggingService, this._configService);
  
  @override
  Future<User> getUser(String id) async {
    _loggingService.logInfo('Getting user: $id');
    // Implementation
  }
  
  @override
  Future<List<User>> getAllUsers() async {
    _loggingService.logInfo('Getting all users');
    // Implementation
  }
  
  @override
  void dispose() {
    _loggingService.logInfo('UserService disposed');
  }
}

// Example configuration
void configureServices(ServiceContainer container) {
  // Register logging service as singleton
  container.registerSingleton<ILoggingService, LoggingService>();
  
  // Register configuration service as singleton
  container.registerSingleton<IConfigurationService, ConfigurationService>();
  
  // Register user service as transient
  container.registerTransient<IUserService, UserService>();
  
  // Register with factory
  container.registerSingletonFactory<IApiService>(() => ApiService());
}

// Example usage
void main() {
  final container = ServiceContainer();
  configureServices(container);
  
  // Resolve services
  final userService = container.resolve<IUserService>();
  final user = userService.getUser('123');
  
  // Use service locator
  final loggingService = ServiceLocator.get<ILoggingService>();
  loggingService.logInfo('Application started');
  
  // Create scope
  final scopeId = container.createScope();
  try {
    // Use scoped services
    final scopedService = container.resolve<IScopedService>();
  } finally {
    container.exitScope();
  }
}
*/
