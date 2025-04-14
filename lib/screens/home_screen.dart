// ./lib/screens/home_screen.dart (Entire File - Updated with Text Input)

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/connection_service.dart';
import '../models/parsed_command.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path/path.dart' as p;
import 'connections_screen.dart';
import '../testing/phrases.dart';

enum EntityType { file, contact, message, none }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {

  EntityType _selectedEntityType = EntityType.none;
  // Controller for message editing dialog
  final TextEditingController _messageEditController = TextEditingController();
  // Controller for the new text command input field
  final TextEditingController _textCommandController = TextEditingController(); // ** NEW **
  String? _selectedTestPhrase;

  @override
  void initState() {
    super.initState();
    Provider.of<SpeechService>(context, listen: false).initialize();
    _requestContactsPermission();
    // Optional: Initialize dropdown selection if desired
    // _selectedTestPhrase = testCommandPhrases.first;
  }

  @override
  void dispose() {
    _messageEditController.dispose();
    _textCommandController.dispose(); // ** NEW: Dispose new controller **
    super.dispose();
  }

  // --- Permission Request (No change) ---
  Future<void> _requestContactsPermission() async {
     // ... (existing code) ...
     if (await FlutterContacts.requestPermission(readonly: true)) {
        print("Contacts permission granted.");
     } else {
        print("Contacts permission denied.");
     }
  }

  // --- Edit Action Handlers (No change) ---
  Future<void> _editFileName(BuildContext context) async {
     // ... (existing code) ...
     final connectionService = Provider.of<ConnectionService>(context, listen: false);
     final speechService = Provider.of<SpeechService>(context, listen: false);
     await connectionService.pickLocalFiles(allowMultiple: false);
     if (connectionService.lastPickedFilePath != null) {
        String newFileName = p.basename(connectionService.lastPickedFilePath!);
        speechService.updateParsedFileName(newFileName);
        if(speechService.parsedCommand?.parseSuccess == false) {
            speechService.setParseSuccess(true);
        }
     }
     setState(() { _selectedEntityType = EntityType.none; });
  }

