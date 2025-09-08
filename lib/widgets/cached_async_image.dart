import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CachedAsyncImage extends StatelessWidget {
  final String? url;
  final Widget Function(AsyncImagePhase) content;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const CachedAsyncImage({
    super.key,
    required this.url,
    required this.content,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return content(AsyncImagePhase.failure());
    }

    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) => content(AsyncImagePhase.empty()),
      errorWidget: (context, url, error) => content(AsyncImagePhase.failure()),
      imageBuilder: (context, imageProvider) {
        return content(AsyncImagePhase.success(imageProvider));
      },
    );
  }
}

// Enum to match SwiftUI's AsyncImagePhase
// Represent AsyncImage phases without enhanced enums for wider SDK support
abstract class AsyncImagePhase {
  const AsyncImagePhase();
  factory AsyncImagePhase.empty() = _AsyncEmpty;
  factory AsyncImagePhase.failure() = _AsyncFailure;
  factory AsyncImagePhase.success(ImageProvider imageProvider) = AsyncImagePhaseSuccess;
}

class _AsyncEmpty extends AsyncImagePhase {
  const _AsyncEmpty();
}

class _AsyncFailure extends AsyncImagePhase {
  const _AsyncFailure();
}

// Extension to make the enum more usable
extension AsyncImagePhaseExtension on AsyncImagePhase {
  bool get isSuccess => this is AsyncImagePhaseSuccess;
  bool get isEmpty => this is _AsyncEmpty;
  bool get isFailure => this is _AsyncFailure;
  ImageProvider? get imageProvider => this is AsyncImagePhaseSuccess
      ? (this as AsyncImagePhaseSuccess).imageProvider
      : null;
}

// Helper class for success phase
class AsyncImagePhaseSuccess extends AsyncImagePhase {
  final ImageProvider imageProvider;
  AsyncImagePhaseSuccess(this.imageProvider) : super();
}

// Usage example widget
class CachedAsyncImageExample extends StatelessWidget {
  const CachedAsyncImageExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CachedAsyncImage(
      url: "https://example.com/image.jpg",
      content: (phase) {
        switch (phase) {
          case _AsyncEmpty():
            return const Center(
              child: CircularProgressIndicator(),
            );
          case AsyncImagePhaseSuccess():
            return Image(
              image: phase.imageProvider,
              fit: BoxFit.cover,
            );
          case _AsyncFailure():
            return const Center(
              child: Icon(
                Icons.photo,
                color: Colors.grey,
                size: 48,
              ),
            );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
