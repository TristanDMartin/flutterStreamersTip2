import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';

@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required String icon,
    required Color color,
  }) = _Category;

  static const List<Category> samples = [
    Category(id: "gaming", name: "Gaming", icon: "videogame_asset", color: Colors.purple),
    Category(id: "art", name: "Art", icon: "brush", color: Colors.blue),
    Category(id: "music", name: "Music", icon: "music_note", color: Colors.pink),
    Category(id: "tech", name: "Tech", icon: "laptop", color: Colors.green),
    Category(id: "sports", name: "Sports", icon: "sports_soccer", color: Colors.orange),
    Category(id: "food", name: "Food", icon: "restaurant", color: Colors.red),
    Category(id: "just-chatting", name: "Just Chatting", icon: "chat", color: Colors.cyan),
    Category(id: "tutorials", name: "Tutorials", icon: "menu_book", color: Colors.indigo),
    Category(id: "fitness", name: "Fitness", icon: "fitness_center", color: Colors.teal),
    Category(id: "podcasts", name: "Podcasts", icon: "mic", color: Colors.brown),
    Category(id: "fashion", name: "Fashion", icon: "checkroom", color: Colors.purple),
    Category(id: "roleplay", name: "Roleplay", icon: "theater_comedy", color: Colors.yellow),
  ];
}
