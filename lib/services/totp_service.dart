import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TotpService {
  final int _period = 30;

  /// Generate a TOTP secret
  String generateSecret() {
    final random = List<int>.generate(
        20, (i) => DateTime.now().microsecondsSinceEpoch % 256);
    return base32Encode(Uint8List.fromList(random)).substring(0, 32);
  }

  /// Generate TOTP code
  String generateCode(String secret) {
    try {
      final now = DateTime.now();
      final timeCounter = (now.millisecondsSinceEpoch ~/ 1000) ~/ _period;

      final secretBytes = base32Decode(secret);
      final timeBytes = _intToBytes(timeCounter);

      final hmac = Hmac(sha1, secretBytes);
      final hash = hmac.convert(timeBytes).bytes;

      final offset = hash[hash.length - 1] & 0x0f;
      final binary = ((hash[offset] & 0x7f) << 24) |
          ((hash[offset + 1] & 0xff) << 16) |
          ((hash[offset + 2] & 0xff) << 8) |
          (hash[offset + 3] & 0xff);

      final code = binary % 1000000;
      return code.toString().padLeft(6, '0');
    } catch (e) {
      return '000000';
    }
  }

  /// Verify TOTP code
  bool verifyCode({required String secret, required String code}) {
    final currentCode = generateCode(secret);

    if (currentCode == code) return true;

    final previousCounter =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ _period - 1;
    final previousCode = _generateCodeForCounter(secret, previousCounter);

    return previousCode == code;
  }

  String _generateCodeForCounter(String secret, int counter) {
    try {
      final secretBytes = base32Decode(secret);
      final timeBytes = _intToBytes(counter);

      final hmac = Hmac(sha1, secretBytes);
      final hash = hmac.convert(timeBytes).bytes;

      final offset = hash[hash.length - 1] & 0x0f;
      final binary = ((hash[offset] & 0x7f) << 24) |
          ((hash[offset + 1] & 0xff) << 16) |
          ((hash[offset + 2] & 0xff) << 8) |
          (hash[offset + 3] & 0xff);

      final code = binary % 1000000;
      return code.toString().padLeft(6, '0');
    } catch (e) {
      return '000000';
    }
  }

  List<int> _intToBytes(int value) {
    final bytes = <int>[];
    for (int i = 7; i >= 0; i--) {
      bytes.add((value >> (i * 8)) & 0xff);
    }
    return bytes;
  }

  Uint8List base32Decode(String input) {
    const String base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final normalized = input.toUpperCase().replaceAll('=', '');

    final bits = normalized
        .split('')
        .map((char) {
          final index = base32Chars.indexOf(char);
          if (index == -1) return [];
          return index.toRadixString(2).padLeft(5, '0').split('');
        })
        .expand((x) => x)
        .toList();

    final bytes = <int>[];
    for (int i = 0; i < bits.length; i += 8) {
      if (i + 8 > bits.length) break;
      final byteBits = bits.sublist(i, i + 8).join('');
      bytes.add(int.parse(byteBits, radix: 2));
    }

    return Uint8List.fromList(bytes);
  }

  String base32Encode(Uint8List input) {
    const String base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final bits = input.map((byte) {
      return byte.toRadixString(2).padLeft(8, '0');
    }).join('');

    final chars = <String>[];
    for (int i = 0; i < bits.length; i += 5) {
      if (i + 5 > bits.length) break;
      final bitGroup = bits.substring(i, i + 5);
      final index = int.parse(bitGroup, radix: 2);
      chars.add(base32Chars[index]);
    }

    return chars.join('');
  }
}
