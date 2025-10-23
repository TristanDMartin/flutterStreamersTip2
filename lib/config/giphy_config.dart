class GiphyConfig {
  // Get your API key from: https://developers.giphy.com/dashboard/
  // Create a new app and copy the API key here
  static const String apiKey = 'zOK2LZy29pRogSSUS2vWnLJmbOCokVzi';

  // Fallback demo key (may be rate-limited)
  static const String fallbackApiKey = 'dc6zaTOxFJmzC';

  // Get the best available API key
  static String get bestApiKey {
    // Try the main API key first, fallback to demo key
    return apiKey.isNotEmpty ? apiKey : fallbackApiKey;
  }
}
