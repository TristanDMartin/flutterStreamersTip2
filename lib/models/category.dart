import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';

@freezed
sealed class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required String icon,
    required Color color,
  }) = _Category;

  static const List<Category> samples = [
    Category(
        id: "All",
        name: "All",
        icon: "square.grid.2x2",
        color: Color(0xFF40DCD1)),
    Category(
        id: "general",
        name: "General",
        icon: "sparkles",
        color: Color(0xFF607D8B)),
    Category(
        id: "gaming",
        name: "Gaming",
        icon: "gamecontroller.fill",
        color: Color(0xFF9C27B0)),
    Category(
        id: "art",
        name: "Art",
        icon: "paintbrush.fill",
        color: Color(0xFF2196F3)),
    Category(
        id: "music",
        name: "Music",
        icon: "music.note",
        color: Color(0xFFF44336)),
    Category(
        id: "tech",
        name: "Tech",
        icon: "laptopcomputer",
        color: Color(0xFF4CAF50)),
    Category(
        id: "sports",
        name: "Sports",
        icon: "sportscourt.fill",
        color: Color(0xFFFF9800)),
    Category(
        id: "food", name: "Food", icon: "fork.knife", color: Color(0xFFE91E63)),
    Category(
        id: "just-chatting",
        name: "Just Chatting",
        icon: "message.fill",
        color: Color(0xFF00BCD4)),
    Category(
        id: "tutorials",
        name: "Tutorials",
        icon: "book.fill",
        color: Color(0xFF3F51B5)),
    Category(
        id: "fitness",
        name: "Fitness",
        icon: "figure.run",
        color: Color(0xFF009688)),
    Category(
        id: "podcasts",
        name: "Podcasts",
        icon: "mic.fill",
        color: Color(0xFF795548)),
    Category(
        id: "fashion",
        name: "Fashion",
        icon: "tshirt.fill",
        color: Color(0xFF9C27B0)),
    Category(
        id: "roleplay",
        name: "Roleplay",
        icon: "theatermasks.fill",
        color: Color(0xFFFFC107)),
  ];
}
