import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const String sourcePath = 'assets/logo1-0.PNG';
const String outputSourcePath = 'assets/app_icon_ios.png';
const String appIconSetPath = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

const List<({String filename, int size})> iconOutputs = <({
  String filename,
  int size,
})>[
  (filename: 'Icon-App-20x20@1x.png', size: 20),
  (filename: 'Icon-App-20x20@2x.png', size: 40),
  (filename: 'Icon-App-20x20@3x.png', size: 60),
  (filename: 'Icon-App-29x29@1x.png', size: 29),
  (filename: 'Icon-App-29x29@2x.png', size: 58),
  (filename: 'Icon-App-29x29@3x.png', size: 87),
  (filename: 'Icon-App-40x40@1x.png', size: 40),
  (filename: 'Icon-App-40x40@2x.png', size: 80),
  (filename: 'Icon-App-40x40@3x.png', size: 120),
  (filename: 'Icon-App-50x50@1x.png', size: 50),
  (filename: 'Icon-App-50x50@2x.png', size: 100),
  (filename: 'Icon-App-57x57@1x.png', size: 57),
  (filename: 'Icon-App-57x57@2x.png', size: 114),
  (filename: 'Icon-App-60x60@2x.png', size: 120),
  (filename: 'Icon-App-60x60@3x.png', size: 180),
  (filename: 'Icon-App-72x72@1x.png', size: 72),
  (filename: 'Icon-App-72x72@2x.png', size: 144),
  (filename: 'Icon-App-76x76@1x.png', size: 76),
  (filename: 'Icon-App-76x76@2x.png', size: 152),
  (filename: 'Icon-App-83.5x83.5@2x.png', size: 167),
  (filename: 'Icon-App-1024x1024@1x.png', size: 1024),
];

void main() {
  final File sourceFile = File(sourcePath);
  final img.Image? source = img.decodePng(sourceFile.readAsBytesSync());
  if (source == null) {
    throw StateError('Could not decode $sourcePath');
  }

  final img.Image base = _buildFlatIcon(source);
  File(outputSourcePath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(base), flush: true);

  for (final output in iconOutputs) {
    final img.Image resized = output.size == 1024
        ? base
        : img.copyResize(
            base,
            width: output.size,
            height: output.size,
            interpolation: img.Interpolation.cubic,
          );
    File('$appIconSetPath/${output.filename}')
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(resized), flush: true);
  }
}

img.Image _buildFlatIcon(img.Image source) {
  const int size = 1024;
  final img.Image out = img.Image(width: size, height: size, numChannels: 3);

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final double t = ((x / (size - 1)) * 0.36) + ((y / (size - 1)) * 0.64);
      final int r = _lerp(113, 47, t);
      final int g = _lerp(72, 85, t);
      final int b = _lerp(166, 159, t);
      out.setPixelRgb(x, y, r, g, b);
    }
  }

  final img.Image scaledSource = source.width == size && source.height == size
      ? source
      : img.copyResize(
          source,
          width: size,
          height: size,
          interpolation: img.Interpolation.cubic,
        );

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final img.Pixel p = scaledSource.getPixel(x, y);
      final int minWhite =
          math.min(p.r.toInt(), math.min(p.g.toInt(), p.b.toInt()));
      final double whiteMask = ((minWhite - 184) / 64).clamp(0.0, 1.0);
      final double sourceAlpha = (p.a / 255.0).clamp(0.0, 1.0);
      final double alpha = whiteMask * sourceAlpha;
      if (alpha <= 0) continue;

      final img.Pixel bg = out.getPixel(x, y);
      final int r = _blend(bg.r.toInt(), 255, alpha);
      final int g = _blend(bg.g.toInt(), 255, alpha);
      final int b = _blend(bg.b.toInt(), 255, alpha);
      out.setPixelRgb(x, y, r, g, b);
    }
  }

  return out;
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);

int _blend(int bg, int fg, double alpha) =>
    (bg + (fg - bg) * alpha).round().clamp(0, 255);
