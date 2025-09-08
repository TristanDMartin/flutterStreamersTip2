import 'package:freezed_annotation/freezed_annotation.dart';
import 'home_video.dart';

part 'home_notifier.freezed.dart';

@freezed
class HomeNotifier with _$HomeNotifier {
  const factory HomeNotifier({
    @Default([]) List<HomeVideo> videos,
    @Default(false) bool isLoading,
    @Default('') String error,
  }) = _HomeNotifier;
}
