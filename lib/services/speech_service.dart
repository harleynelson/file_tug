// ./lib/services/speech_service.dart (Entire File - Revised Logic)

import 'dart:async'; // Required for Timer if needed later, but not now
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'command_parser_service.dart';
import '../models/parsed_command.dart';

class SpeechService with ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  final CommandParserService _parserService = CommandParserService();

  bool _isSpeechEnabled = false;
  bool _isListening = false;
  String _lastWords = "";
  String _currentError = "";
  ParsedCommand? _parsedCommand;

  // --- New state variables for final result handling ---
  String? _finalRecognizedText; // Stores text specifically marked as final=true
  bool _finalResultReceived = false; // Flag if we received final=true
  bool _parsingAttempted = false; // Ensure parsing happens only once per session

  // --- Getters ---
  bool get isListening => _isListening;
  bool get isSpeechEnabled => _isSpeechEnabled;
  String get recognizedWords => _lastWords; // Keep showing live words
  String get lastError => _currentError;
  ParsedCommand? get parsedCommand => _parsedCommand;

  Future<void> initialize() async {
    // Clear state just in case
    _resetState();
    try {
      _isSpeechEnabled = await _speechToText.initialize(
        onError: _statusErrorListener,
        onStatus: _statusListener,
      );
      if (!_isSpeechEnabled) {
        _currentError = "Speech recognition not available.";
      } else {
        _currentError = "";
      }
    } catch (e) {
      _isSpeechEnabled = false;
      _currentError = "Error initializing speech: ${e.toString()}";
      print("Error initializing speech: $e");
    }
    notifyListeners();
  }

  // Helper to reset session state
  void _resetState() {
     _lastWords = "";
     _currentError = "";
     _parsedCommand = null;
     _finalRecognizedText = null;
     _finalResultReceived = false;
     _parsingAttempted = false;
     // _isListening state managed by listeners/controls
  }

  void startListening() {
    if (!_isSpeechEnabled || _isListening) return;

    _resetState(); // Reset all state for new session
    notifyListeners(); // Update UI immediately (e.g., clear old text)

    print("Starting speech listening (max 30 seconds or manual stop)...");

    _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 30),
      localeId: "en_US",
    );
    // Let statusListener set _isListening = true
  }

  void stopListening() {
    if (!_isListening) {
      print("StopListening called but already not listening.");
      return;
    }
    print("StopListening called manually.");
    _speechToText.stop(); // Request stop

    // Assume stopped locally for UI responsiveness
    _isListening = false;
    print("--> State updated: No Longer Listening (manual stop)");

    // Attempt final parse if not already done
    _tryFinalParse();

    // Notify UI about listening state change and potentially parsed command
    notifyListeners();
  }

  /// Called when the speech recognition result is available
  void _onSpeechResult(SpeechRecognitionResult result) {
    // Always update the live words
    _lastWords = result.recognizedWords;
    print("Speech Result: '$_lastWords' (Final: ${result.finalResult})");

    // If this result is marked as final, store it and set the flag
    if (result.finalResult) {
      print("--> FinalResult flag received. Storing final text.");
      _finalRecognizedText = result.recognizedWords;
      _finalResultReceived = true;
      // Do NOT parse here, wait for session end signals
    }

    // Notify UI to update with the latest live words
    notifyListeners();
  }

  /// Called when the listening status changes
  void _statusListener(String status) {
    print('Speech status changed: $status - Current _isListening state: $_isListening');

    if (status == SpeechToText.listeningStatus) {
      if (!_isListening) {
         _isListening = true;
         _currentError = ""; // Clear error on successful listen start
         print("--> State updated: Now Listening");
         notifyListeners();
      }
    } else { // Status implies not listening ('done', 'notListening', etc.)
      if (_isListening) { // Only act if we thought we were listening
         _isListening = false;
         print("--> State updated: No Longer Listening (stopped by status change: $status)");

         // Attempt final parse if not already done
         _tryFinalParse();

         notifyListeners(); // Notify UI about listening state change and potentially parsed command
      } else {
        print("--> Status indicates not listening ($status), state was already false.");
        // It's possible a 'done' status comes slightly after 'notListening' was already processed
        // or after stopListening was called manually. In this case, parsing should have already
        // been attempted by the first event that set _isListening to false.
      }
    }
  }

  /// Called on recognition errors
  void _statusErrorListener(dynamic errorNotification) {
      print('!!! Speech Error Received: $errorNotification - Listening state was: $_isListening');
      _currentError = "Error: ${errorNotification.errorMsg} (${errorNotification.permanent ? 'Permanent' : 'Temporary'})";
      if (_isListening) {
          _isListening = false;
          print("--> State updated: No Longer Listening due to error.");

          // Attempt final parse with potentially incomplete words on error? Or just show error?
          // Let's prioritize showing the error. We could optionally try parsing _lastWords here.
          _tryFinalParse(parseOnError: true); // Optionally parse on error

          notifyListeners();
      } else {
         print("--> Error received but state was already not listening.");
         notifyListeners(); // Still notify to show the error message
      }
  }

  // --- Centralized Parsing Logic ---
  /// Attempts to parse the final text, ensuring it only happens once.
  /// Prioritizes text marked with finalResult=true if available.
  void _tryFinalParse({bool parseOnError = false}) {
     if (_parsingAttempted) {
        print("--> Final parse already attempted for this session.");
        return; // Only parse once
     }
     _parsingAttempted = true;

     String? textToParse;

     // Prioritize the text received with the finalResult flag
     if (_finalResultReceived && _finalRecognizedText != null) {
        textToParse = _finalRecognizedText;
        print("Parsing final text (from finalResult=true): '$textToParse'");
     } else if (_lastWords.isNotEmpty) {
        // Fallback to the last known words if no finalResult flag was received
        // (e.g., manual stop before final flag, maybe some errors)
        textToParse = _lastWords;
         print("Parsing final text (fallback to last words): '$textToParse'");
     } else {
         print("No text available to parse.");
         return; // Nothing to parse
     }

     // Only proceed if we have text
     if (textToParse != null && textToParse.isNotEmpty) {
         _parsedCommand = _parserService.parseSendCommand(textToParse);
         print("Parser result: Success=${_parsedCommand?.parseSuccess}, File='${_parsedCommand?.fileName}', Contact='${_parsedCommand?.contactName}', Message='${_parsedCommand?.messageBody}'");

         // Optionally clear error if parsing succeeds after an error occurred?
         // if (!parseOnError && _parsedCommand?.parseSuccess == true && _currentError.isNotEmpty) {
         //    _currentError = "";
         // }
     } else {
         print("Final text to parse was empty.");
     }
     // No need to notify here, the calling methods (stopListening, statusListener, errorListener) will notify.
  }


  // --- Update Methods for Parsed Command (Keep Existing) ---
  void updateParsedFileName(String newFileName) { /* ... no change ... */
      if (_parsedCommand == null) return;
    _parsedCommand = ParsedCommand(
      originalText: _parsedCommand!.originalText,
      fileName: newFileName,
      contactName: _parsedCommand!.contactName,
      messageBody: _parsedCommand!.messageBody,
      parseSuccess: _parsedCommand!.parseSuccess,
    );
    print("SpeechService: Updated file name to '$newFileName'");
    notifyListeners();
   }
  void updateParsedContactName(String newContactName) { /* ... no change ... */
      if (_parsedCommand == null) return;
    _parsedCommand = ParsedCommand(
      originalText: _parsedCommand!.originalText,
      fileName: _parsedCommand!.fileName,
      contactName: newContactName,
      messageBody: _parsedCommand!.messageBody,
      parseSuccess: _parsedCommand!.parseSuccess,
    );
     print("SpeechService: Updated contact name to '$newContactName'");
    notifyListeners();
  }
  void updateParsedMessageBody(String newMessageBody) { /* ... no change ... */
      if (_parsedCommand == null) return;
    _parsedCommand = ParsedCommand(
      originalText: _parsedCommand!.originalText,
      fileName: _parsedCommand!.fileName,
      contactName: _parsedCommand!.contactName,
      messageBody: newMessageBody,
      parseSuccess: _parsedCommand!.parseSuccess,
    );
     print("SpeechService: Updated message body to '$newMessageBody'");
    notifyListeners();
  }
  void setParseSuccess(bool success) { /* ... no change ... */
       if (_parsedCommand == null) return;
     _parsedCommand = ParsedCommand(
      originalText: _parsedCommand!.originalText,
      fileName: _parsedCommand!.fileName,
      contactName: _parsedCommand!.contactName,
      messageBody: _parsedCommand!.messageBody,
      parseSuccess: success,
    );
     print("SpeechService: Updated parse success to '$success'");
    notifyListeners();
   }

  // --- Local Storage Methods etc (Keep Existing) ---
  // ... (appDocumentsPath, listAppDirectoryFiles, pickLocalFiles, etc.) ...
  String? _appDocumentsPath;
  List<FileSystemEntity> _appDirectoryFiles = [];
  bool _isLocalLoading = false;
  String? _lastPickedFilePath;
  String? get appDocumentsPath => _appDocumentsPath;
  List<FileSystemEntity> get appDirectoryFiles => _appDirectoryFiles;
  bool get isLocalLoading => _isLocalLoading;
  String? get lastPickedFilePath => _lastPickedFilePath;
  bool get isLocalStorageAvailable => _appDocumentsPath != null;

    Future<void> _loadAppDirectoryPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
      print("App Documents Path: $_appDocumentsPath");
    } catch (e) {
      print("Error getting app documents directory: $e");
      _appDocumentsPath = null; // Ensure it's null on error
    }
  }
   Future<void> listAppDirectoryFiles() async {
     if (_appDocumentsPath == null || _isLocalLoading) return;
    _isLocalLoading = true;
    _appDirectoryFiles = []; // Clear previous list
    notifyListeners();
    try {
      final dir = Directory(_appDocumentsPath!);
      final List<FileSystemEntity> entities = await dir.list().toList();
      _appDirectoryFiles = entities;
      print("Found ${_appDirectoryFiles.length} items in app directory.");
    } catch (e) {
      print("Error listing files in app directory: $e");
      _appDirectoryFiles = []; // Clear list on error
    } finally {
      _isLocalLoading = false;
      notifyListeners();
    }
  }
   Future<void> pickLocalFiles({bool allowMultiple = false}) async {
    if (_isLocalLoading) return;
    _isLocalLoading = true;
    _lastPickedFilePath = null; // Clear previous pick
    notifyListeners();
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: allowMultiple,
      );
      if (result != null) {
        if (allowMultiple) {
          print("Picked ${result.files.length} files");
          _lastPickedFilePath = result.files.first.path;
        } else if (result.files.single.path != null) {
           _lastPickedFilePath = result.files.single.path!;
           print("Picked file: $_lastPickedFilePath");
        } else {
           print("Picked file has no path.");
           _lastPickedFilePath = null;
        }
      } else {
        print("User cancelled file picking.");
        _lastPickedFilePath = null;
      }
    } catch (e) {
      print("Error picking files: $e");
       _lastPickedFilePath = null;
    } finally {
      _isLocalLoading = false;
      notifyListeners();
    }
  }
   Future<File?> saveFileToAppDirectory(PlatformFile fileToSave) async {
     if (_appDocumentsPath == null) return null;
     try {
        final String destinationPath = p.join(_appDocumentsPath!, fileToSave.name);
        final File destinationFile = File(destinationPath);
        if (fileToSave.path != null) {
           await File(fileToSave.path!).copy(destinationPath);
           print("File saved to: $destinationPath");
           await listAppDirectoryFiles(); // Refresh file list
           return destinationFile;
        }
     } catch(e) {
        print("Error saving file: $e");
     }
     return null;
  }

  // --- Other connection placeholders (Keep Existing) ---
  bool get isDropboxConnected => false; // Placeholder
  Future<void> connectDropbox() async { /* ... */ }
  Future<void> disconnectDropbox() async { /* ... */ }

} // End of SpeechService