// ./lib/screens/home_screen.dart (Entire File - Updated Text Construction)

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/connection_service.dart';
// Import model for AssociationStatus and ParsedCommand structure
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
  final TextEditingController _messageEditController = TextEditingController();
  final TextEditingController _textCommandController = TextEditingController();
  String? _selectedTestPhrase;

  @override
  void initState() {
    super.initState();
    Provider.of<SpeechService>(context, listen: false).initialize();
    _requestContactsPermission();
  }

  @override
  void dispose() {
    _messageEditController.dispose();
    _textCommandController.dispose();
    super.dispose();
  }

  Future<void> _requestContactsPermission() async {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        print("Contacts permission granted.");
      } else {
        print("Contacts permission denied.");
      }
  }

  // --- Edit Action Handlers (Unchanged - they call correct Service methods now) ---
  Future<void> _handleFileAction(BuildContext context) async {
     final speechService = Provider.of<SpeechService>(context, listen: false);
    final connectionService = Provider.of<ConnectionService>(context, listen: false);
    final currentStatus = speechService.parsedCommand?.fileStatus;

    print("Handling file action. Current status: $currentStatus");

    // TODO: Implement logic for AssociationStatus.foundMultiple (e.g., show dialog)
    // if (currentStatus == AssociationStatus.foundMultiple) { ... }

    // For pending, notFound, or other states, trigger the file picker
    try {
        await connectionService.pickLocalFiles(allowMultiple: false);
        if (connectionService.lastPickedFilePath != null) {
          String filePath = connectionService.lastPickedFilePath!;
          String displayFileName = p.basename(filePath);
          // Use the new method in SpeechService
          speechService.userSelectedFile(filePath, displayFileName);
        } else {
           print("File picking cancelled.");
        }
    } catch(e) {
       print("Error picking file: $e");
        if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error picking file: $e')),
            );
        }
    } finally {
        // Deselect after action complete or cancelled
        if(mounted) {
           setState(() { _selectedEntityType = EntityType.none; });
        }
    }
   }
  Future<void> _handleContactAction(BuildContext context) async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    final currentStatus = speechService.parsedCommand?.contactStatus;

    print("Handling contact action. Current status: $currentStatus");

    // Check for permission first
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Contact permission is needed to select a recipient.')
        ));
      }
      setState(() { _selectedEntityType = EntityType.none; });
      return;
    }

    // TODO: Implement logic for AssociationStatus.foundMultiple (e.g., show dialog)
    // if (currentStatus == AssociationStatus.foundMultiple) { ... }

    // For pending, notFound, or other states, trigger the contact picker
    Contact? contact;
    try {
      contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        // Use the new method in SpeechService
        speechService.userSelectedContact(contact.id, contact.displayName);
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
        // Deselect after action complete or cancelled
         if(mounted) {
           setState(() { _selectedEntityType = EntityType.none; });
         }
    }
   }
  Future<void> _handleMessageAction(BuildContext context) async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    final currentMessage = speechService.parsedCommand?.messageBody ?? "";
    _messageEditController.text = currentMessage;

    final newMessage = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: _messageEditController,
          autofocus: true,
          maxLines: null, // Allow multi-line input
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(hintText: 'Enter message content'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () => Navigator.of(context).pop(_messageEditController.text),
          ),
        ],
      ),
    );

    // Only update if the message actually changed
    if (newMessage != null && newMessage != currentMessage) {
       // Use the new method in SpeechService
       speechService.userEditedMessageBody(newMessage);
    }
     // Deselect after action complete or cancelled
    if(mounted) {
      setState(() { _selectedEntityType = EntityType.none; });
    }
  }


  // --- Build Highlighted Text - *** REFACTORED *** ---
  InlineSpan _buildHighlightedText(ParsedCommand? command, BuildContext context) {
    // Default styles
    final defaultStyle = TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.black87);
    final highlightStyleBase = defaultStyle.copyWith(fontWeight: FontWeight.bold);
    final annotationStyle = TextStyle(fontSize: 12.0, color: Colors.black54, fontStyle: FontStyle.italic);
    final resolvedStyle = annotationStyle.copyWith(color: Colors.green.shade800, fontWeight: FontWeight.bold);
    final errorStyle = annotationStyle.copyWith(color: Colors.red.shade800, fontWeight: FontWeight.bold);

    // Handle null command case
    if (command == null) {
      return TextSpan(text: 'Awaiting command...', style: defaultStyle.copyWith(color: Colors.black54));
    }
    // Handle initial parse failure (show original text simply)
    if (!command.parseSuccess && _selectedEntityType == EntityType.none) {
        // Try showing original text if available, otherwise fallback
        return TextSpan(text: command.originalText.isNotEmpty ? command.originalText : 'Command processing failed.', style: defaultStyle.copyWith(color: Colors.black54));
    }
    // If parse failed but user selected something, show original (allows clicking to edit)
    if (!command.parseSuccess && _selectedEntityType != EntityType.none) {
        return TextSpan(text: command.originalText, style: defaultStyle);
    }


    // Helper to determine background color and annotation based on status
    // (Same helper function as before)
    Map<String, dynamic> getEntityStyle(EntityType type, AssociationStatus status, String? resolvedValue) {
       String annotationText; Color bgColor; InlineSpan? statusIndicator;
       switch (status) {
         case AssociationStatus.pending:
           bgColor = Colors.orange.shade100; annotationText = type == EntityType.file ? 'File' : 'Contact';
           statusIndicator = TextSpan(text: ' [Searching...]', style: annotationStyle.copyWith(color: Colors.orange.shade900)); break;
         case AssociationStatus.notFound: case AssociationStatus.lookupFailed:
           bgColor = Colors.red.shade100; annotationText = type == EntityType.file ? 'File' : 'Contact';
           statusIndicator = TextSpan(text: ' [Not Found]', style: errorStyle); break;
         case AssociationStatus.foundSingle: case AssociationStatus.userSelected:
           bgColor = Colors.green.shade100; annotationText = type == EntityType.file ? 'File' : 'Contact';
           String displayValue = resolvedValue ?? 'Selected';
           if (type == EntityType.file && resolvedValue != null) displayValue = p.basename(resolvedValue);
           // For contacts, maybe fetch display name using ID if needed later
           statusIndicator = TextSpan(text: ' [$displayValue]', style: resolvedStyle); break;
         case AssociationStatus.foundMultiple:
           bgColor = Colors.yellow.shade300; annotationText = type == EntityType.file ? 'File' : 'Contact';
           statusIndicator = TextSpan(text: ' [Multiple Found]', style: annotationStyle.copyWith(color: Colors.deepOrange.shade800, fontWeight: FontWeight.bold)); break;
       }
       // Add special case for message type which doesn't use association
       if (type == EntityType.message) {
          bgColor = Colors.lightGreen.shade100;
          annotationText = 'Message';
          statusIndicator = null; // No status indicator for messages
       }
       return {'annotation': annotationText, 'color': bgColor, 'statusIndicator': statusIndicator};
    }

    // Helper to create the actual tappable InlineSpan
    // (Updated slightly to handle message type styling)
    InlineSpan createHighlightSpan({ required String? entityText, required EntityType entityType, required AssociationStatus status, required String? resolvedValue, required Function() onTapAction, }) {
      if (entityText == null || entityText.isEmpty) return const TextSpan(); // Return empty span if no text

      final styleInfo = getEntityStyle(entityType, status, resolvedValue);
      final String annotation = styleInfo['annotation']; final Color bgColor = styleInfo['color']; final InlineSpan? statusIndicator = styleInfo['statusIndicator'];
      bool showErrorIndicator = status == AssociationStatus.notFound || status == AssociationStatus.lookupFailed || status == AssociationStatus.foundMultiple;
      TextDecoration? decoration; Color? decorationColor; double? decorationThickness;

      // Apply selection highlight or error highlight
      if (_selectedEntityType == entityType) { decoration = TextDecoration.underline; decorationColor = Colors.blue.shade700; decorationThickness = 2; }
      else if (showErrorIndicator && entityType != EntityType.message) { decoration = TextDecoration.underline; decorationColor = Colors.red.shade700; decorationThickness = 1.5; }

      // Build the span
      return TextSpan( children: [
          TextSpan( text: entityText, style: highlightStyleBase.copyWith( backgroundColor: bgColor, decoration: decoration, decorationColor: decorationColor, decorationThickness: decorationThickness, ),
            recognizer: TapGestureRecognizer()..onTap = () { print("Tapped on $entityType (Status: $status)"); setState(() { _selectedEntityType = (_selectedEntityType == entityType) ? EntityType.none : entityType; }); }, ),
          const TextSpan(text: ' '), TextSpan(text: '[$annotation]', style: annotationStyle), if (statusIndicator != null) statusIndicator, ], );
    } // End createHighlightSpan


    // --- *** Text Reconstruction Logic *** ---
    List<InlineSpan> spans = [];

    // Determine the verb/action phrase (could be more dynamic later)
    spans.add(const TextSpan(text: "Send "));

    // Add File Span (using current command.fileName)
    spans.add(createHighlightSpan(
        entityText: command.fileName ?? command.originalFileName ?? "[File]", // Show current, fallback to original, then placeholder
        entityType: EntityType.file,
        status: command.fileStatus,
        resolvedValue: command.resolvedFilePath,
        onTapAction: () => _handleFileAction(context),
    ));

    // Add intermediate text (" to ")
    spans.add(const TextSpan(text: " to "));

    // Add Contact Span (using current command.contactName)
    spans.add(createHighlightSpan(
        entityText: command.contactName ?? command.originalContactName ?? "[Contact]", // Show current, fallback to original, then placeholder
        entityType: EntityType.contact,
        status: command.contactStatus,
        resolvedValue: command.resolvedContactId, // Pass ID for potential display logic
        onTapAction: () => _handleContactAction(context),
    ));

    // Add Message Span (if message exists, using current command.messageBody)
    final currentMessage = command.messageBody; // Use current message
    if (currentMessage != null && currentMessage.isNotEmpty) {
        spans.add(const TextSpan(text: " with message "));
        // Message doesn't have association status, treat as found/userSelected
        spans.add(createHighlightSpan(
           entityText: currentMessage,
           entityType: EntityType.message,
           // Pass a status that gives the desired message styling (e.g., userSelected gives green)
           status: AssociationStatus.userSelected,
           resolvedValue: null,
           onTapAction: () => _handleMessageAction(context),
        ));
    }

    // Add a period at the end?
    spans.add(const TextSpan(text: "."));

    // --- *** End Text Reconstruction Logic *** ---


    // Fallback if spans are empty (shouldn't happen with reconstruction)
    if (spans.isEmpty) {
       print("Warning: Text reconstruction resulted in empty spans.");
       return TextSpan(text: command.originalText, style: defaultStyle.copyWith(color: Colors.orange[800]));
    }

    return TextSpan(style: defaultStyle, children: spans);
  } // End _buildHighlightedText


  // --- Text Command Input Handling (No change) ---
  void _sendTextCommand() {
     final text = _textCommandController.text.trim();
    if (text.isNotEmpty) {
      print("Sending text command: $text");
      // Use the service method that handles parsing AND association
      Provider.of<SpeechService>(context, listen: false).processTextCommand(text);
      _textCommandController.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _selectedEntityType = EntityType.none; // Reset selection
        _selectedTestPhrase = null; // Reset dropdown
      });
    }
  }

  // --- Main Build Method (Updated to call new _buildHighlightedText signature) ---
  @override
  Widget build(BuildContext context) {
    final speechService = Provider.of<SpeechService>(context);
    final command = speechService.parsedCommand;

    InlineSpan textSpanToShow = const TextSpan(); // Initialize
    String statusText = "";

    if (speechService.isListening) { statusText = speechService.recognizedWords.isEmpty ? 'Listening...' : speechService.recognizedWords; }
    else if (speechService.lastError.isNotEmpty) { statusText = 'Error: ${speechService.lastError}'; }
    else if (command != null) {
      // *** Call the refactored build method (only needs command and context) ***
      textSpanToShow = _buildHighlightedText(command, context);
    }
    else { statusText = 'Awaiting command...'; }

    if (statusText.isNotEmpty) {
      textSpanToShow = TextSpan(
        text: statusText,
        style: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.w500,
          // Style differently based on content (error vs status)
          color: speechService.lastError.isNotEmpty ? Colors.red.shade700 : Colors.black54,
        ),
      );
    }
    // else: textSpanToShow holds the reconstructed highlighted text

    // Build Edit Action Buttons (Unchanged logic)
    Widget? editActions;
     if (_selectedEntityType != EntityType.none) {
         Function()? buttonAction; String buttonLabel = "Edit"; IconData buttonIcon = Icons.edit;
         switch(_selectedEntityType) {
             case EntityType.file: buttonAction = () => _handleFileAction(context); buttonLabel = "Change File"; buttonIcon = Icons.file_open_outlined; break;
             case EntityType.contact: buttonAction = () => _handleContactAction(context); buttonLabel = "Change Contact"; buttonIcon = Icons.contact_page_outlined; break;
             case EntityType.message: buttonAction = () => _handleMessageAction(context); buttonLabel = "Edit Message"; buttonIcon = Icons.edit_note_outlined; break;
             case EntityType.none: buttonAction = null; break;
         }
         if (buttonAction != null) {
             editActions = ElevatedButton.icon(
                icon: Icon(buttonIcon, size: 16),
                label: Text(buttonLabel),
                onPressed: buttonAction,
                style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                )
            );
         }
     }


    // --- Scaffold and rest of UI (Unchanged structure) ---
    return Scaffold(
      appBar: AppBar(
          title: const Text('Realtor Assistant'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Manage Connections',
              onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionsScreen()));
              },
            ),
          ],
        ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Display Area (RichText)
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                    // Subtle border if something is selected for editing
                    border: _selectedEntityType != EntityType.none
                        ? Border.all(color: Colors.blue.shade300, width: 1.5)
                        : null,
                  ),
                  constraints: const BoxConstraints(minHeight: 100.0),
                  alignment: Alignment.centerLeft,
                  child: Builder(builder: (context) {
                     // Ensure effectiveSpan handles the initialized empty TextSpan correctly
                     final effectiveSpan = (textSpanToShow.toPlainText().isNotEmpty || speechService.isListening || statusText.isNotEmpty) // Check statusText too
                                         ? textSpanToShow
                                         : const TextSpan(text: ' ', style: TextStyle(fontSize: 18.0)); // Placeholder if empty
                     return RichText(textAlign: TextAlign.left, text: effectiveSpan);
                  }),
                ),
              const SizedBox(height: 10),
              // Edit Buttons Area
              AnimatedSize(duration: const Duration(milliseconds: 200), child: editActions ?? const SizedBox.shrink()),
              const SizedBox(height: 20),
              // Test Phrase Dropdown
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
                      child: Text( phrase, overflow: TextOverflow.ellipsis,),);
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTestPhrase = newValue;
                      _textCommandController.text = newValue ?? '';
                       _selectedEntityType = EntityType.none;
                    });
                  },
               ),
              const SizedBox(height: 15),
              // Text Input Row
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
              const SizedBox(height: 20),
              // Microphone Button Area
              const Text('Tap the microphone and speak your command:', style: TextStyle(fontSize: 16.0), textAlign: TextAlign.center,),
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
                                _textCommandController.clear(); // Clear text field
                                _selectedTestPhrase = null; // Clear dropdown
                                speechService.startListening();
                              },
                  ),
              // Initialization Status Error
              if (!speechService.isSpeechEnabled && speechService.lastError.isNotEmpty && !speechService.isListening)
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
  } // End build method
}