import 'package:freezed_annotation/freezed_annotation.dart';

part 'ml_score.freezed.dart';
part 'ml_score.g.dart';

@freezed
sealed class MLScore with _$MLScore {
  const factory MLScore({
    required double value,
    required String type,
  }) = _MLScore;

  factory MLScore.fromJson(Map<String, dynamic> json) => _$MLScoreFromJson(json);
}
