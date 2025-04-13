// ./lib/screens/home_screen.dart (Entire File - Corrected)

import 'dart:async'; // For Future in dialogs
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/connection_service.dart'; // Needed for file picking
import '../models/parsed_command.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; // Import contacts package
import 'package:path/path.dart' as p; // For basename in file picker result
import 'connections_screen.dart'; // Keep navigation import

// Enum to track which entity type is selected for editing
enum EntityType { file, contact, message, none }

// *** FIX: Added missing HomeScreen StatefulWidget definition ***
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  // *** FIX: Corrected State type reference ***
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {

  EntityType _selectedEntityType = EntityType.none; // Track which entity is tapped
  // Controller for message editing dialog
  final TextEditingController _messageEditController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize speech service (no changes here)
    Provider.of<SpeechService>(context, listen: false).initialize();
    // Pre-request contacts permission (optional, but good UX)
    _requestContactsPermission();
  }

  @override
  void dispose() {
    _messageEditController.dispose(); // Dispose the controller
    super.dispose();
     // Note: We are not creating TapGestureRecognizers that need disposal here
     // because we are handling taps via the _buildHighlightedText logic modifying state.
  }


  Future<void> _requestContactsPermission() async {
     if (await FlutterContacts.requestPermission(readonly: true)) {
        print("Contacts permission granted.");
     } else {
        print("Contacts permission denied.");
        // Optionally show a message to the user
     }
  }

  // --- Edit Action Handlers ---

  Future<void> _editFileName(BuildContext context) async {
     // Use ConnectionService to pick a file
     final connectionService = Provider.of<ConnectionService>(context, listen: false);
     final speechService = Provider.of<SpeechService>(context, listen: false);

     await connectionService.pickLocalFiles(allowMultiple: false); // Use existing method

     if (connectionService.lastPickedFilePath != null) {
        String newFileName = p.basename(connectionService.lastPickedFilePath!);
        speechService.updateParsedFileName(newFileName);
         // If parsing originally failed, mark as successful now that user provided file
        if(speechService.parsedCommand?.parseSuccess == false) {
            speechService.setParseSuccess(true);
        }
     }
     setState(() { _selectedEntityType = EntityType.none; }); // Deselect after action
  }

  Future<void> _editContactName(BuildContext context) async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    Contact? contact;

     // Check permission before trying to pick
     if (!await FlutterContacts.requestPermission(readonly: true)) {
         if(context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                 content: Text('Contact permission is needed to select a recipient.')
             ));
         }
         setState(() { _selectedEntityType = EntityType.none; }); // Deselect
         return;
     }

    try {
       // *** This should be correct for flutter_contacts >= 1.1.0 ***
       contact = await FlutterContacts.openExternalPick();

       if (contact != null) {
         // Sometimes the picked contact might not have all details loaded.
         // Display name is usually available.
         speechService.updateParsedContactName(contact.displayName);
          // If parsing originally failed, mark as successful now that user provided contact
         if(speechService.parsedCommand?.parseSuccess == false) {
            speechService.setParseSuccess(true);
         }
       } else {
         print("Contact selection cancelled or failed.");
       }
    } catch (e) {
       print("Error picking contact: $e");
        if(context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Error selecting contact: $e')
            ));
        }
    } finally {
        setState(() { _selectedEntityType = EntityType.none; }); // Deselect after action
    }
  }

  Future<void> _editMessageBody(BuildContext context) async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    final currentMessage = speechService.parsedCommand?.messageBody ?? "";
    _messageEditController.text = currentMessage; // Pre-fill dialog field

    final newMessage = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Message"),
        content: TextField(
          controller: _messageEditController,
          autofocus: true,
          maxLines: null, // Allow multi-line input
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(hintText: "Enter message"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context), // Return null
          ),
          TextButton(
            child: const Text("Save"),
            onPressed: () => Navigator.pop(context, _messageEditController.text), // Return new text
          ),
        ],
      ),
    );

    // Check if newMessage is not null before comparing or updating
    if (newMessage != null && newMessage != currentMessage) { // Check if changed
      speechService.updateParsedMessageBody(newMessage);
       // If parsing originally failed, mark as successful now that user provided message
       if(speechService.parsedCommand?.parseSuccess == false) {
            speechService.setParseSuccess(true);
        }
    }
    setState(() { _selectedEntityType = EntityType.none; }); // Deselect after action
  }


  // --- Build Highlighted Text with Interaction ---
  InlineSpan _buildHighlightedText(ParsedCommand? command, String originalText, BuildContext context) {
    // Styles (consider moving these outside build method if static)
    final defaultStyle = TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.black87);
    final highlightStyle = defaultStyle.copyWith(fontWeight: FontWeight.bold);
    final annotationStyle = TextStyle(fontSize: 12.0, color: Colors.black54, fontStyle: FontStyle.italic);

    // Base span if no command or parsing failed but user hasn't tapped anything
     if (command == null || !command.parseSuccess && _selectedEntityType == EntityType.none) {
        return TextSpan(
            text: originalText.isEmpty ? 'Awaiting command...' : (command?.originalText ?? originalText),
            style: defaultStyle);
     }
    // If parsing failed, but user tapped something, show the original with prompt? Or just the plain text?
    // Let's show the original text plainly if parsing failed, the edit buttons will guide correction.
    if (command != null && !command.parseSuccess) {
        return TextSpan(text: command.originalText, style: defaultStyle);
    }

    // Helper to create a tappable, highlighted span
    InlineSpan createHighlightSpan(
        String? text,
        String annotation,
        Color bgColor,
        EntityType entityType, // Pass entity type
        ) {
      if (text == null || text.isEmpty) return const TextSpan();

      return TextSpan(
        children: [
          TextSpan(
            text: text,
            style: highlightStyle.copyWith(
              backgroundColor: bgColor,
              decoration: _selectedEntityType == entityType // Add underline if selected
                  ? TextDecoration.underline
                  : TextDecoration.none,
               decorationColor: Colors.red,
               decorationThickness: 2,
            ),
             // *** ADD GESTURE RECOGNIZER ***
             recognizer: TapGestureRecognizer()
                ..onTap = () {
                  print("Tapped on $entityType");
                  // Set state to indicate which entity type was tapped
                  setState(() {
                     // Toggle selection: if tapped again, deselect; otherwise, select.
                     _selectedEntityType = (_selectedEntityType == entityType) ? EntityType.none : entityType;
                  });
                },
          ),
          const TextSpan(text: ' '), // Space before annotation
          TextSpan(text: '[$annotation]', style: annotationStyle),
        ],
      );
    }

    // Find indices (same logic as before, might need refinement)
     int fileIndex = command!.fileName != null ? command.originalText.toLowerCase().indexOf(command.fileName!.toLowerCase()) : -1;
     int contactIndex = command.contactName != null ? command.originalText.toLowerCase().indexOf(command.contactName!.toLowerCase(), fileIndex != -1 ? fileIndex + command.fileName!.length : 0) : -1;
     // Adjust message index search start based on contact or file if contact missing
     int messageSearchStartIndex = contactIndex != -1 ? contactIndex + command.contactName!.length : (fileIndex != -1 ? fileIndex + command.fileName!.length : 0);
     int messageIndex = command.messageBody != null && command.messageBody!.isNotEmpty
         ? command.originalText.toLowerCase().indexOf(command.messageBody!.toLowerCase(), messageSearchStartIndex)
         : -1;


    List<InlineSpan> spans = [];
    int currentIndex = 0;

    // Function to add text segment (unchanged)
     void addPrecedingText(int entityIndex) {
      if (entityIndex > currentIndex) {
        spans.add(TextSpan(text: command!.originalText.substring(currentIndex, entityIndex)));
      }
    }

    // Build spans using createHighlightSpan with EntityType (ensure correct order)
     // Sort entities by their start index to handle potential ordering variations
    List<Map<String, dynamic>> entities = [];
    if(fileIndex != -1 && command.fileName != null) entities.add({'index': fileIndex, 'type': EntityType.file, 'text': command.fileName, 'annotation': 'File', 'color': Colors.yellow.shade200, 'length': command.fileName!.length});
    if(contactIndex != -1 && command.contactName != null) entities.add({'index': contactIndex, 'type': EntityType.contact, 'text': command.contactName, 'annotation': 'Contact', 'color': Colors.lightBlue.shade100, 'length': command.contactName!.length});
    if(messageIndex != -1 && command.messageBody != null) entities.add({'index': messageIndex, 'type': EntityType.message, 'text': command.messageBody, 'annotation': 'Message', 'color': Colors.lightGreen.shade100, 'length': command.messageBody!.length});

    entities.sort((a, b) => a['index'].compareTo(b['index'])); // Sort by start index

     for (var entity in entities) {
       // Double check index before adding preceding text
        if (entity['index'] >= 0) {
           addPrecedingText(entity['index']);
           spans.add(createHighlightSpan(
              entity['text'],
              entity['annotation'],
              entity['color'],
              entity['type'],
           ));
           currentIndex = entity['index'] + entity['length'];
        }
     }

    // Add any remaining text (unchanged)
    if (currentIndex < command.originalText.length) {
      spans.add(TextSpan(text: command.originalText.substring(currentIndex)));
    }

    // Fallback (unchanged)
    if (spans.isEmpty && command.originalText.isNotEmpty) {
       print("Warning: Could not reliably find indices for highlighting. Falling back.");
       return TextSpan(
         text: "File: ${command.fileName ?? 'N/A'}\n"
               "Contact: ${command.contactName ?? 'N/A'}\n"
               "Message: ${command.messageBody ?? 'N/A'}",
         style: defaultStyle.copyWith(color: Colors.orange[800]) // Indicate fallback
       );
    }

    return TextSpan(style: defaultStyle, children: spans);
  }


  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // Access services using Provider.of or Consumer
    final speechService = Provider.of<SpeechService>(context);
    // final connectionService = Provider.of<ConnectionService>(context); // If needed directly

    // *** FIX: Initialize textSpanToShow ***
    InlineSpan textSpanToShow = const TextSpan(text: ''); // Default empty span
    String statusText = ""; // For simple status messages

    if (speechService.isListening) {
       // Don't set status text here if listening, show recognized words instead
       // statusText = 'Listening...'; // Remove this or comment out
       textSpanToShow = _buildHighlightedText(
           speechService.parsedCommand, speechService.recognizedWords, context);
       // Handle empty recognized words while listening
       if (speechService.recognizedWords.isEmpty) {
          textSpanToShow = const TextSpan(
             text: 'Listening...',
             style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.black54)
           );
       }

    } else if (speechService.lastError.isNotEmpty) {
       statusText = 'Error: ${speechService.lastError}';
    } else if (speechService.parsedCommand != null || speechService.recognizedWords.isNotEmpty) {
       // If we have parsed command or recognized words, use the highlighting builder
       textSpanToShow = _buildHighlightedText(
           speechService.parsedCommand, speechService.recognizedWords, context);
    } else {
       statusText = 'Awaiting command...';
    }

     // If statusText is set, overwrite textSpanToShow with a simple TextSpan
     if (statusText.isNotEmpty) {
       textSpanToShow = TextSpan(
         text: statusText,
         style: TextStyle(
           fontSize: 18.0,
           fontWeight: FontWeight.w500,
           color: speechService.lastError.isNotEmpty ? Colors.red : Colors.black54,
         ),
       );
     }


    // Build Edit Action Buttons conditionally
    Widget? editActions;
    switch (_selectedEntityType) {
       case EntityType.file:
         editActions = ElevatedButton.icon(
             icon: const Icon(Icons.file_open_outlined, size: 16),
             label: const Text("Change File"),
             onPressed: () => _editFileName(context),
             style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact)
             );
         break;
       case EntityType.contact:
         editActions = ElevatedButton.icon(
             icon: const Icon(Icons.contact_page_outlined, size: 16),
             label: const Text("Change Contact"),
             onPressed: () => _editContactName(context),
              style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact)
             );
         break;
       case EntityType.message:
         editActions = ElevatedButton.icon(
             icon: const Icon(Icons.edit_outlined, size: 16),
             label: const Text("Edit Message"),
             onPressed: () => _editMessageBody(context),
              style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact)
             );
         break;
       case EntityType.none:
         editActions = null;
         break;
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtor Assistant'),
        actions: [
          IconButton( // Keep navigation
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Manage Connections',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConnectionsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center( // Keep overall structure
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Tap the microphone and speak your command:',
                style: TextStyle(fontSize: 16.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Display Area (RichText)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8.0),
                  border: _selectedEntityType != EntityType.none // Highlight border if something is selected
                     ? Border.all(color: Colors.red, width: 1.5)
                     : null,
                ),
                constraints: const BoxConstraints(minHeight: 100.0),
                alignment: Alignment.centerLeft,
                 // Use a builder to only build RichText when needed
                 child: Builder(builder: (context) {
                    // Ensure we have a valid span, even if empty, for RichText
                    final effectiveSpan = (textSpanToShow.toPlainText().isNotEmpty || speechService.isListening)
                                          ? textSpanToShow
                                          : const TextSpan(text: ' ', style: TextStyle(fontSize: 18.0)); // Use space to maintain height
                    return RichText(
                       textAlign: TextAlign.left,
                       text: effectiveSpan,
                    );
                 }),
              ),
              const SizedBox(height: 10), // Space for edit buttons

              // Conditionally display Edit Buttons
              AnimatedSize( // Add animation for smoother appearance/disappearance
                 duration: const Duration(milliseconds: 200),
                 child: editActions ?? const SizedBox.shrink(), // Use SizedBox.shrink() if null
              ),

              // Initialization Status Error (keep existing logic)
              if (!speechService.isSpeechEnabled &&
                  speechService.lastError.isNotEmpty &&
                  !speechService.isListening)
                Padding(
                  // Add the required padding argument
                  padding: const EdgeInsets.only(top: 15.0, bottom: 10.0), // Added top padding too
                  child: Text(
                    'Initialization Failed: ${speechService.lastError}',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (editActions == null) // Only add SizedBox if edit actions aren't showing
                 const SizedBox(height: 25.0), // Maintain space


              // Microphone Button
               ElevatedButton.icon(
                    icon: Icon(
                       // Icon remains stop/mic based on listening state
                      speechService.isListening ? Icons.stop : Icons.mic,
                      size: 30,
                    ),
                    // *** UPDATE BUTTON LABEL TEXT ***
                    label: Text(speechService.isListening ? "I'm Done" : 'Listen'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: speechService.isListening
                          ? Colors.orange.shade800 // Changed color for "I'm Done" state
                          : Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    // onPressed logic remains the same toggle
                    onPressed: !speechService.isSpeechEnabled
                        ? null
                        : speechService.isListening
                            ? speechService.stopListening // Tapping "I'm Done" calls stop
                            : () { // Tapping "Listen" calls start
                                setState(() { _selectedEntityType = EntityType.none; }); // Also reset selection
                                speechService.startListening();
                              },
                  ),
            ],
          ),
        ),
      ),
    );
  }
} // End of _HomeScreenState