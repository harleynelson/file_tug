// ./lib/services/template_service.dart (Updated for First Launch Copy)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle; // Needed for loading assets
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart'; // Needed for generating new IDs
import '../models/message_template.dart';

class TemplateService {

  static const String _jsonFileName = 'message_templates.json'; // User's editable file
  static const String _defaultTemplatesAssetPath = 'assets/default_templates.json'; // Default templates in assets

  List<MessageTemplate> _templates = [];
  bool _isInitialized = false;
  String? _error;
  // Add state for loading status if needed for UI feedback
  bool _isLoading = false;

  // --- Getters ---
  List<MessageTemplate> get templates => List.unmodifiable(_templates);
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isLoading => _isLoading; // Getter for loading state

  // --- Initialization ---
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return; // Prevent multiple initializations

    _isLoading = true;
    _error = null;
    // notifyListeners(); // Notify UI that loading started (if using ChangeNotifier)

    try {
      await _loadTemplates(); // This now includes the first-launch copy logic
      _isInitialized = true;
      print("TemplateService Initialized: Loaded ${_templates.length} templates.");
    } catch (e) {
      print("!!! Error initializing TemplateService: $e");
      _error = "Failed to load templates: $e";
      _templates = [];
      _isInitialized = false; // Ensure it's marked as not initialized on error
    } finally {
       _isLoading = false;
       // notifyListeners(); // Notify UI that loading finished (if using ChangeNotifier)
    }
  }

  // --- Private Helper Methods ---

  /// Gets the path to the user's editable JSON file.
  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, _jsonFileName);
  }

  /// Loads templates, performing first-launch copy if needed.
  Future<void> _loadTemplates() async {
    final filePath = await _getFilePath();
    final file = File(filePath);

    if (await file.exists()) {
      // Load existing user templates
      print("Loading templates from existing file: $filePath");
      try {
        final jsonString = await file.readAsString();
        if (jsonString.isNotEmpty) {
           final List<dynamic> jsonList = jsonDecode(jsonString) as List;
           _templates = jsonList
               .map((jsonItem) => MessageTemplate.fromJson(jsonItem as Map<String, dynamic>))
               .toList();
        } else {
           _templates = []; // File exists but is empty
           print("Template file exists but is empty.");
        }
      } catch (e) {
        print("!!! Error reading or parsing existing template file '$filePath': $e");
        // Decide strategy: Load defaults or throw error? Let's throw for now.
        throw Exception("Error reading existing template data: $e");
      }
    } else {
      // First launch: Copy templates from assets
      print("Template file not found. Performing first-time copy from assets...");
      try {
          final String defaultJsonString = await rootBundle.loadString(_defaultTemplatesAssetPath);
          final List<dynamic> defaultJsonList = jsonDecode(defaultJsonString) as List;

          // Create NEW templates with NEW IDs from the defaults
          const uuid = Uuid();
          _templates = defaultJsonList.map((jsonItem) {
             final defaultTemplate = MessageTemplate.fromJson(jsonItem as Map<String, dynamic>);
             // Create a new template with a new ID, copying other fields
             return MessageTemplate(
                id: uuid.v4(), // Generate new unique ID
                category: defaultTemplate.category,
                title: defaultTemplate.title,
                text: defaultTemplate.text,
             );
          }).toList();

          // Save the newly copied templates to the user's file
          await _saveTemplatesInternal(); // Use internal save to bypass init check here
          print("Copied ${_templates.length} default templates to $filePath");

      } catch (e) {
          print("!!! Error loading or copying default templates from '$_defaultTemplatesAssetPath': $e");
          // If defaults fail, start with empty list but log error
          _templates = [];
           // Optionally set error state: _error = "Failed to load default templates";
           // Don't throw here, allow app to continue with empty templates
      }
    }
  }

  /// Internal save method, bypasses the _isInitialized check needed during first launch copy.
  Future<void> _saveTemplatesInternal() async {
     final filePath = await _getFilePath();
     final file = File(filePath);
     try {
       final jsonList = _templates.map((template) => template.toJson()).toList();
       final jsonString = jsonEncode(jsonList);
       await file.writeAsString(jsonString);
       // Avoid verbose logging during initial copy
       // print("Templates saved successfully to '$filePath'. Count: ${_templates.length}");
     } catch (e) {
       print("!!! Error writing template file '$filePath': $e");
       _error = "Failed to save templates: $e";
       // notifyListeners(); // If needed
       throw Exception("Error saving template data: $e"); // Re-throw critical error
     }
  }


  /// Saves the current list of templates to the user's JSON file. (Public method)
  Future<void> _saveTemplates() async {
     // Public save should only work if initialized without error
     if (!_isInitialized || _error != null) {
         print("Template service not initialized or in error state. Cannot save.");
         throw Exception("Template service not ready. Cannot save.");
     }
     await _saveTemplatesInternal(); // Call internal save logic
      print("Templates saved successfully. Count: ${_templates.length}");
  }

  // --- Public CRUD Methods (Unchanged logic, but rely on _saveTemplates) ---

  List<MessageTemplate> getAllTemplates() {
    return List.unmodifiable(_templates);
  }

  List<MessageTemplate> getTemplatesByCategory(String category) {
    final lowerCaseCategory = category.toLowerCase();
    return List.unmodifiable(
        _templates.where((t) => t.category.toLowerCase() == lowerCaseCategory)
    );
  }

  Map<String, List<MessageTemplate>> getTemplatesGroupedByCategory() {
     Map<String, List<MessageTemplate>> grouped = {};
     for (var template in _templates) { (grouped[template.category] ??= []).add(template); }
     // Optional sorting can be done here or in the UI
     return grouped;
  }

  Future<void> saveTemplate(MessageTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      _templates[index] = template; print("Template updated: ${template.id}");
    } else {
      // Ensure template has a valid ID (should be handled by creation logic)
      if(template.id.isEmpty) throw Exception("Cannot save template without an ID.");
      _templates.add(template); print("Template added: ${template.id}");
    }
    await _saveTemplates();
    // notifyListeners(); // If using ChangeNotifier
  }

   Future<MessageTemplate> createAndAddTemplate({
       required String category, required String title, required String text,
   }) async {
      final newTemplate = MessageTemplate.create( category: category, title: title, text: text, );
      // Add to list locally first
      _templates.add(newTemplate);
      await _saveTemplates(); // Then save
      // notifyListeners(); // If using ChangeNotifier
      return newTemplate;
   }

  Future<void> deleteTemplate(String id) async {
    final initialLength = _templates.length;
    _templates.removeWhere((t) => t.id == id);
    if (_templates.length < initialLength) {
      print("Template deleted: $id");
      await _saveTemplates();
      // notifyListeners(); // If using ChangeNotifier
    } else {
       print("Template not found for deletion: $id");
    }
  }

  /// Reloads templates from the file (e.g., for manual refresh).
  Future<void> refreshTemplates() async {
     print("Refreshing templates from file...");
     _isInitialized = false; // Force re-initialization
     await initialize(); // This will re-run the load logic
  }
}