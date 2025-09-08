import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class SecurityService {
  static SecurityService? _instance;
  static SecurityService get instance => _instance ??= SecurityService._();
  
  SecurityService._();
  
  // Validate email format
  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }
  
  // Validate username format
  bool isValidUsername(String username) {
    // Username should be 3-20 characters, alphanumeric and underscores only
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    return usernameRegex.hasMatch(username);
  }
  
  // Validate password strength
  bool isValidPassword(String password) {
    // Password should be at least 8 characters with mix of letters, numbers, and symbols
    if (password.length < 8) return false;
    
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbol = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    
    return hasLetter && hasNumber && hasSymbol;
  }
  
  // Sanitize user input
  String sanitizeInput(String input) {
    // Remove potentially dangerous characters
    String sanitized = input.replaceAll('<', '').replaceAll('>', '').replaceAll('"', '').replaceAll("'", '');
    sanitized = sanitized.replaceAll(RegExp(r'[^\w\s@.-]'), ''); // Keep only alphanumeric, spaces, @, ., -
    return sanitized.trim();
  }
  
  // Validate URL format
  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
  
  // Validate phone number format
  bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }
  
  // Validate file extension
  bool isValidFileExtension(String filename, List<String> allowedExtensions) {
    final extension = filename.split('.').last.toLowerCase();
    return allowedExtensions.contains(extension);
  }
  
  // Validate file size
  bool isValidFileSize(int fileSizeInBytes, {int maxSizeInMB = 10}) {
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024;
    return fileSizeInBytes <= maxSizeInBytes;
  }
  
  // Validate image dimensions
  bool isValidImageDimensions(int width, int height, {int maxWidth = 4096, int maxHeight = 4096}) {
    return width > 0 && height > 0 && width <= maxWidth && height <= maxHeight;
  }
  
  // Check for SQL injection patterns
  bool containsSqlInjection(String input) {
    final upperInput = input.toUpperCase();
    final sqlKeywords = ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE', 'ALTER', 'EXEC', 'UNION', 'SCRIPT'];
    return sqlKeywords.any((keyword) => upperInput.contains(keyword));
  }
  
  // Check for XSS patterns
  bool containsXss(String input) {
    final upperInput = input.toUpperCase();
    final xssPatterns = ['<SCRIPT', 'JAVASCRIPT:', 'VBSCRIPT:', 'ONLOAD=', 'ONERROR=', 'ONCLICK=', 'ONMOUSEOVER=', '<IFRAME', '<OBJECT', '<EMBED'];
    return xssPatterns.any((pattern) => upperInput.contains(pattern));
  }
  
  // Escape HTML characters
  String escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }
  
  // Escape SQL characters
  String escapeSql(String input) {
    return input
        .replaceAll("'", "''")
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
  
  // Generate secure hash
  String generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Generate secure random string
  String generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }
  
  // Validate input against security rules
  bool validateInput(String input, {
    int? minLength,
    int? maxLength,
    bool checkSqlInjection = true,
    bool checkXss = true,
    bool allowSpecialChars = false,
  }) {
    // Check length constraints
    if (minLength != null && input.length < minLength) return false;
    if (maxLength != null && input.length > maxLength) return false;
    
    // Check for SQL injection
    if (checkSqlInjection && containsSqlInjection(input)) return false;
    
    // Check for XSS
    if (checkXss && containsXss(input)) return false;
    
    // Check for special characters if not allowed
    if (!allowSpecialChars && (input.contains('<') || input.contains('>') || input.contains('"') || input.contains("'"))) return false;
    
    return true;
  }
  
  // Validate file upload
  bool validateFileUpload(String filename, int fileSizeInBytes, {
    List<String> allowedExtensions = const ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx'],
    int maxSizeInMB = 10,
    int maxWidth = 4096,
    int maxHeight = 4096,
  }) {
    // Check file extension
    if (!isValidFileExtension(filename, allowedExtensions)) return false;
    
    // Check file size
    if (!isValidFileSize(fileSizeInBytes, maxSizeInMB: maxSizeInMB)) return false;
    
    return true;
  }
  
  // Sanitize HTML content
  String sanitizeHtml(String html) {
    // Remove script tags and their content
    String sanitized = html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '');
    
    // Remove event handlers - simplified approach
    sanitized = sanitized.replaceAll(RegExp(r'\s+on\w+\s*=', caseSensitive: false), '');
    
    // Remove javascript: and vbscript: protocols
    sanitized = sanitized.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'vbscript:', caseSensitive: false), '');
    
    return sanitized;
  }
  
  // Validate and sanitize user input
  String validateAndSanitizeInput(String input, {
    int? minLength,
    int? maxLength,
    bool checkSqlInjection = true,
    bool checkXss = true,
    bool allowSpecialChars = false,
  }) {
    // First validate
    if (!validateInput(input, 
        minLength: minLength, 
        maxLength: maxLength, 
        checkSqlInjection: checkSqlInjection, 
        checkXss: checkXss, 
        allowSpecialChars: allowSpecialChars)) {
      throw ArgumentError('Input validation failed');
    }
    
    // Then sanitize
    return sanitizeInput(input);
  }
}