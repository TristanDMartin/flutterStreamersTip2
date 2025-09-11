import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodeGenerator {
  static Widget generateQRCode({
    required String data,
    double size = 200,
    Color foregroundColor = Colors.black,
    Color backgroundColor = Colors.white,
  }) {
    // print('🔍 QRCodeGenerator: Starting generation for string: $data');
    // print('🔍 QRCodeGenerator: Size: $size');

    if (data.isEmpty) {
    // print('❌ QR Code: Empty string provided');
      return Container(
        width: size,
        height: size,
        color: Colors.grey,
        child: const Icon(Icons.error, color: Colors.white),
      );
    }

    // print('🔍 QRCodeGenerator: Data length: ${data.length}');

    try {
      final qrCode = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: foregroundColor,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: foregroundColor,
        ),
        gapless: false,
        embeddedImage: null,
        embeddedImageStyle: null,
        // embeddedImageEmitsError removed (not supported by current qr_flutter)
      );

    // print('🔍 QRCodeGenerator: QrPainter created successfully');
    // print('✅ QR Code: Generated successfully for string: $data');

      return CustomPaint(
        size: Size(size, size),
        painter: qrCode,
      );
    } catch (e) {
    // print('❌ QRCodeGenerator: Error generating QR code: $e');
      return Container(
        width: size,
        height: size,
        color: Colors.grey,
        child: const Icon(Icons.error, color: Colors.white),
      );
    }
  }

  static Widget generateProfileQRCode({
    required String username,
    double size = 200,
    Color foregroundColor = Colors.black,
    Color backgroundColor = Colors.white,
  }) {
    final profileURL = 'streamerstip://profile/$username';
    return generateQRCode(
      data: profileURL,
      size: size,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
    );
  }

  // Alternative method using QrImageView for better performance
  static Widget generateQRCodeImage({
    required String data,
    double size = 200,
    Color foregroundColor = Colors.black,
    Color backgroundColor = Colors.white,
  }) {
    // print('🔍 QRCodeGenerator: Starting generation with QrImageView for string: $data');
    // print('🔍 QRCodeGenerator: Size: $size');

    if (data.isEmpty) {
    // print('❌ QR Code: Empty string provided');
      return Container(
        width: size,
        height: size,
        color: Colors.grey,
        child: const Icon(Icons.error, color: Colors.white),
      );
    }

    // print('🔍 QRCodeGenerator: Data length: ${data.length}');

    try {
      final qrCode = QrImageView(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        size: size,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: foregroundColor,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: foregroundColor,
        ),
        backgroundColor: backgroundColor,
        embeddedImage: null,
        embeddedImageStyle: null,
        // embeddedImageEmitsError removed (not supported by current qr_flutter)
      );

    // print('🔍 QRCodeGenerator: QrImageView created successfully');
    // print('✅ QR Code: Generated successfully with QrImageView for string: $data');

      return qrCode;
    } catch (e) {
    // print('❌ QRCodeGenerator: Error generating QR code with QrImageView: $e');
      return Container(
        width: size,
        height: size,
        color: Colors.grey,
        child: const Icon(Icons.error, color: Colors.white),
      );
    }
  }

  static Widget generateProfileQRCodeImage({
    required String username,
    double size = 200,
    Color foregroundColor = Colors.black,
    Color backgroundColor = Colors.white,
  }) {
    final profileURL = 'streamerstip://profile/$username';
    return generateQRCodeImage(
      data: profileURL,
      size: size,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
    );
  }
}
