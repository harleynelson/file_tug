// ./lib/services/command_parser_service.dart (Entire File - Replaced Regex Logic)

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
  // Using Sets for efficient lookup
  final Set<String> _actionKeywords = const {'send', 'email', 'text'};
  final Set<String> _recipientMarkers = const {'to'}; // Keeping simple for now
  final Set<String> _messageMarkers = const {
    'with the message', 'with message', // Order matters for finding longest match first
    'saying', 'and write', 'telling them', 'message'
    };

  // Helper to find the first occurrence of any marker from a set after a start index
  _MarkerInfo? _findFirstMarker(String lowerText, Set<String> markers, int startIndex) {
    _MarkerInfo? earliestMatch;

    // Sort markers by length descending to find longest match first if overlaps occur at same index
    // e.g., find "with the message" before "message" if both start at same point
    List<String> sortedMarkers = markers.toList()..sort((a, b) => b.length.compareTo(a.length));

    for (String marker in sortedMarkers) {
      int index = lowerText.indexOf(marker, startIndex);
      if (index != -1) {
        // If found, check if it's earlier than the current earliestMatch
        if (earliestMatch == null || index < earliestMatch.index) {
          earliestMatch = _MarkerInfo(marker, index);
        }
        // Optimization: if a match is found at the very beginning of the search range,
        // no need to check shorter markers starting at the same position.
        // However, markers could start later, so we continue the loop.
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

    // --- Find Markers ---

    // 1. Find the first action keyword
    _MarkerInfo? actionInfo = _findFirstMarker(lowerText, _actionKeywords, 0);
    if (actionInfo == null) {
       print("Parser: No action keyword found.");
      return ParsedCommand.failure(originalText); // No action found
    }
     print("Parser: Found action '${actionInfo.marker}' at index ${actionInfo.index}");

    // 2. Find the first recipient marker ('to') *after* the action keyword
    int recipientSearchStart = actionInfo.index + actionInfo.marker.length;
    _MarkerInfo? recipientInfo = _findFirstMarker(lowerText, _recipientMarkers, recipientSearchStart);
    if (recipientInfo == null) {
       print("Parser: No recipient marker ('to') found after action.");
      return ParsedCommand.failure(originalText); // Requires a recipient marker
    }
     print("Parser: Found recipient marker '${recipientInfo.marker}' at index ${recipientInfo.index}");

    // 3. Find the first message marker *after* the recipient marker
    int messageSearchStart = recipientInfo.index + recipientInfo.marker.length;
    _MarkerInfo? messageInfo = _findFirstMarker(lowerText, _messageMarkers, messageSearchStart);
     if (messageInfo != null) {
         print("Parser: Found message marker '${messageInfo.marker}' at index ${messageInfo.index}");
     } else {
         print("Parser: No message marker found after recipient marker.");
     }

    // --- Extract Entities (using indices on original text) ---

    String? fileName;
    String? contactName;
    String? messageBody;

    // Extract File: Assume it's between action and 'to' marker
    int fileStartIndex = actionInfo.index + actionInfo.marker.length;
    int fileEndIndex = recipientInfo.index;
    if (fileEndIndex > fileStartIndex) {
      fileName = originalText.substring(fileStartIndex, fileEndIndex).trim();
       print("Parser: Extracted potential file: '$fileName'");
    } else {
       print("Parser: No text found between action and recipient marker for file.");
    }

    // Extract Contact: Between 'to' marker and message marker (or end of string)
    int contactStartIndex = recipientInfo.index + recipientInfo.marker.length;
    // End contact extraction at the start of the message marker, or end of string if no message marker
    int contactEndIndex = (messageInfo != null) ? messageInfo.index : originalText.length;
    if (contactEndIndex > contactStartIndex) {
       contactName = originalText.substring(contactStartIndex, contactEndIndex).trim();
        print("Parser: Extracted potential contact: '$contactName'");
    } else {
       print("Parser: No text found between recipient marker and message marker/end for contact.");
    }

    // Extract Message: After message marker to the end of the string
    if (messageInfo != null) {
      int messageStartIndex = messageInfo.index + messageInfo.marker.length;
      if (originalText.length > messageStartIndex) {
         messageBody = originalText.substring(messageStartIndex).trim();
         print("Parser: Extracted potential message: '$messageBody'");
      } else {
         print("Parser: No text found after message marker.");
      }
    }

    // --- Validation & Result ---

    // Basic validation: require at least file and contact to be plausible
    if (fileName != null && fileName.isNotEmpty && contactName != null && contactName.isNotEmpty) {
       print("Parser: Success - File and Contact extracted.");
      return ParsedCommand(
        originalText: originalText,
        fileName: fileName,
        contactName: contactName,
        messageBody: messageBody, // Message is optional
        parseSuccess: true,
      );
    } else {
       print("Parser: Failure - Extracted file or contact is empty/null.");
       // Return failure, potentially include partially extracted info if needed for debugging
       // return ParsedCommand.failure(originalText);
       // Or return with success=false but include partials:
        return ParsedCommand(
           originalText: originalText,
           fileName: fileName,
           contactName: contactName,
           messageBody: messageBody,
           parseSuccess: false, // Indicate that essential parts might be missing
       );
    }
  }
}