// ./lib/models/parsed_command.dart (Entire File - Updated with Message Blocks)

import 'package:flutter/foundation.dart'; // For immutable and ValueGetter
import 'package:collection/collection.dart'; // For list equality

// Enum remains the same
enum AssociationStatus {
  pending,
  notFound,
  foundSingle,
  foundMultiple,
  userSelected,
  lookupFailed,
}

@immutable // Mark class as immutable
class ParsedCommand {
  // Original text from speech/text input
  final String originalText;
  // Original entity text as parsed by Dialogflow
  final String? originalFileName;
  final String? originalContactName;
  final List<String>? originalMessageBlocks; // *** CHANGED: List<String> ***

  // Current entity text (can be updated by user interaction)
  final String? fileName;
  final String? contactName;
  final List<String>? messageBlocks; // *** CHANGED: List<String> ***

  // Status flags and resolved data
  final bool parseSuccess;
  final AssociationStatus fileStatus;
  final String? resolvedFilePath;
  final AssociationStatus contactStatus;
  final String? resolvedContactId;

  // Use const constructor for immutability
  const ParsedCommand({
    required this.originalText,
    // Original parsed values
    this.originalFileName,
    this.originalContactName,
    this.originalMessageBlocks,
    // Current values (initialize from original)
    this.fileName,
    this.contactName,
    this.messageBlocks, // Initialize from original blocks if provided
    // Status fields
    this.parseSuccess = false,
    this.fileStatus = AssociationStatus.pending,
    this.resolvedFilePath,
    this.contactStatus = AssociationStatus.pending,
    this.resolvedContactId,
  });

  // Factory for failed parse (initializes lists as null)
  factory ParsedCommand.failure(String originalText) {
    return ParsedCommand(
      originalText: originalText,
      parseSuccess: false,
      fileStatus: AssociationStatus.pending,
      contactStatus: AssociationStatus.pending,
      // messageBlocks remain null
    );
  }

  // --- CopyWith Method (Updated for messageBlocks List) ---
  ParsedCommand copyWith({
    String? originalText,
    ValueGetter<String?>? originalFileName,
    ValueGetter<String?>? originalContactName,
    ValueGetter<List<String>?>? originalMessageBlocks, // Handle list
    ValueGetter<String?>? fileName,
    ValueGetter<String?>? contactName,
    ValueGetter<List<String>?>? messageBlocks, // Handle list
    bool? parseSuccess,
    AssociationStatus? fileStatus,
    ValueGetter<String?>? resolvedFilePath,
    AssociationStatus? contactStatus,
    ValueGetter<String?>? resolvedContactId,
  }) {
    return ParsedCommand(
      originalText: originalText ?? this.originalText,
      originalFileName: originalFileName != null ? originalFileName() : this.originalFileName,
      originalContactName: originalContactName != null ? originalContactName() : this.originalContactName,
      originalMessageBlocks: originalMessageBlocks != null ? originalMessageBlocks() : this.originalMessageBlocks,
      fileName: fileName != null ? fileName() : this.fileName,
      contactName: contactName != null ? contactName() : this.contactName,
      messageBlocks: messageBlocks != null ? messageBlocks() : this.messageBlocks, // Update list
      parseSuccess: parseSuccess ?? this.parseSuccess,
      fileStatus: fileStatus ?? this.fileStatus,
      resolvedFilePath: resolvedFilePath != null ? resolvedFilePath() : this.resolvedFilePath,
      contactStatus: contactStatus ?? this.contactStatus,
      resolvedContactId: resolvedContactId != null ? resolvedContactId() : this.resolvedContactId,
    );
  }

  // Override equality and hashCode for value comparison, including lists
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals; // Helper for lists

    return other is ParsedCommand &&
        other.originalText == originalText &&
        other.originalFileName == originalFileName &&
        other.originalContactName == originalContactName &&
        listEquals(other.originalMessageBlocks, originalMessageBlocks) && // Compare lists
        other.fileName == fileName &&
        other.contactName == contactName &&
        listEquals(other.messageBlocks, messageBlocks) && // Compare lists
        other.parseSuccess == parseSuccess &&
        other.fileStatus == fileStatus &&
        other.resolvedFilePath == resolvedFilePath &&
        other.contactStatus == contactStatus &&
        other.resolvedContactId == resolvedContactId;
  }

  @override
  int get hashCode {
    final listHash = const DeepCollectionEquality().hash; // Helper for lists
    return Object.hash(
      originalText,
      originalFileName,
      originalContactName,
      listHash(originalMessageBlocks), // Hash list
      fileName,
      contactName,
      listHash(messageBlocks), // Hash list
      parseSuccess,
      fileStatus,
      resolvedFilePath,
      contactStatus,
      resolvedContactId,
    );
  }

  // Optional: toString for debugging
  @override
  String toString() {
     return 'ParsedCommand(originalText: $originalText, ..., messageBlocks: $messageBlocks, fileStatus: $fileStatus, contactStatus: $contactStatus, ...)';
  }
}

// Helper extension remains useful
extension OptionalValueGetter<T> on T? {
  ValueGetter<T?>? get asValueGetter => this == null ? null : () => this;
}