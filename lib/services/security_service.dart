import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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
    return input
        .replaceAll(RegExp(r'[<>"\']'), '') // Remove HTML/JS characters
        .replaceAll(RegExp(r'[^\w\s@.-]'), '') // Keep only alphanumeric, spaces, @, ., -
        .trim();
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
  
  // Hash sensitive data
  String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Generate secure token
  String generateSecureToken() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(random);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }
  
  // Validate image URL
  bool isValidImageUrl(String url) {
    if (!isValidUrl(url)) return false;
    
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'];
    final lowerUrl = url.toLowerCase();
    
    return imageExtensions.any((ext) => lowerUrl.contains(ext));
  }
  
  // Validate file size (in bytes)
  bool isValidFileSize(int fileSizeBytes, int maxSizeMB) {
    final maxSizeBytes = maxSizeMB * 1024 * 1024;
    return fileSizeBytes <= maxSizeBytes;
  }
  
  // Validate image dimensions
  bool isValidImageDimensions(int width, int height, {int maxWidth = 4096, int maxHeight = 4096}) {
    return width > 0 && height > 0 && width <= maxWidth && height <= maxHeight;
  }
  
  // Check for SQL injection patterns
  bool containsSqlInjection(String input) {
    final sqlPatterns = [
      r'(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|SCRIPT)\b)',
      r'(\b(OR|AND)\s+\d+\s*=\s*\d+)',
      r'(\b(OR|AND)\s+\w+\s*=\s*\w+)',
      r'(\b(OR|AND)\s+\w+\s*LIKE\s*[\'"])',
      r'(\b(OR|AND)\s+\w+\s*IN\s*[\'"])',
      r'(\b(OR|AND)\s+\w+\s*BETWEEN\s+[\'"])',
      r'(\b(OR|AND)\s+\w+\s*IS\s+NULL)',
      r'(\b(OR|AND)\s+\w+\s*IS\s+NOT\s+NULL)',
      r'(\b(OR|AND)\s+\w+\s*EXISTS\s*[\'"])',
      r'(\b(OR|AND)\s+\w+\s*NOT\s+EXISTS\s*[\'"])',
    ];
    
    final upperInput = input.toUpperCase();
    return sqlPatterns.any((pattern) => RegExp(pattern, caseSensitive: false).hasMatch(upperInput));
  }
  
  // Check for XSS patterns
  bool containsXss(String input) {
    final xssPatterns = [
      r'<script[^>]*>.*?</script>',
      r'<iframe[^>]*>.*?</iframe>',
      r'<object[^>]*>.*?</object>',
      r'<embed[^>]*>.*?</embed>',
      r'<applet[^>]*>.*?</applet>',
      r'<form[^>]*>.*?</form>',
      r'<input[^>]*>.*?</input>',
      r'<button[^>]*>.*?</button>',
      r'<select[^>]*>.*?</select>',
      r'<textarea[^>]*>.*?</textarea>',
      r'<link[^>]*>.*?</link>',
      r'<meta[^>]*>.*?</meta>',
      r'<style[^>]*>.*?</style>',
      r'<link[^>]*>.*?</link>',
      r'<meta[^>]*>.*?</meta>',
      r'<style[^>]*>.*?</style>',
      r'javascript:',
      r'vbscript:',
      r'data:',
      r'<img[^>]*onerror[^>]*>',
      r'<img[^>]*onload[^>]*>',
      r'<img[^>]*onclick[^>]*>',
      r'<img[^>]*onmouseover[^>]*>',
      r'<img[^>]*onmouseout[^>]*>',
      r'<img[^>]*onmousedown[^>]*>',
      r'<img[^>]*onmouseup[^>]*>',
      r'<img[^>]*onmousemove[^>]*>',
      r'<img[^>]*onmouseenter[^>]*>',
      r'<img[^>]*onmouseleave[^>]*>',
      r'<img[^>]*onfocus[^>]*>',
      r'<img[^>]*onblur[^>]*>',
      r'<img[^>]*onchange[^>]*>',
      r'<img[^>]*onsubmit[^>]*>',
      r'<img[^>]*onreset[^>]*>',
      r'<img[^>]*onselect[^>]*>',
      r'<img[^>]*onkeydown[^>]*>',
      r'<img[^>]*onkeyup[^>]*>',
      r'<img[^>]*onkeypress[^>]*>',
      r'<img[^>]*oncontextmenu[^>]*>',
      r'<img[^>]*ondblclick[^>]*>',
      r'<img[^>]*onabort[^>]*>',
      r'<img[^>]*onerror[^>]*>',
      r'<img[^>]*onload[^>]*>',
      r'<img[^>]*onresize[^>]*>',
      r'<img[^>]*onscroll[^>]*>',
      r'<img[^>]*onunload[^>]*>',
      r'<img[^>]*onbeforeunload[^>]*>',
      r'<img[^>]*onhashchange[^>]*>',
      r'<img[^>]*onpagehide[^>]*>',
      r'<img[^>]*onpageshow[^>]*>',
      r'<img[^>]*onpopstate[^>]*>',
      r'<img[^>]*onstorage[^>]*>',
      r'<img[^>]*ononline[^>]*>',
      r'<img[^>]*onoffline[^>]*>',
      r'<img[^>]*onmessage[^>]*>',
      r'<img[^>]*onerror[^>]*>',
      r'<img[^>]*onload[^>]*>',
      r'<img[^>]*onclick[^>]*>',
      r'<img[^>]*onmouseover[^>]*>',
      r'<img[^>]*onmouseout[^>]*>',
      r'<img[^>]*onmousedown[^>]*>',
      r'<img[^>]*onmouseup[^>]*>',
      r'<img[^>]*onmousemove[^>]*>',
      r'<img[^>]*onmouseenter[^>]*>',
      r'<img[^>]*onmouseleave[^>]*>',
      r'<img[^>]*onfocus[^>]*>',
      r'<img[^>]*onblur[^>]*>',
      r'<img[^>]*onchange[^>]*>',
      r'<img[^>]*onsubmit[^>]*>',
      r'<img[^>]*onreset[^>]*>',
      r'<img[^>]*onselect[^>]*>',
      r'<img[^>]*onkeydown[^>]*>',
      r'<img[^>]*onkeyup[^>]*>',
      r'<img[^>]*onkeypress[^>]*>',
      r'<img[^>]*oncontextmenu[^>]*>',
      r'<img[^>]*ondblclick[^>]*>',
      r'<img[^>]*onabort[^>]*>',
      r'<img[^>]*onerror[^>]*>',
      r'<img[^>]*onload[^>]*>',
      r'<img[^>]*onresize[^>]*>',
      r'<img[^>]*onscroll[^>]*>',
      r'<img[^>]*onunload[^>]*>',
      r'<img[^>]*onbeforeunload[^>]*>',
      r'<img[^>]*onhashchange[^>]*>',
      r'<img[^>]*onpagehide[^>]*>',
      r'<img[^>]*onpageshow[^>]*>',
      r'<img[^>]*onpopstate[^>]*>',
      r'<img[^>]*onstorage[^>]*>',
      r'<img[^>]*ononline[^>]*>',
      r'<img[^>]*onoffline[^>]*>',
      r'<img[^>]*onmessage[^>]*>',
    ];
    
    return xssPatterns.any((pattern) => RegExp(pattern, caseSensitive: false).hasMatch(input));
  }
  
  // Validate and sanitize user input
  String validateAndSanitizeInput(String input, {bool allowHtml = false}) {
    if (input.isEmpty) return input;
    
    // Check for SQL injection
    if (containsSqlInjection(input)) {
      debugPrint('🚨 SQL injection attempt detected');
      return '';
    }
    
    // Check for XSS
    if (!allowHtml && containsXss(input)) {
      debugPrint('🚨 XSS attempt detected');
      return '';
    }
    
    // Sanitize input
    return sanitizeInput(input);
  }
  
  // Rate limiting check
  bool isRateLimited(String userId, String action, {int maxAttempts = 10, Duration window = const Duration(minutes: 1)}) {
    // This would typically use a cache or database to track attempts
    // For now, return false (not rate limited)
    return false;
  }
  
  // Validate file upload
  bool isValidFileUpload(String fileName, int fileSize, List<String> allowedExtensions) {
    if (fileName.isEmpty) return false;
    
    final extension = fileName.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) return false;
    
    const maxFileSize = 10 * 1024 * 1024; // 10MB
    if (fileSize > maxFileSize) return false;
    
    return true;
  }
}
