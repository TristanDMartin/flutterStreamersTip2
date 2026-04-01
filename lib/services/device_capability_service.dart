import 'dart:io';
import 'dart:developer' as developer;

/// Service for detecting device capabilities and recommending video quality
class DeviceCapabilityService {
  static DeviceCapabilityService? _instance;
  static DeviceCapabilityService get instance =>
      _instance ??= DeviceCapabilityService._();

  DeviceCapabilityService._();

  int? _cachedHeapSizeMB;
  String? _cachedRecommendedResolution;

  /// Get device heap size in MB (conservative estimates)
  /// Returns estimated heap size based on platform and device characteristics
  Future<int> getDeviceHeapSizeMB() async {
    if (_cachedHeapSizeMB != null) {
      return _cachedHeapSizeMB!;
    }

    try {
      if (Platform.isAndroid) {
        // Modern Android devices can generally handle sharper playback.
        // Keep a safe-but-not-overly-pessimistic default so we do not
        // downshift flagship phones into blurry 720p unnecessarily.
        _cachedHeapSizeMB = 512;
        developer.log('📱 DeviceCapability: Estimated Android heap: 512MB (balanced default)');
      } else if (Platform.isIOS) {
        // iOS devices generally have more memory available
        // Conservative default for iOS
        _cachedHeapSizeMB = 512;
        developer.log('📱 DeviceCapability: Estimated iOS heap: 512MB (conservative)');
      } else {
        // Desktop/other platforms
        _cachedHeapSizeMB = 512;
        developer.log('📱 DeviceCapability: Estimated heap: 512MB (default)');
      }
    } catch (e) {
      developer.log('⚠️ DeviceCapability: Error detecting heap size: $e');
      _cachedHeapSizeMB = 256; // Safe default (lowest)
    }

    return _cachedHeapSizeMB!;
  }

  /// Get recommended video resolution for device based on heap size
  /// Returns: '720' for low-memory devices, '1080' for high-memory devices
  Future<String> getRecommendedResolution() async {
    if (_cachedRecommendedResolution != null) {
      return _cachedRecommendedResolution!;
    }

    final heapSize = await getDeviceHeapSizeMB();

    // Resolution selection based on heap size:
    // ≤ 256MB: 720p (prevents MediaCodec crashes on truly constrained devices)
    // > 256MB: 1080p (prefer sharper playback, step down only when needed)
    if (heapSize <= 256) {
      _cachedRecommendedResolution = '720';
      developer.log('📱 DeviceCapability: Recommended resolution: 720p (low memory device)');
    } else {
      _cachedRecommendedResolution = '1080';
      developer.log('📱 DeviceCapability: Recommended resolution: 1080p (preferred sharp playback)');
    }

    return _cachedRecommendedResolution!;
  }

  /// Clear cached values (useful for testing)
  void clearCache() {
    _cachedHeapSizeMB = null;
    _cachedRecommendedResolution = null;
  }
}
