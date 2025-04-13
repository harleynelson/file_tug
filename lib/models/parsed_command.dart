// ./lib/models/parsed_command.dart (New File)

// A simple data class to hold the results of parsing the voice command.
class ParsedCommand {
  final String? fileName;
  final String? contactName;
  final String? messageBody;
  final String originalText;
  final bool parseSuccess; // Flag indicating if parsing was successful

  ParsedCommand({
    required this.originalText,
    this.fileName,
    this.contactName,
    this.messageBody,
    this.parseSuccess = false, // Default to false unless all parts are found
  });

  // Convenience factory for a failed parse
  factory ParsedCommand.failure(String originalText) {
    return ParsedCommand(originalText: originalText, parseSuccess: false);
  }
}