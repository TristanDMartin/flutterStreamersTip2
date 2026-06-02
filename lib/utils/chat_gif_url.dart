import 'dart:typed_data';

/// True when [raw] is a single HTTP(S) URL that should be stored as a GIF
/// message (direct file or known GIF CDN), not plain chat text.
bool shouldSendComposerInputAsRemoteGifUrl(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (trimmed.contains('\n') || trimmed.contains(' ')) {
    return false;
  }
  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    return false;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return false;
  }
  final String host = uri.host.toLowerCase();
  final String path = uri.path.toLowerCase();
  final String full = trimmed.toLowerCase();
  if (path.endsWith('.gif') || full.contains('.gif?')) {
    return true;
  }
  if (host.contains('media.giphy.com') || host == 'i.giphy.com') {
    return path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.mp4');
  }
  if (host.contains('tenor.com')) {
    return path.endsWith('.gif') ||
        path.contains('tenor.gif') ||
        full.contains('.gif?');
  }
  return false;
}

/// Best-effort extension for a pasted image byte header.
String fileExtensionForImageBytes(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return '.gif';
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return '.png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return '.jpg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46) {
    return '.webp';
  }
  return '.bin';
}
