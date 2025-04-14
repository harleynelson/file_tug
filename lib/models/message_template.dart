// ./lib/models/message_template.dart (New File)

import 'package:flutter/foundation.dart'; // For @required and immutable
import 'package:uuid/uuid.dart'; // For generating unique IDs

@immutable // Mark class as immutable
class MessageTemplate {
  final String id;
  final String category;
  final String title;
  final String text;

  MessageTemplate({
    required this.id,
    required this.category,
    required this.title,
    required this.text,
  });

  // Factory constructor to create a new template with a generated ID
  factory MessageTemplate.create({
    required String category,
    required String title,
    required String text,
  }) {
    return MessageTemplate(
      id: const Uuid().v4(), // Generate a unique v4 UUID
      category: category,
      title: title,
      text: text,
    );
  }

  // Method to create a MessageTemplate instance from a JSON map
  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      id: json['id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      text: json['text'] as String,
    );
  }

  // Method to convert a MessageTemplate instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'text': text,
    };
  }

  // Optional: Override equality and hashCode for comparisons if needed
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // Optional: toString for easier debugging
  @override
  String toString() {
    return 'MessageTemplate{id: $id, category: $category, title: $title, text: $text}';
  }

   // Optional: copyWith method for easier updates
   MessageTemplate copyWith({
       String? id,
       String? category,
       String? title,
       String? text,
   }) {
       return MessageTemplate(
           id: id ?? this.id,
           category: category ?? this.category,
           title: title ?? this.title,
           text: text ?? this.text,
       );
   }
}