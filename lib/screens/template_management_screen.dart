// ./lib/screens/template_management_screen.dart (New File)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_template.dart';
import '../services/template_service.dart';

class TemplateManagementScreen extends StatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  State<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  late Future<void> _initTemplatesFuture;
  // Controllers for the Add/Edit Dialog
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _textController = TextEditingController();
  MessageTemplate? _editingTemplate; // Track if editing existing template

  @override
  void initState() {
    super.initState();
    // Initialize the service when the screen is first created
    _initTemplatesFuture = Provider.of<TemplateService>(context, listen: false).initialize();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // --- Dialog for Adding/Editing Templates ---
  Future<void> _showAddEditDialog({MessageTemplate? template}) async {
     _editingTemplate = template; // Set if editing

     // Pre-fill controllers if editing
     if (_editingTemplate != null) {
        _titleController.text = _editingTemplate!.title;
        _categoryController.text = _editingTemplate!.category;
        _textController.text = _editingTemplate!.text;
     } else {
        // Clear controllers if adding
        _titleController.clear();
        _categoryController.clear();
        _textController.clear();
     }

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        final templateService = Provider.of<TemplateService>(context, listen: false);
        return AlertDialog(
          title: Text(_editingTemplate == null ? 'Add New Template' : 'Edit Template'),
          content: SingleChildScrollView(
             child: Form(
               key: _formKey,
               child: Column(
                  mainAxisSize: MainAxisSize.min, // Important for Dialog content
                  children: <Widget>[
                     TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) => (value == null || value.isEmpty) ? 'Please enter a title' : null,
                     ),
                     TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(labelText: 'Category'),
                         validator: (value) => (value == null || value.isEmpty) ? 'Please enter a category' : null,
                     ),
                     TextFormField(
                        controller: _textController,
                        decoration: const InputDecoration(labelText: 'Template Text'),
                        maxLines: 5, // Allow multi-line input
                        keyboardType: TextInputType.multiline,
                         validator: (value) => (value == null || value.isEmpty) ? 'Please enter template text' : null,
                     ),
                  ],
               ),
             ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _editingTemplate = null; // Clear editing state
              },
            ),
            TextButton(
              child: Text(_editingTemplate == null ? 'Add' : 'Save'),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                   MessageTemplate templateToSave;
                   if (_editingTemplate != null) {
                      // Update existing template
                      templateToSave = _editingTemplate!.copyWith(
                         title: _titleController.text.trim(),
                         category: _categoryController.text.trim(),
                         text: _textController.text.trim(),
                      );
                   } else {
                      // Create new template
                      templateToSave = MessageTemplate.create(
                         title: _titleController.text.trim(),
                         category: _categoryController.text.trim(),
                         text: _textController.text.trim(),
                      );
                   }

                  try {
                      await templateService.saveTemplate(templateToSave);
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Template ${ _editingTemplate == null ? 'added' : 'saved'} successfully!')) );
                         Navigator.of(context).pop(); // Close dialog
                         _editingTemplate = null; // Clear editing state
                         setState(() {}); // Trigger rebuild to show changes
                      }
                  } catch (e) {
                     print("Error saving template: $e");
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error saving template: $e'), backgroundColor: Colors.red,) );
                      }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }


  // --- Deletion Confirmation Dialog ---
  Future<void> _confirmDelete(BuildContext context, MessageTemplate template) async {
     return showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
           final templateService = Provider.of<TemplateService>(context, listen: false);
           return AlertDialog(
              title: const Text('Confirm Delete'),
              content: Text('Are you sure you want to delete the template "${template.title}"?'),
              actions: <Widget>[
                 TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                 ),
                 TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                    onPressed: () async {
                       try {
                           await templateService.deleteTemplate(template.id);
                            if (mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template deleted.')));
                               Navigator.of(dialogContext).pop(); // Close confirmation dialog
                               setState(() {}); // Trigger rebuild
                            }
                       } catch (e) {
                            print("Error deleting template: $e");
                             if (mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting template: $e'), backgroundColor: Colors.red));
                            }
                       }
                    },
                 ),
              ],
           );
        },
     );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Message Templates'),
        actions: [
          // Optional: Add a refresh button if needed
          IconButton(
             icon: const Icon(Icons.refresh),
             tooltip: 'Reload Templates',
             onPressed: () {
                // Re-initialize and trigger rebuild
                setState(() {
                   _initTemplatesFuture = Provider.of<TemplateService>(context, listen: false).initialize();
                });
             },
          )
        ],
      ),
      body: FutureBuilder<void>(
        future: _initTemplatesFuture,
        builder: (context, snapshot) {
          // Access the service *after* the future completes or use Consumer
          final templateService = Provider.of<TemplateService>(context, listen: false); // Use listen: false in builder if using setState

          // Handle loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Handle error state during initialization
          if (snapshot.hasError || templateService.error != null) {
            return Center(
               child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading templates: ${snapshot.error ?? templateService.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
               )
            );
          }

          // Data loaded successfully, get grouped templates
          final groupedTemplates = templateService.getTemplatesGroupedByCategory();
          final categories = groupedTemplates.keys.toList()..sort(); // Sort category names

          // Handle empty state
          if (groupedTemplates.isEmpty) {
             return const Center(
                 child: Text(
                    'No templates found. Tap the + button to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                 ),
             );
          }

          // Display templates grouped by category
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final templatesInCategory = groupedTemplates[category]!;
              // Sort templates within category by title
              templatesInCategory.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

              return ExpansionTile(
                title: Text(category, style: Theme.of(context).textTheme.titleLarge),
                initiallyExpanded: true, // Optional: Expand all categories by default
                children: templatesInCategory.map((template) {
                  return ListTile(
                    title: Text(template.title),
                    subtitle: Text(
                       template.text,
                       maxLines: 2, // Show preview of text
                       overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                       mainAxisSize: MainAxisSize.min, // Keep icons tight
                       children: [
                          IconButton(
                             icon: const Icon(Icons.edit_outlined, size: 20),
                             tooltip: 'Edit Template',
                             onPressed: () => _showAddEditDialog(template: template),
                             visualDensity: VisualDensity.compact, // Make button smaller
                          ),
                          IconButton(
                             icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
                             tooltip: 'Delete Template',
                             onPressed: () => _confirmDelete(context, template),
                              visualDensity: VisualDensity.compact,
                          ),
                       ],
                    ),
                    // Optional: Add onTap to view full text if needed
                    // onTap: () { /* Show full text dialog */ }
                  );
                }).toList(),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(), // Call without template to add new
        tooltip: 'Add New Template',
        child: const Icon(Icons.add),
      ),
    );
  }
}