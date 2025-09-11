import 'package:flutter/material.dart';

class CustomTextFieldStyle extends InputDecoration {
  const CustomTextFieldStyle({
    super.hintText,
    super.labelText,
    super.prefixIcon,
    super.suffixIcon,
    super.errorText,
  });

  @override
  InputBorder? get border => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: Colors.grey.withValues(alpha:0.3),
      width: 1,
    ),
  );

  @override
  InputBorder? get enabledBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: Colors.grey.withValues(alpha:0.3),
      width: 1,
    ),
  );

  @override
  InputBorder? get focusedBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: Colors.grey.withValues(alpha:0.5),
      width: 2,
    ),
  );

  @override
  InputBorder? get errorBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: Colors.red.withValues(alpha:0.5),
      width: 1,
    ),
  );

  @override
  InputBorder? get focusedErrorBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: Colors.red.withValues(alpha:0.7),
      width: 2,
    ),
  );

  @override
  Color? get fillColor => Colors.grey.withValues(alpha:0.2);

  @override
  bool get filled => true;

  @override
  EdgeInsetsGeometry? get contentPadding => const EdgeInsets.all(16);

  @override
  TextStyle? get hintStyle => TextStyle(
    color: Colors.grey.withValues(alpha:0.7),
    fontSize: 16,
  );

  @override
  TextStyle? get labelStyle => TextStyle(
    color: Colors.grey.withValues(alpha:0.7),
    fontSize: 16,
  );

  @override
  TextStyle? get errorStyle => TextStyle(
    color: Colors.red.withValues(alpha:0.8),
    fontSize: 14,
  );
}