  Future<void> _editContactName(BuildContext context) async {
    // ... (existing code) ...
    final speechService = Provider.of<SpeechService>(context, listen: false);
    Contact? contact;
     if (!await FlutterContacts.requestPermission(readonly: true)) {
         if(context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                 content: Text('Contact permission is needed to select a recipient.')
             ));
         }
         setState(() { _selectedEntityType = EntityType.none; });
         return;
     }
    try {
       contact = await FlutterContacts.openExternalPick();
       if (contact != null) {
         speechService.updateParsedContactName(contact.displayName);
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
        setState(() { _selectedEntityType = EntityType.none; });
    }
  }

  Future<void> _editMessageBody(BuildContext context) async {
    // ... (existing code) ...
     final speechService = Provider.of<SpeechService>(context, listen: false);
    final currentMessage = speechService.parsedCommand?.messageBody ?? "";
    _messageEditController.text = currentMessage;
    final newMessage = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog( /* ... dialog definition ... */ ),
    );
    if (newMessage != null && newMessage != currentMessage) {
      speechService.updateParsedMessageBody(newMessage);
       if(speechService.parsedCommand?.parseSuccess == false) {
            speechService.setParseSuccess(true);
        }
    }
    setState(() { _selectedEntityType = EntityType.none; });
  }


  // --- Build Highlighted Text with Interaction (No change needed in logic) ---
  InlineSpan _buildHighlightedText(ParsedCommand? command, String originalText, BuildContext context) {
    // Styles
    final defaultStyle = TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.black87);
    final highlightStyle = defaultStyle.copyWith(fontWeight: FontWeight.bold);
    final annotationStyle = TextStyle(fontSize: 12.0, color: Colors.black54, fontStyle: FontStyle.italic);

    // Base cases
     if (command == null || (!command.parseSuccess && _selectedEntityType == EntityType.none)) {
        return TextSpan(
            text: originalText.isEmpty ? 'Awaiting command...' : (command?.originalText ?? originalText),
            style: defaultStyle);
     }
     if (command != null && !command.parseSuccess) {
        return TextSpan(text: command.originalText, style: defaultStyle);
     }

    // *** CORRECTED Helper to create tappable span ***
    // Ensure parameter names match usage below and types are correct
    InlineSpan createHighlightSpan(
        String? entityText, // Use entityText consistently
        String annotation,  // Parameter for annotation text
        Color bgColor,       // Parameter for background color
        EntityType entityType, // Parameter for entity type enum
        ) {
      // Check if the text to highlight is valid
      if (entityText == null || entityText.isEmpty) return const TextSpan();

      // Build the tappable span with background, underline (if selected), and annotation
      return TextSpan(
        children: [
          TextSpan(
            text: entityText, // Use the entityText parameter
            style: highlightStyle.copyWith(
              backgroundColor: bgColor, // Use bgColor parameter
              decoration: _selectedEntityType == entityType // Use entityType parameter
                  ? TextDecoration.underline
                  : TextDecoration.none,
               decorationColor: Colors.red,
               decorationThickness: 2,
            ),
             recognizer: TapGestureRecognizer()
                ..onTap = () {
                  print("Tapped on $entityType"); // Use entityType parameter
                  // Update state when tapped
                  setState(() {
                     _selectedEntityType = (_selectedEntityType == entityType) ? EntityType.none : entityType; // Use entityType parameter
                  });
                },
          ),
          const TextSpan(text: ' '), // Spacer
          // Display the annotation text using the annotation parameter
          TextSpan(text: '[$annotation]', style: annotationStyle),
        ],
      );
    } // *** End CORRECTED Helper ***

    // --- Refined Index Finding (from previous step, likely okay) ---
    String lowerOriginalText = command.originalText.toLowerCase();
    int fileIndex = -1;
    int contactIndex = -1;
    int messageIndex = -1;
    int searchStartIndex = 0;

    if (command.fileName != null && command.fileName!.isNotEmpty) {
      fileIndex = lowerOriginalText.indexOf(command.fileName!.toLowerCase(), searchStartIndex);
      if (fileIndex != -1) {
        searchStartIndex = fileIndex + command.fileName!.length;
      }
    }
    if (command.contactName != null && command.contactName!.isNotEmpty) {
      contactIndex = lowerOriginalText.indexOf(command.contactName!.toLowerCase(), searchStartIndex);
       if (contactIndex == -1 && fileIndex != -1) {
          contactIndex = lowerOriginalText.indexOf(command.contactName!.toLowerCase(), 0);
       }
       if (contactIndex != -1) {
           searchStartIndex = (fileIndex != -1 && fileIndex > contactIndex)
                             ? fileIndex + command.fileName!.length
                             : contactIndex + command.contactName!.length;
       }
    }
    if (command.messageBody != null && command.messageBody!.isNotEmpty) {
        messageIndex = lowerOriginalText.indexOf(command.messageBody!.toLowerCase(), searchStartIndex);
         if (messageIndex == -1) {
            messageIndex = lowerOriginalText.indexOf(command.messageBody!.toLowerCase(), 0);
         }
    }
    // --- End Refined Index Finding ---

    // Build entities map (references keys 'text', 'annotation', 'color', 'type')
    List<Map<String, dynamic>> entities = [];
     if(fileIndex != -1 && command.fileName != null) entities.add({'index': fileIndex, 'type': EntityType.file, 'text': command.fileName, 'annotation': 'File', 'color': Colors.yellow.shade200, 'length': command.fileName!.length});
     if(contactIndex != -1 && command.contactName != null) entities.add({'index': contactIndex, 'type': EntityType.contact, 'text': command.contactName, 'annotation': 'Contact', 'color': Colors.lightBlue.shade100, 'length': command.contactName!.length});
     if(messageIndex != -1 && command.messageBody != null) entities.add({'index': messageIndex, 'type': EntityType.message, 'text': command.messageBody, 'annotation': 'Message', 'color': Colors.lightGreen.shade100, 'length': command.messageBody!.length});

    // --- Span building logic (Uses the helper function correctly) ---
    entities.sort((a, b) => a['index'].compareTo(b['index']));
    List<InlineSpan> spans = [];
    int currentIndex = 0;

    void addPrecedingText(int entityIndex) {
      if (entityIndex > currentIndex) {
        spans.add(TextSpan(text: command!.originalText.substring(currentIndex, entityIndex)));
      }
    }

    for (var entity in entities) {
      if (entity['index'] >= 0) {
         addPrecedingText(entity['index']);
         // Call helper using the map keys, matching the corrected helper parameters
         spans.add(createHighlightSpan(
            entity['text'],       // Corresponds to entityText parameter
            entity['annotation'], // Corresponds to annotation parameter
            entity['color'],      // Corresponds to bgColor parameter
            entity['type'],       // Corresponds to entityType parameter
         ));
         currentIndex = entity['index'] + entity['length'];
      }
    }

    if (currentIndex < command.originalText.length) {
      spans.add(TextSpan(text: command.originalText.substring(currentIndex)));
    }

    // Fallback
    if (spans.isEmpty && command.originalText.isNotEmpty) {
       print("Warning: Could not reliably find indices for highlighting. Falling back.");
       return TextSpan(
         text: "File: ${command.fileName ?? 'N/A'}\n"
               "Contact: ${command.contactName ?? 'N/A'}\n"
               "Message: ${command.messageBody ?? 'N/A'}",
         style: defaultStyle.copyWith(color: Colors.orange[800])
       );
    }

    return TextSpan(style: defaultStyle, children: spans);
  }

  void _sendTextCommand() {
    final text = _textCommandController.text.trim();
    if (text.isNotEmpty) {
      print("Sending text command: $text");
      Provider.of<SpeechService>(context, listen: false).processTextCommand(text);
      _textCommandController.clear();
      FocusScope.of(context).unfocus();
       setState(() {
          _selectedEntityType = EntityType.none;
          // ** NEW: Reset dropdown after sending **
          _selectedTestPhrase = null;
       });
    }
  }


  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final speechService = Provider.of<SpeechService>(context);

    InlineSpan textSpanToShow = const TextSpan(text: '');
    String statusText = "";

    // Determine what to show in the display area (based on voice state mostly)
    if (speechService.isListening) {
       textSpanToShow = _buildHighlightedText(
           speechService.parsedCommand, speechService.recognizedWords, context);
       if (speechService.recognizedWords.isEmpty) {
          textSpanToShow = const TextSpan(
             text: 'Listening...',
             style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.black54)
           );
       }
    } else if (speechService.lastError.isNotEmpty) {
       // If there's an error, display it prominently
       statusText = 'Error: ${speechService.lastError}';
    } else if (speechService.parsedCommand != null) {
       // If not listening and no error, show the parsed command (or fallback highlighting)
       // Use parsedCommand.originalText which is set by both voice and text input paths
       textSpanToShow = _buildHighlightedText(
           speechService.parsedCommand, speechService.parsedCommand!.originalText, context);
    }
    // Fallback if not listening, no error, no command yet
    else if (speechService.recognizedWords.isEmpty) {
         statusText = 'Awaiting command...';
    }
    // If statusText is set, use a simple TextSpan
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

    // Build Edit Action Buttons
    Widget? editActions;
    switch (_selectedEntityType) {
       case EntityType.file:
         editActions = ElevatedButton.icon(
             // Fill in details for File button
             icon: const Icon(Icons.file_open_outlined, size: 16),
             label: const Text("Change File"),
             onPressed: () => _editFileName(context),
             style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact) // Style for compactness
             );
         break;
       case EntityType.contact:
         editActions = ElevatedButton.icon(
             // Fill in details for Contact button
             icon: const Icon(Icons.contact_page_outlined, size: 16),
             label: const Text("Change Contact"),
             onPressed: () => _editContactName(context),
             style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact) // Style for compactness
             );
         break;
       case EntityType.message:
         editActions = ElevatedButton.icon(
            // Fill in details for Message button
             icon: const Icon(Icons.edit_outlined, size: 16),
             label: const Text("Edit Message"),
             onPressed: () => _editMessageBody(context),
             style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact) // Style for compactness
             );
         break;
       case EntityType.none:
         editActions = null; // No button when nothing is selected
         break;
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtor Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Manage Connections',
            onPressed: () { /* ... navigation ... */ },
          ),
        ],
      ),
      body: SingleChildScrollView( // ** NEW: Added SingleChildScrollView **
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Display Area (RichText) - No change in logic
              Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(12.0),
                 decoration: BoxDecoration(
                   color: Colors.grey[200],
                   borderRadius: BorderRadius.circular(8.0),
                   border: _selectedEntityType != EntityType.none
                      ? Border.all(color: Colors.red, width: 1.5)
                      : null,
                 ),
                 constraints: const BoxConstraints(minHeight: 100.0),
                 alignment: Alignment.centerLeft,
                  child: Builder(builder: (context) {
                     final effectiveSpan = (textSpanToShow.toPlainText().isNotEmpty || speechService.isListening)
                                           ? textSpanToShow
                                           : const TextSpan(text: ' ', style: TextStyle(fontSize: 18.0));
                     return RichText(
                        textAlign: TextAlign.left,
                        text: effectiveSpan,
                     );
                  }),
              ),
              const SizedBox(height: 10),

              // Edit Buttons Area (No change)
              AnimatedSize(
                 duration: const Duration(milliseconds: 200),
                 child: editActions ?? const SizedBox.shrink(),
              ),
              // Add spacing below edit buttons or display area
              const SizedBox(height: 20),

              // ** Test Phrase Dropdown **
              DropdownButtonFormField<String>(
                value: _selectedTestPhrase,
                hint: const Text('Select a test phrase...'),
                isExpanded: true, // Allow dropdown to expand
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  border: OutlineInputBorder(),
                ),
                items: testCommandPhrases.map((String phrase) {
                  return DropdownMenuItem<String>(
                    value: phrase,
                    child: Text(
                      phrase,
                      overflow: TextOverflow.ellipsis, // Prevent long text overflow
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedTestPhrase = newValue;
                    // Update the text field when a phrase is selected
                    _textCommandController.text = newValue ?? '';
                    _selectedEntityType = EntityType.none; // Reset entity selection
                  });
                },
              ),
              const SizedBox(height: 15), // Spacing after dropdown

              // ** NEW: Text Input Row **
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCommandController,
                      decoration: const InputDecoration(
                        hintText: 'Or type command here...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _sendTextCommand(), // Allow sending via keyboard action
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendTextCommand,
                    tooltip: 'Send Text Command',
                  ),
                ],
              ),
              // ** End NEW Text Input Row **

              const SizedBox(height: 20), // Spacing before Mic button

              // Microphone Button Area (No change in logic)
              const Text(
                'Tap the microphone and speak your command:',
                style: TextStyle(fontSize: 16.0),
                textAlign: TextAlign.center,
              ),
               const SizedBox(height: 10),
               ElevatedButton.icon(
                    icon: Icon(speechService.isListening ? Icons.stop : Icons.mic, size: 30),
                    label: Text(speechService.isListening ? "I'm Done" : 'Listen'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: speechService.isListening
                          ? Colors.orange.shade800
                          : Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: !speechService.isSpeechEnabled
                        ? null
                        : speechService.isListening
                            ? speechService.stopListening
                            : () {
                                setState(() { _selectedEntityType = EntityType.none; });
                                // Clear text field when starting voice
                                _textCommandController.clear();
                                speechService.startListening();
                              },
                  ),

                 // Initialization Status Error (keep existing logic)
                 if (!speechService.isSpeechEnabled &&
                     speechService.lastError.isNotEmpty &&
                     !speechService.isListening)
                   Padding(
                     padding: const EdgeInsets.only(top: 15.0, bottom: 10.0),
                     child: Text(
                       'Initialization Failed: ${speechService.lastError}',
                       style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                       textAlign: TextAlign.center,
                     ),
                   ),

            ],
          ),
        ),
      ),
    );
  }
}