import 'package:freezed_annotation/freezed_annotation.dart';
import 'user.dart';
import 'json_converters.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

@freezed
sealed class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    @UserConverter() required User user,
    required String token,
    String? refreshToken,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
}

@freezed
sealed class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required String email,
    required String password,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
}

@freezed
sealed class SignupRequest with _$SignupRequest {
  const factory SignupRequest({
    required String username,
    required String email,
    required String password,
  }) = _SignupRequest;

  factory SignupRequest.fromJson(Map<String, dynamic> json) => _$SignupRequestFromJson(json);
}
