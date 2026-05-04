/// [widthOverHeight] is [VideoPlayerController.value.aspectRatio]
/// (same as size.width / size.height).
bool shouldLetterboxNonVerticalAspectRatio(double widthOverHeight) {
  const double targetVerticalAspectRatio = 9 / 16;
  const double verticalTolerance = 0.09;
  if (widthOverHeight <= 0) {
    return true;
  }
  return (widthOverHeight - targetVerticalAspectRatio).abs() >
      verticalTolerance;
}
