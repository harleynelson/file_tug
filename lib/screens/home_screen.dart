// ./lib/screens/home_screen.dart (Entire File - Updated for Template Integration)

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/connection_service.dart';
import '../services/template_service.dart'; // Import TemplateService
import '../models/parsed_command.dart';
import '../models/message_template.dart'; // Import MessageTemplate model
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path/path.dart' as p;
import 'connections_screen.dart';
import 'template_management_screen.dart'; // Import management screen for navigation
import '../testing/phrases.dart'; // Keep for testing UI

enum EntityType { file, contact, messageBlock, none } // Added messageBlock

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EntityType _selectedEntityType = EntityType.none;
  int _selectedMessageBlockIndex = -1; // Track selected message block index
  final TextEditingController _messageEditController = TextEditingController();
  final TextEditingController _textCommandController = TextEditingController();
  String? _selectedTestPhrase;
  // For template selection modal
  String? _selectedCategoryFilter;


  @override
  void initState() {
    super.initState();
    // Initialize services (TemplateService init handled within its usage below)
    Provider.of<SpeechService>(context, listen: false).initialize();
    Provider.of<TemplateService>(context, listen: false).initialize(); // Initialize templates
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

  // --- Edit Action Handlers (File/Contact are mostly unchanged) ---
  Future<void> _handleFileAction(BuildContext context) async {
     final speechService = Provider.of<SpeechService>(context, listen: false);
    final connectionService = Provider.of<ConnectionService>(context, listen: false);
    final currentStatus = speechService.parsedCommand?.fileStatus;
    print("Handling file action. Current status: $currentStatus");
    try {
        await connectionService.pickLocalFiles(allowMultiple: false);
        if (connectionService.lastPickedFilePath != null) {
          String filePath = connectionService.lastPickedFilePath!;
          String displayFileName = p.basename(filePath);
          speechService.userSelectedFile(filePath, displayFileName);
        } else { print("File picking cancelled."); }
    } catch(e) {
        print("Error picking file: $e");
        if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error picking file: $e')),
            );
        }
     }
    finally {
        // Deselect after action complete or cancelled
        if(mounted) { // Check if widget is still mounted
           setState(() { _selectedEntityType = EntityType.none; });
        }
    }
  }

  Future<void> _handleContactAction(BuildContext context) async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    if (!await FlutterContacts.requestPermission(readonly: true)) {
        if(context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Contact permission is needed to select a recipient.')
          ));
        }
        setState(() { _selectedEntityType = EntityType.none; });
        return;
     }
    Contact? contact;
    try {
      contact = await FlutterContacts.openExternalPick();
      if (contact != null) { speechService.userSelectedContact(contact.id, contact.displayName); }
      else { print("Contact selection cancelled or failed."); }
    } catch (e) {
        print("Error picking contact: $e");
        if(context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error selecting contact: $e')
          ));
        }
     }
    finally {
        // Deselect after action complete or cancelled
         if(mounted) { // Check if widget is still mounted
           setState(() { _selectedEntityType = EntityType.none; });
         }
    }
  }

  // --- NEW: Message Block Specific Actions ---

  /// Opens dialog to edit a specific message block
  Future<void> _editMessageBlock(BuildContext context, int index) async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    final currentBlocks = speechService.parsedCommand?.messageBlocks;
    if (currentBlocks == null || index < 0 || index >= currentBlocks.length) return;

    final currentText = currentBlocks[index];
    _messageEditController.text = currentText; // Use shared controller

    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Message Block ${index + 1}'),
        content: TextField(
          controller: _messageEditController,
          autofocus: true,
          maxLines: null, // Allow multi-line
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(hintText: 'Enter message content'),
        ),
        actions: [
          TextButton( child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(), ),
          TextButton( child: const Text('Save'), onPressed: () => Navigator.of(context).pop(_messageEditController.text), ),
        ],
      ),
    );

    // Only update if text changed
    if (newText != null && newText != currentText) {
       speechService.updateMessageBlock(index, newText);
    }
    // Deselect after editing attempt
    if(mounted) setState(() { _selectedEntityType = EntityType.none; _selectedMessageBlockIndex = -1; });
  }

   /// Shows confirmation and deletes a message block
   Future<void> _deleteMessageBlock(BuildContext context, int index) async {
     final speechService = Provider.of<SpeechService>(context, listen: false);
     final currentBlocks = speechService.parsedCommand?.messageBlocks;
     if (currentBlocks == null || index < 0 || index >= currentBlocks.length) return;

     final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
           title: Text('Delete Block ${index + 1}?'),
           content: const Text('Are you sure you want to remove this message block?'),
           actions: [
              TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
              TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true)),
           ],
        ),
     );

     if (confirm == true) {
        speechService.removeMessageBlock(index);
     }
      // Deselect after delete attempt
     if(mounted) setState(() { _selectedEntityType = EntityType.none; _selectedMessageBlockIndex = -1; });
   }

   // --- Template Selection Modal ---
   Future<void> _showTemplateSelection() async {
      final templateService = Provider.of<TemplateService>(context, listen: false);
      final speechService = Provider.of<SpeechService>(context, listen: false);

      // Ensure templates are loaded (might show loading indicator briefly if not)
      if (!templateService.isInitialized) {
         await templateService.initialize();
         // Rebuild modal content if needed after init
         if (mounted) setState(() {});
      }

      // Get templates and categories
      final groupedTemplates = templateService.getTemplatesGroupedByCategory();
      final allCategories = ['All']..addAll(groupedTemplates.keys.toList()..sort()); // Add 'All' option


      // ignore: use_build_context_synchronously
      return showModalBottomSheet<void>(
         context: context,
         isScrollControlled: true, // Allow modal to take more height
         builder: (BuildContext modalContext) {
            // Use StatefulWidget for local state management (category filter) inside modal
            return StatefulBuilder(
               builder: (BuildContext context, StateSetter setModalState) {

                 // Filter templates based on the selected category
                 List<MessageTemplate> filteredTemplates = [];
                 if (_selectedCategoryFilter == null || _selectedCategoryFilter == 'All') {
                    // Flatten all templates if 'All' is selected
                    groupedTemplates.values.forEach((list) => filteredTemplates.addAll(list));
                 } else {
                    filteredTemplates = groupedTemplates[_selectedCategoryFilter] ?? [];
                 }
                  // Sort filtered templates by title
                 filteredTemplates.sort((a,b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));


                 return DraggableScrollableSheet(
                     expand: false, // Don't expand fully initially
                     initialChildSize: 0.6, // Start at 60% height
                     minChildSize: 0.3,
                     maxChildSize: 0.9,
                     builder: (_, controller) {
                       return Container(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Text('Select Message Templates', style: Theme.of(context).textTheme.headlineSmall),
                                const SizedBox(height: 10),
                                // Category Filter Dropdown
                                DropdownButton<String>(
                                   value: _selectedCategoryFilter ?? 'All',
                                   hint: const Text('Filter by Category'),
                                   isExpanded: true,
                                   items: allCategories.map((String category) {
                                      return DropdownMenuItem<String>( value: category, child: Text(category), );
                                   }).toList(),
                                   onChanged: (String? newValue) {
                                      setModalState(() { _selectedCategoryFilter = newValue; });
                                   },
                                ),
                                const SizedBox(height: 10),
                                // List of Templates
                                Expanded(
                                   child: // *** REMOVED isLoading check ***
                                      filteredTemplates.isEmpty
                                         ? Center(child: Text('No templates found${_selectedCategoryFilter != null && _selectedCategoryFilter != 'All' ? ' in category "$_selectedCategoryFilter"' : ''}.'))
                                         : ListView.builder(
                                            controller: controller, // Use controller for scrolling
                                            itemCount: filteredTemplates.length,
                                            itemBuilder: (context, index) {
                                               final template = filteredTemplates[index];
                                               return Card(
                                                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: ListTile(
                                                     title: Text(template.title),
                                                     subtitle: Text(template.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                                                     // Use onTap for quick add
                                                     onTap: () {
                                                        speechService.addMessageBlock(template.text);
                                                        Navigator.pop(modalContext); // Close modal after adding
                                                         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Added template: "${template.title}"'), duration: const Duration(seconds: 1),) );
                                                     },
                                                     // Optional: Add trailing button for more info/preview?
                                                  ),
                                               );
                                            },
                                         ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                   mainAxisAlignment: MainAxisAlignment.end,
                                   children: [
                                      TextButton(
                                        child: const Text('Manage Templates'),
                                        onPressed: () {
                                           Navigator.pop(modalContext); // Close modal
                                           Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplateManagementScreen()));
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('Close'),
                                        onPressed: () => Navigator.pop(modalContext),
                                      ),
                                   ],
                                )
                             ],
                          ),
                       );
                    },
                 );
               }
            );
         },
      ).whenComplete(() {
          // Reset filter when modal closes
          _selectedCategoryFilter = null;
      });
   }


  // --- Build Highlighted Text (Handles File/Contact only now) ---
  InlineSpan _buildEntitySpan(ParsedCommand? command, BuildContext context) {
    // Default styles
    final defaultStyle = TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.black87);
    final highlightStyleBase = defaultStyle.copyWith(fontWeight: FontWeight.bold);
    final annotationStyle = TextStyle(fontSize: 12.0, color: Colors.black54, fontStyle: FontStyle.italic);
    final resolvedStyle = annotationStyle.copyWith(color: Colors.green.shade800, fontWeight: FontWeight.bold);
    final errorStyle = annotationStyle.copyWith(color: Colors.red.shade800, fontWeight: FontWeight.bold);

    // Handle null or failed parse
    if (command == null || !command.parseSuccess) {
      return TextSpan(text: command?.originalText ?? 'Awaiting command...', style: defaultStyle.copyWith(color: Colors.black54));
    }

    // Helper function (same as before)
    Map<String, dynamic> getEntityStyle(EntityType type, AssociationStatus status, String? resolvedValue) {
       String annotationText; Color bgColor; InlineSpan? statusIndicator;
       switch (status) { /* ... cases remain the same ... */
          case AssociationStatus.pending: bgColor = Colors.orange.shade100; annotationText = type == EntityType.file ? 'File' : 'Contact'; statusIndicator = TextSpan(text: ' [Searching...]', style: annotationStyle.copyWith(color: Colors.orange.shade900)); break;
          case AssociationStatus.notFound: case AssociationStatus.lookupFailed: bgColor = Colors.red.shade100; annotationText = type == EntityType.file ? 'File' : 'Contact'; statusIndicator = TextSpan(text: ' [Not Found]', style: errorStyle); break;
          case AssociationStatus.foundSingle: case AssociationStatus.userSelected: bgColor = Colors.green.shade100; annotationText = type == EntityType.file ? 'File' : 'Contact'; String displayValue = resolvedValue ?? 'Selected'; if (type == EntityType.file && resolvedValue != null) displayValue = p.basename(resolvedValue); statusIndicator = TextSpan(text: ' [$displayValue]', style: resolvedStyle); break;
          case AssociationStatus.foundMultiple: bgColor = Colors.yellow.shade300; annotationText = type == EntityType.file ? 'File' : 'Contact'; statusIndicator = TextSpan(text: ' [Multiple Found]', style: annotationStyle.copyWith(color: Colors.deepOrange.shade800, fontWeight: FontWeight.bold)); break;
       }
       return {'annotation': annotationText, 'color': bgColor, 'statusIndicator': statusIndicator};
    }

    // Helper function (same as before)
     InlineSpan createHighlightSpan({ required String? entityText, required EntityType entityType, required AssociationStatus status, required String? resolvedValue, required Function() onTapAction, }) {
      if (entityText == null || entityText.isEmpty) return const TextSpan(text: "[Unknown]"); // Placeholder if missing

      final styleInfo = getEntityStyle(entityType, status, resolvedValue);
      final String annotation = styleInfo['annotation']; final Color bgColor = styleInfo['color']; final InlineSpan? statusIndicator = styleInfo['statusIndicator'];
      bool showErrorIndicator = status == AssociationStatus.notFound || status == AssociationStatus.lookupFailed || status == AssociationStatus.foundMultiple;
      TextDecoration? decoration; Color? decorationColor; double? decorationThickness;

      if (_selectedEntityType == entityType) { decoration = TextDecoration.underline; decorationColor = Colors.blue.shade700; decorationThickness = 2; }
      else if (showErrorIndicator) { decoration = TextDecoration.underline; decorationColor = Colors.red.shade700; decorationThickness = 1.5; }

      return TextSpan( children: [
          TextSpan( text: entityText, style: highlightStyleBase.copyWith( backgroundColor: bgColor, decoration: decoration, decorationColor: decorationColor, decorationThickness: decorationThickness, ),
            recognizer: TapGestureRecognizer()..onTap = () {
                print("Tapped on $entityType (Status: $status)");
                setState(() { _selectedEntityType = (_selectedEntityType == entityType) ? EntityType.none : entityType; _selectedMessageBlockIndex = -1; }); // Deselect message block
            }, ),
          const TextSpan(text: ' '), TextSpan(text: '[$annotation]', style: annotationStyle), if (statusIndicator != null) statusIndicator, ], );
    }

    // --- Construct File and Contact Spans Only ---
    List<InlineSpan> spans = [];
    spans.add(const TextSpan(text: "File: "));
    spans.add(createHighlightSpan(
        entityText: command.fileName ?? command.originalFileName, // Fallback to original
        entityType: EntityType.file,
        status: command.fileStatus,
        resolvedValue: command.resolvedFilePath,
        onTapAction: () => _handleFileAction(context),
    ));
    spans.add(const TextSpan(text: " | Contact: "));
    spans.add(createHighlightSpan(
        entityText: command.contactName ?? command.originalContactName, // Fallback to original
        entityType: EntityType.contact,
        status: command.contactStatus,
        resolvedValue: command.resolvedContactId,
        onTapAction: () => _handleContactAction(context),
    ));

    return TextSpan(style: defaultStyle, children: spans);
  }

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


  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // Listen to SpeechService for updates
    final speechService = Provider.of<SpeechService>(context);
    final command = speechService.parsedCommand;
    final messageBlocks = command?.messageBlocks ?? []; // Get current message blocks

    // --- Build Entity Header (File/Contact) ---
    // Use a separate widget area for File/Contact status
    Widget entityHeader = Container(
       padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
       child: RichText(text: _buildEntitySpan(command, context)),
    );

    // --- Build Reorderable Message List ---
    Widget messageArea;
    if (messageBlocks.isEmpty) {
       messageArea = Container(
           padding: const EdgeInsets.all(16),
           alignment: Alignment.center,
           child: const Text("No message content yet. Add templates or use voice command.", style: TextStyle(color: Colors.grey)),
       );
    } else {
       messageArea = ReorderableListView.builder(
          shrinkWrap: true, // Important inside SingleChildScrollView
          physics: const NeverScrollableScrollPhysics(), // Disable its own scrolling
          itemCount: messageBlocks.length,
          itemBuilder: (context, index) {
             final blockText = messageBlocks[index];
             // Use index as key for reordering
             final itemKey = ValueKey('msgBlock_$index');
             // Highlight if selected
             bool isSelected = _selectedEntityType == EntityType.messageBlock && _selectedMessageBlockIndex == index;

             return Card(
                key: itemKey,
                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                elevation: isSelected ? 4.0 : 1.0,
                shape: isSelected ? RoundedRectangleBorder( side: BorderSide(color: Theme.of(context).primaryColor, width: 2.0), borderRadius: BorderRadius.circular(4.0), ) : null,
                child: ListTile(
                  // contentPadding: EdgeInsets.zero,
                   leading: Tooltip(
                      message: 'Drag to Reorder',
                      child: ReorderableDragStartListener( // Drag handle
                         index: index,
                         child: const Icon(Icons.drag_handle),
                      ),
                   ),
                   title: Text(blockText),
                    onTap: () { // Select block on tap
                       setState(() {
                          if (isSelected) {
                             _selectedEntityType = EntityType.none;
                             _selectedMessageBlockIndex = -1;
                          } else {
                             _selectedEntityType = EntityType.messageBlock;
                             _selectedMessageBlockIndex = index;
                          }
                       });
                    },
                   trailing: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Edit Block',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _editMessageBlock(context, index),
                         ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
                            tooltip: 'Delete Block',
                             visualDensity: VisualDensity.compact,
                            onPressed: () => _deleteMessageBlock(context, index),
                         ),
                       ],
                    ),
                ),
             );
          },
          onReorder: (oldIndex, newIndex) {
             // Important: This callback provides indices *before* the move visually happens.
             // The SpeechService handles the list update logic.
             speechService.reorderMessageBlocks(oldIndex, newIndex);
             // No need to call setState here usually, SpeechService notifies listeners.
             // If visual glitches occur, uncomment setState:
             // setState(() {});
          },
       );
    }

    // --- Build Edit Action Buttons ---
    Widget? editActions;
    // Simplified - only show edit button if a message block is selected
    if (_selectedEntityType == EntityType.messageBlock && _selectedMessageBlockIndex != -1) {
       editActions = Row(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_note_outlined, size: 16),
              label: Text("Edit Block ${_selectedMessageBlockIndex + 1}"),
              onPressed: () => _editMessageBlock(context, _selectedMessageBlockIndex),
              style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(width: 8),
             ElevatedButton.icon(
              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade700),
              label: Text("Delete Block ${_selectedMessageBlockIndex + 1}", style: TextStyle(color: Colors.red.shade700)),
              onPressed: () => _deleteMessageBlock(context, _selectedMessageBlockIndex),
              style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: Colors.white, foregroundColor: Colors.red.shade700),
            ),
         ],
       );
    } else if (_selectedEntityType == EntityType.file) {
         editActions = ElevatedButton.icon( icon: const Icon(Icons.file_open_outlined, size: 16), label: const Text("Change File"), onPressed: () => _handleFileAction(context), style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact));
    } else if (_selectedEntityType == EntityType.contact) {
         editActions = ElevatedButton.icon( icon: const Icon(Icons.contact_page_outlined, size: 16), label: const Text("Change Contact"), onPressed: () => _handleContactAction(context), style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact));
    }


    // --- UI Structure ---
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtor Assistant'),
        actions: [
            // Navigate to Template Management
            IconButton(
               icon: const Icon(Icons.list_alt_outlined),
               tooltip: 'Manage Templates',
               onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplateManagementScreen()));
               },
            ),
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
            // Align content towards top
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
            children: <Widget>[
              // File/Contact Header
              entityHeader,
              const Divider(height: 20, thickness: 1),

              // Message Composition Area Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text("Message Content", style: Theme.of(context).textTheme.titleMedium),
                   TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text("Add Template"),
                      onPressed: _showTemplateSelection,
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                   )
                ],
              ),
              const SizedBox(height: 8),

              // Message Blocks Area
              Container(
                 padding: const EdgeInsets.all(8.0),
                 decoration: BoxDecoration(
                   color: Colors.grey[100],
                   borderRadius: BorderRadius.circular(4.0),
                   border: Border.all(color: Colors.grey.shade300)
                 ),
                 constraints: const BoxConstraints(minHeight: 100.0), // Ensure minimum height
                 child: messageArea, // Display list or 'empty' text
              ),
              const SizedBox(height: 10),

              // Edit Buttons Area
              AnimatedSize( duration: const Duration(milliseconds: 200), child: editActions ?? const SizedBox(height: 36) ), // Placeholder height when no button
              const SizedBox(height: 20), // Spacing

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
                       _selectedMessageBlockIndex = -1; // Deselect block index too
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
              // Show listening status OR error OR idle text
              _buildStatusArea(speechService),
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
                                setState(() {
                                   _selectedEntityType = EntityType.none;
                                   _selectedMessageBlockIndex = -1;
                                 });
                                _textCommandController.clear(); // Clear text field
                                _selectedTestPhrase = null; // Clear dropdown
                                speechService.startListening();
                              },
                  ),

              // Initialization Status Error (keep existing logic)
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


   // Helper to build the status area below Mic button
   Widget _buildStatusArea(SpeechService speechService) {
     if (speechService.isListening) {
       return Text(
         speechService.recognizedWords.isEmpty ? 'Listening...' : speechService.recognizedWords,
         style: const TextStyle(fontSize: 16.0, color: Colors.blueGrey),
         textAlign: TextAlign.center,
       );
     } else if (speechService.lastError.isNotEmpty && !speechService.isSpeechEnabled) {
       // Show initialization errors here
       return const SizedBox.shrink(); // Error shown at bottom already
     } else if (speechService.lastError.isNotEmpty) {
        // Show NLU/Processing errors here
        return Text(
         'Error: ${speechService.lastError}',
         style: const TextStyle(fontSize: 16.0, color: Colors.red),
         textAlign: TextAlign.center,
       );
     } else {
       // Idle state
       return const Text(
         'Tap the microphone or type a command.',
         style: TextStyle(fontSize: 16.0, color: Colors.grey),
         textAlign: TextAlign.center,
       );
     }
   }

} // End _HomeScreenState class