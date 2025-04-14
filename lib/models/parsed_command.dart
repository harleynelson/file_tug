// ./lib/models/parsed_command.dart (Entire File - Updated with Original Fields)

import 'package:flutter/foundation.dart'; // For @required annotation

// Enum remains the same
enum AssociationStatus {
  pending,
  notFound,
  foundSingle,
  foundMultiple,
  userSelected,
  lookupFailed,
}

class ParsedCommand {
  // Original text from speech/text input
  final String originalText;
  // Original entity text as parsed by Dialogflow
  final String? originalFileName;
  final String? originalContactName;
  final String? originalMessageBody;

  // Current entity text (can be updated by user interaction)
  final String? fileName;
  final String? contactName;
  final String? messageBody;

  // Status flags and resolved data
  final bool parseSuccess;
  final AssociationStatus fileStatus;
  final String? resolvedFilePath;
  final AssociationStatus contactStatus;
  final String? resolvedContactId;

  ParsedCommand({
    required this.originalText,
    // Original parsed values
    this.originalFileName,
    this.originalContactName,
    this.originalMessageBody,
    // Current values (initialize from original)
    this.fileName,
    this.contactName,
    this.messageBody,
    // Status fields
    this.parseSuccess = false,
    this.fileStatus = AssociationStatus.pending,
    this.resolvedFilePath,
    this.contactStatus = AssociationStatus.pending,
    this.resolvedContactId,
  });

  factory ParsedCommand.failure(String originalText) {
    return ParsedCommand(
      originalText: originalText,
      parseSuccess: false,
      fileStatus: AssociationStatus.pending,
      contactStatus: AssociationStatus.pending,
    );
  }

  // --- CopyWith Method (Updated for new fields) ---
  ParsedCommand copyWith({
    String? originalText,
    ValueGetter<String?>? originalFileName, // Less likely to change, but possible
    ValueGetter<String?>? originalContactName,
    ValueGetter<String?>? originalMessageBody,
    ValueGetter<String?>? fileName, // Current file name
    ValueGetter<String?>? contactName, // Current contact name
    ValueGetter<String?>? messageBody, // Current message
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
      originalMessageBody: originalMessageBody != null ? originalMessageBody() : this.originalMessageBody,
      // Update current values
      fileName: fileName != null ? fileName() : this.fileName,
      contactName: contactName != null ? contactName() : this.contactName,
      messageBody: messageBody != null ? messageBody() : this.messageBody,
      // Update status
      parseSuccess: parseSuccess ?? this.parseSuccess,
      fileStatus: fileStatus ?? this.fileStatus,
      resolvedFilePath: resolvedFilePath != null ? resolvedFilePath() : this.resolvedFilePath,
      contactStatus: contactStatus ?? this.contactStatus,
      resolvedContactId: resolvedContactId != null ? resolvedContactId() : this.resolvedContactId,
    );
  }
}

// Helper extension remains the same
extension OptionalValueGetter<T> on T? {
  ValueGetter<T?>? get asValueGetter => this == null ? null : () => this;
}