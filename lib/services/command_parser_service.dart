// ./lib/services/command_parser_service.dart (Entire File - Revised Logic)

import '../models/parsed_command.dart'; // Adjust path if needed
import 'package:collection/collection.dart'; // Import for firstWhereOrNull

// Helper class to store marker finding results
class _MarkerInfo {
  final String marker;
  final int index;
  _MarkerInfo(this.marker, this.index);
}

class CommandParserService {
  // Define keywords and markers
  final Set<String> _actionKeywords = const {'send', 'email', 'text'};
  final Set<String> _recipientMarkers = const {'to'}; // Only 'to' for recipient identification
  final Set<String> _messageMarkers = const {
    // Add 'note', prioritize longer phrases
    'with the message', 'with message', 'with a note',
    'saying', 'and write', 'telling them', 'message', 'note'
    };

  // Helper to find the first occurrence of any marker from a set after a start index
  _MarkerInfo? _findFirstMarker(String lowerText, Set<String> markers, int startIndex) {
    _MarkerInfo? earliestMatch;

    // Sort markers by length descending to find longest match first if overlaps occur
    List<String> sortedMarkers = markers.toList()..sort((a, b) => b.length.compareTo(a.length));

    for (String marker in sortedMarkers) {
      int index = lowerText.indexOf(marker, startIndex);
      if (index != -1) {
        if (earliestMatch == null || index < earliestMatch.index) {
          earliestMatch = _MarkerInfo(marker, index);
        }
        // Optimization: If a match is found right at the start index,
        // we prioritize it due to the descending length sort.
        // We still continue searching in case a *different* marker appears later.
      }
    }
    return earliestMatch;
  }


  ParsedCommand parseSendCommand(String text) {
    if (text.isEmpty) {
      return ParsedCommand.failure(text);
    }

    String originalText = text; // Keep original for extraction
    String lowerText = text.toLowerCase().trim();

    // --- 1. Find Action Keyword ---
    _MarkerInfo? actionInfo = _findFirstMarker(lowerText, _actionKeywords, 0);
    if (actionInfo == null) {
       print("Parser: No action keyword found.");
      return ParsedCommand.failure(originalText);
    }
    print("Parser: Found action '${actionInfo.marker}' at index ${actionInfo.index}");
    int searchStartIndex = actionInfo.index + actionInfo.marker.length;

    // --- 2. Find Key Markers After Action ---
    _MarkerInfo? recipientMarkerInfo = _findFirstMarker(lowerText, _recipientMarkers, searchStartIndex);
    _MarkerInfo? messageMarkerInfo = _findFirstMarker(lowerText, _messageMarkers, searchStartIndex);

    if (recipientMarkerInfo != null) {
        print("Parser: Found recipient marker '${recipientMarkerInfo.marker}' at index ${recipientMarkerInfo.index}");
    } else {
        print("Parser: No recipient marker ('to') found after action.");
    }
     if (messageMarkerInfo != null) {
         print("Parser: Found message marker '${messageMarkerInfo.marker}' at index ${messageMarkerInfo.index}");
     } else {
         print("Parser: No message marker found after action.");
     }

    // --- 3. Determine Entity Boundaries ---
    // Determine the end of the "entity" section (file/contact)
    // It ends where the message starts, or at the end of the string if no message marker.
    int entitySectionEndIndex = messageMarkerInfo?.index ?? originalText.length;

    // --- 4. Extract Entities Based on 'to' Marker Presence ---
    String? fileName;
    String? contactName;
    String? messageBody;

    // Extract Message Body (if marker exists)
    if (messageMarkerInfo != null) {
        int messageStartIndex = messageMarkerInfo.index + messageMarkerInfo.marker.length;
        if (originalText.length > messageStartIndex) {
            messageBody = originalText.substring(messageStartIndex).trim();
            print("Parser: Extracted potential message: '$messageBody'");
        }
    }

    // Determine start index for file/contact entities
    int entitySectionStartIndex = searchStartIndex;

    if (recipientMarkerInfo != null && recipientMarkerInfo.index < entitySectionEndIndex) {
        // CASE 1: 'to' marker is present and occurs *before* the message starts (or end of string)
        print("Parser: Using 'to' marker to separate file and contact.");

        // File is between action and 'to'
        int fileEndIndex = recipientMarkerInfo.index;
        if (fileEndIndex > entitySectionStartIndex) {
            fileName = originalText.substring(entitySectionStartIndex, fileEndIndex).trim();
            print("Parser: Extracted potential file (before 'to'): '$fileName'");
        }

        // Contact is between 'to' and the message marker (or end of entity section)
        int contactStartIndex = recipientMarkerInfo.index + recipientMarkerInfo.marker.length;
        if (entitySectionEndIndex > contactStartIndex) {
            contactName = originalText.substring(contactStartIndex, entitySectionEndIndex).trim();
            print("Parser: Extracted potential contact (after 'to'): '$contactName'");
        }

    } else {
        // CASE 2: 'to' marker is absent or occurs *after* the message marker (unlikely/ignored)
        print("Parser: No 'to' marker found before message/end. Treating section as ambiguous.");

        // The entire section between action and message marker is ambiguous
        if (entitySectionEndIndex > entitySectionStartIndex) {
             String ambiguousEntityText = originalText.substring(entitySectionStartIndex, entitySectionEndIndex).trim();
             print("Parser: Ambiguous entity text: '$ambiguousEntityText'");

             // --- Simple Heuristic Attempt ---
             // This is basic. Could be improved with keyword spotting ("file", "contact", "document", etc.)
             // Or by checking against known contact/file lists if available later.

             // Default Assumption: Assign the whole chunk as the file name for now.
             // The user can correct it using the UI edit buttons if this assumption is wrong.
             fileName = ambiguousEntityText;
             contactName = null; // Explicitly set contact to null in ambiguous case
             print("Parser: Default assumption - Treating ambiguous text as file name: '$fileName'");

        } else {
             print("Parser: No text found between action and message/end for file/contact.");
        }
    }

    // --- 5. Validation & Result ---
    bool success = fileName != null && fileName.isNotEmpty || contactName != null && contactName.isNotEmpty;
    // We need at least *something* identified as file or contact besides the action.
    // Message is optional.

    if (success) {
       print("Parser: Success - Action and at least one entity (file/contact) extracted.");
        return ParsedCommand(
            originalText: originalText,
            fileName: fileName,
            contactName: contactName,
            messageBody: messageBody,
            parseSuccess: true,
        );
    } else {
         print("Parser: Failure - Could not extract sufficient file/contact information.");
         // Return failure, including any partial data found for potential debugging/UI display
         return ParsedCommand(
             originalText: originalText,
             fileName: fileName,
             contactName: contactName,
             messageBody: messageBody,
             parseSuccess: false,
         );
    }
  }
}