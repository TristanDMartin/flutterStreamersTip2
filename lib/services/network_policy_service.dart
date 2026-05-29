import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Service for managing network policies based on connectivity, battery, and user preferences
class NetworkPolicyService {
  static final NetworkPolicyService _instance = NetworkPolicyService._internal();
  factory NetworkPolicyService() => _instance;
  NetworkPolicyService._internal();

  final Connectivity _connectivity = Connectivity();
  
  // Policy state
  bool _isInitialized = false;
  ConnectivityResult _currentConnectivity = ConnectivityResult.none;
  final int _batteryLevel = 100; // Simulated battery level
  final bool _isLowPowerMode = false; // Simulated low power mode
  bool _prefetchEnabled = true;
  bool _prefetchMediaSegments = true;
  double _prefetchThreshold = 0.5;

  /// Initialize the network policy service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get initial connectivity
      final results = await _connectivity.checkConnectivity();
      _currentConnectivity = results.isNotEmpty ? results.first : ConnectivityResult.none;
      
      // Load user preferences
      await _loadPreferences();
      
      // Listen to connectivity changes
      _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
        _onConnectivityChanged(results.isNotEmpty ? results.first : ConnectivityResult.none);
      });
      
      _isInitialized = true;
      secureLog('📡 Network policy service initialized');
      secureLog('📊 Policy: ${getPolicyInfo()}');
    } catch (e) {
      secureLog('❌ Error initializing network policy: $e');
    }
  }

  /// Check if prefetch is allowed for given priority
  bool canPrefetch(double priority) {
    if (!_prefetchEnabled) return false;
    if (priority < _prefetchThreshold) return false;
    
    // Check connectivity
    if (_currentConnectivity == ConnectivityResult.none) return false;
    
    // Check battery level
    if (_batteryLevel < 20) return false;
    
    // Check low power mode
    if (_isLowPowerMode) return false;
    
    // Check cellular vs WiFi
    if (_currentConnectivity == ConnectivityResult.mobile) {
      // On cellular, only prefetch high priority items
      return priority >= 0.8;
    }
    
    return true;
  }

  /// Check if media segments should be prefetched
  bool get prefetchMediaSegments {
    if (!_prefetchMediaSegments) return false;
    if (_currentConnectivity == ConnectivityResult.mobile) return false;
    if (_batteryLevel < 30) return false;
    if (_isLowPowerMode) return false;
    
    return true;
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    _currentConnectivity = result;
    secureLog('📡 Connectivity changed: $result');
    
    // Update prefetch settings based on connectivity
    _updatePrefetchSettings();
  }


  /// Update prefetch settings based on current conditions
  void _updatePrefetchSettings() {
    final oldMediaSegments = _prefetchMediaSegments;
    
    // Update media segment prefetching
    _prefetchMediaSegments = _currentConnectivity == ConnectivityResult.wifi &&
                           _batteryLevel >= 30 &&
                           !_isLowPowerMode;
    
    if (oldMediaSegments != _prefetchMediaSegments) {
      secureLog('🔄 Media segment prefetching: $_prefetchMediaSegments');
    }
  }

  /// Load user preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _prefetchEnabled = prefs.getBool('prefetch_enabled') ?? true;
      _prefetchThreshold = prefs.getDouble('prefetch_threshold') ?? 0.5;
      
      secureLog('⚙️ Loaded preferences: enabled=$_prefetchEnabled, threshold=$_prefetchThreshold');
    } catch (e) {
      secureLog('❌ Error loading preferences: $e');
    }
  }

  /// Save user preferences
  Future<void> savePreferences({
    bool? prefetchEnabled,
    double? prefetchThreshold,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (prefetchEnabled != null) {
        _prefetchEnabled = prefetchEnabled;
        await prefs.setBool('prefetch_enabled', prefetchEnabled);
      }
      
      if (prefetchThreshold != null) {
        _prefetchThreshold = prefetchThreshold;
        await prefs.setDouble('prefetch_threshold', prefetchThreshold);
      }
      
      secureLog('💾 Saved preferences: enabled=$_prefetchEnabled, threshold=$_prefetchThreshold');
    } catch (e) {
      secureLog('❌ Error saving preferences: $e');
    }
  }

  /// Get current policy information
  Map<String, dynamic> getPolicyInfo() {
    return {
      'connectivity': _currentConnectivity.toString(),
      'batteryLevel': _batteryLevel,
      'isLowPowerMode': _isLowPowerMode,
      'prefetchEnabled': _prefetchEnabled,
      'prefetchMediaSegments': _prefetchMediaSegments,
      'prefetchThreshold': _prefetchThreshold,
      'canPrefetch': canPrefetch(0.5), // Test with medium priority
    };
  }

  /// Get network quality estimate
  NetworkQuality getNetworkQuality() {
    if (_currentConnectivity == ConnectivityResult.none) {
      return NetworkQuality.none;
    }
    
    if (_currentConnectivity == ConnectivityResult.mobile) {
      if (_batteryLevel < 20) return NetworkQuality.poor;
      return NetworkQuality.medium;
    }
    
    if (_currentConnectivity == ConnectivityResult.wifi) {
      if (_batteryLevel < 30) return NetworkQuality.medium;
      return NetworkQuality.excellent;
    }
    
    return NetworkQuality.unknown;
  }

  /// Get recommended prefetch strategy
  PrefetchStrategy getPrefetchStrategy() {
    final quality = getNetworkQuality();
    
    switch (quality) {
      case NetworkQuality.excellent:
        return PrefetchStrategy.aggressive;
      case NetworkQuality.medium:
        return PrefetchStrategy.moderate;
      case NetworkQuality.poor:
        return PrefetchStrategy.conservative;
      case NetworkQuality.none:
        return PrefetchStrategy.offline;
      case NetworkQuality.unknown:
        return PrefetchStrategy.moderate;
    }
  }
}

/// Network quality levels
enum NetworkQuality {
  none,
  poor,
  medium,
  excellent,
  unknown,
}

/// Prefetch strategies
enum PrefetchStrategy {
  offline,      // No prefetching
  conservative, // Only posters, no media
  moderate,     // Posters + playlists
  aggressive,   // Posters + playlists + first segments
}
