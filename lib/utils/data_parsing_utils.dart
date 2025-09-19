/// Data Parsing Utilities
/// 
/// This file contains utility functions for safely parsing data from Firestore
/// and other sources, handling type mismatches gracefully.
library data_parsing_utils;

/// Safely parse a dynamic value as a list of strings
/// Handles cases where the data might be a string, list, or other type
List<String> parseStringList(dynamic data) {
  if (data == null) return [];
  
  if (data is List) {
    return data.map((e) => e.toString()).toList();
  }
  
  if (data is String) {
    // If it's a string, try to parse it as a comma-separated list
    if (data.isEmpty) return [];
    return data.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  
  // If it's any other type, convert to string and return as single item
  return [data.toString()];
}

/// Safely parse a dynamic value as a list of any type
/// Handles cases where the data might be a string, list, or other type
List<T> parseList<T>(dynamic data, T Function(dynamic) converter) {
  if (data == null) return [];
  
  if (data is List) {
    return data.map((e) => converter(e)).toList();
  }
  
  if (data is String) {
    // If it's a string, try to parse it as a comma-separated list
    if (data.isEmpty) return [];
    return data.split(',').map((e) => converter(e.trim())).where((e) => e != null).cast<T>().toList();
  }
  
  // If it's any other type, convert and return as single item
  return [converter(data)];
}

/// Safely parse a dynamic value as a map
/// Handles cases where the data might be a string, map, or other type
Map<String, dynamic> parseMap(dynamic data) {
  if (data == null) return {};
  
  if (data is Map<String, dynamic>) {
    return data;
  }
  
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  
  if (data is String) {
    // Try to parse as JSON
    try {
      // This would need json.decode for actual JSON parsing
      // For now, return empty map
      return {};
    } catch (e) {
      return {};
    }
  }
  
  // If it's any other type, return empty map
  return {};
}

/// Safely parse a dynamic value as an integer
/// Handles cases where the data might be a string, int, or other type
int parseInteger(dynamic data, {int defaultValue = 0}) {
  if (data == null) return defaultValue;
  
  if (data is int) return data;
  
  if (data is String) {
    return int.tryParse(data) ?? defaultValue;
  }
  
  if (data is double) {
    return data.toInt();
  }
  
  return defaultValue;
}

/// Safely parse a dynamic value as a double
/// Handles cases where the data might be a string, double, or other type
double parseDouble(dynamic data, {double defaultValue = 0.0}) {
  if (data == null) return defaultValue;
  
  if (data is double) return data;
  
  if (data is int) return data.toDouble();
  
  if (data is String) {
    return double.tryParse(data) ?? defaultValue;
  }
  
  return defaultValue;
}

/// Safely parse a dynamic value as a boolean
/// Handles cases where the data might be a string, bool, or other type
bool parseBoolean(dynamic data, {bool defaultValue = false}) {
  if (data == null) return defaultValue;
  
  if (data is bool) return data;
  
  if (data is String) {
    return data.toLowerCase() == 'true' || data == '1';
  }
  
  if (data is int) {
    return data != 0;
  }
  
  return defaultValue;
}
