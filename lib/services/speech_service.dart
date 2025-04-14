// ./lib/services/speech_service.dart (Entire File - Dialogflow Integration)

import 'dart:async';
// import 'dart:io'; // No longer needed directly here
import 'dart:convert'; // Needed for Dialogflow response handling

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle; // Needed to load asset
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:dialog_flowtter/dialog_flowtter.dart';
// command_parser_service.dart is removed
import '../models/parsed_command.dart';

class SpeechService with ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  DialogFlowtter? _dialogFlowtter; // Dialogflow client instance

  // State Variables
  bool _isSpeechEnabled = false;
  bool _isListening = false;
  String _lastWords = "";
  String _currentError = "";
  ParsedCommand? _parsedCommand;

  // State variables for final result handling from speech_to_text
  String? _finalRecognizedText;
  bool _finalResultReceived = false;
  bool _parsingAttempted = false;

  // Timer and Manual Stop Control (Keep if desired)
  Timer? _listenTimer;
  bool _manualStopRequested = false;
  final Duration _maxListenDuration = const Duration(seconds: 30);

  // --- Getters ---
  bool get isListening => _isListening;
  bool get isSpeechEnabled => _isSpeechEnabled;
  String get recognizedWords => _lastWords;
  String get lastError => _currentError;
  ParsedCommand? get parsedCommand => _parsedCommand;

  // --- Initialization ---
  Future<void> initialize() async {
    _resetState();
    try {
      // Initialize Dialogflow first
      await _initializeDialogflow();

      // Initialize SpeechToText
      _isSpeechEnabled = await _speechToText.initialize(
        onError: _statusErrorListener,
        onStatus: _statusListener,
      );

      // Check if both services initialized correctly
      if (!_isSpeechEnabled) {
        _currentError = "Speech recognition not available.";
      } else if (_dialogFlowtter == null) {
        _currentError = "Dialogflow NLU service could not be initialized.";
        _isSpeechEnabled = false; // Can't process commands without NLU
      } else {
        _currentError = ""; // Both initialized successfully
      }
    } catch (e) {
      _isSpeechEnabled = false;
      _currentError = "Error initializing services: ${e.toString()}";
      print("Error initializing services: $e");
    }
    notifyListeners();
  }

  // Helper to initialize Dialogflow
  Future<void> _initializeDialogflow() async {
    try {
      // Ensure path matches where you placed the JSON key in assets
      final String credentialsJson = await rootBundle.loadString('assets/dialogflow_credentials.json');
      final credentials = DialogAuthCredentials.fromJson(jsonDecode(credentialsJson));
      _dialogFlowtter = DialogFlowtter(credentials: credentials);
      print("Dialogflow initialized successfully.");
    } catch (e) {
      print("!!! Error initializing Dialogflow: $e");
      _dialogFlowtter = null;
    }
  }

  // Helper to reset session state
  void _resetState() {
     _lastWords = "";
     _currentError = "";
     _parsedCommand = null;
     _finalRecognizedText = null;
     _finalResultReceived = false;
     _parsingAttempted = false;
     _manualStopRequested = false;
     _cancelTimer();
     // _isListening state managed by listeners/controls
  }

  // Helper to cancel the timer
  void _cancelTimer() {
    _listenTimer?.cancel();
    _listenTimer = null;
  }

  // --- Listening Control ---
  void startListening() {
    if (!_isSpeechEnabled || _isListening) return;

    _resetState();
    _isListening = true; // Assume listening starts immediately for UI feedback
    _manualStopRequested = false;
    notifyListeners(); // Update UI immediately

    print("Starting speech listening (max ${_maxListenDuration.inSeconds} seconds or manual stop)...");

    // Start app-level timer (optional, provides backup timeout)
    _cancelTimer();
    _listenTimer = Timer(_maxListenDuration, _onTimerExpired);

    _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: _maxListenDuration,
      pauseFor: const Duration(seconds: 10), // Use a reasonable pause duration
      localeId: "en_US",
      listenMode: ListenMode.dictation, // Use dictation mode
      partialResults: true,
      cancelOnError: false, // Handle errors via listener
    );
  }

  // Called when our manual 30-second timer expires
  void _onTimerExpired() {
    print("Listen timer expired after ${_maxListenDuration.inSeconds} seconds.");
    if (_isListening) {
        print("Timer causing stop. Stopping listening.");
        _speechToText.stop(); // Ask plugin to stop
        // Let status listener handle state change
    }
     _listenTimer = null;
  }

  void stopListening() {
    if (!_isListening) {
      print("StopListening called but already not listening.");
      return;
    }
    print("StopListening called manually.");
    _manualStopRequested = true; // Set flag
    _cancelTimer(); // Cancel the timer

    _speechToText.stop(); // Ask plugin to stop

    // --- Directly handle state change and parsing on manual stop ---
    bool wasListening = _isListening;
    _isListening = false;
    print("--> State updated: No Longer Listening (Manual stop)");

    if (wasListening) {
        _tryFinalParse(); // Trigger parse immediately
        // No need to notify here, _tryFinalParse will notify at the end
    }
    // --------------------------------------------------------------
  }

  // --- SpeechToText Callbacks ---

  /// Called when speech recognition result is available
  void _onSpeechResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    // Minimal logging here to avoid spamming console during active speech
    // print("Speech Result: '$_lastWords' (Final: ${result.finalResult})");

    if (result.finalResult) {
      print("--> FinalResult flag received from STT. Storing final text: '$_lastWords'");
      _finalRecognizedText = result.recognizedWords;
      _finalResultReceived = true;
    }

    // Only notify if still listening to update live words in UI
    if(_isListening) {
        notifyListeners();
    }
  }

  /// Called when the STT listening status changes
  void _statusListener(String status) {
    print('STT status changed: $status - Current _isListening state: $_isListening');
    bool wasListening = _isListening;

    if (status == SpeechToText.listeningStatus) {
        if (!wasListening) {
           _isListening = true;
           _currentError = "";
           print("--> State confirmed: Now Listening");
           notifyListeners();
        } else {
           print("--> State already listening, STT status confirms.");
        }
    } else if (status == SpeechToText.notListeningStatus || status == SpeechToText.doneStatus) {
        if (wasListening) {
            bool timerExpired = _listenTimer == null && !_manualStopRequested;
            if (timerExpired) {
                 _isListening = false;
                 print("--> State updated: No Longer Listening (Reason: Timer) Status: $status");
                 _tryFinalParse(); // Parse when timer expires
                 // No need to notify here, _tryFinalParse will notify at the end
            } else if (_manualStopRequested) {
                 print("--> STT Status '$status' received after manual stop. State already updated.");
                 // Ensure state is false if somehow missed in stopListening
                 if (_isListening) {
                    _isListening = false;
                    notifyListeners(); // Notify just in case state wasn't updated
                 }
            } else {
                print("--> Ignoring premature STT '$status' status change, waiting for manual stop or timer.");
            }
        } else {
             print("--> STT Status '$status' received but state was already not listening.");
        }
    } else {
        print("--> Unhandled STT status: $status");
    }
  }

  /// Called on STT recognition errors
  void _statusErrorListener(dynamic errorNotification) {
      print('!!! STT Error Received: ${errorNotification.errorMsg} - Listening state was: $_isListening');
      _currentError = "STT Error: ${errorNotification.errorMsg}";

      if (_isListening) { // Only act if we thought we were listening
          _isListening = false; // Stop listening on error
          _cancelTimer(); // Stop timer on error
          print("--> State updated: No Longer Listening due to STT error.");
          _tryFinalParse(parseOnError: true); // Attempt parse on error
          // No need to notify here, _tryFinalParse will notify at the end
      } else {
         print("--> STT Error received but state was already not listening.");
         // Update UI to show the error even if not listening
         notifyListeners();
      }
  }

  // --- Dialogflow Parsing Logic ---
  void _tryFinalParse({bool parseOnError = false}) async { // Make async
     if (_parsingAttempted) {
        print("--> Final parse already attempted for this session.");
        return;
     }
     if (_dialogFlowtter == null) {
         print("--> Cannot parse: Dialogflow not initialized.");
         _currentError = "NLU service unavailable.";
         _parsedCommand = ParsedCommand.failure(_lastWords ?? "");
         _parsingAttempted = true;
         notifyListeners();
         return;
     }

     _parsingAttempted = true;
     _manualStopRequested = false;

     String? textToParse;
     if (_finalResultReceived && _finalRecognizedText != null && _finalRecognizedText!.isNotEmpty) {
        textToParse = _finalRecognizedText;
     } else if (_lastWords.isNotEmpty) {
        textToParse = _lastWords;
     }

     if (textToParse == null || textToParse.isEmpty) {
        print("No text available to parse.");
        _parsedCommand = ParsedCommand.failure("");
        return;
     }

     print("Sending to Dialogflow: '$textToParse'");
     _parsedCommand = null;
     _currentError = "";
     notifyListeners();

     try {
         DetectIntentResponse response = await _dialogFlowtter!.detectIntent(
            queryInput: QueryInput(text: TextInput(text: textToParse)),
         );

         QueryResult? queryResult = response.queryResult;
         String intentName = queryResult?.intent?.displayName ?? "unknown";
         Map<String, dynamic>? parameters = queryResult?.parameters;

         print("Dialogflow Intent: $intentName");
         print("Dialogflow Parameters: ${parameters ?? 'None'}");

         // !!! IMPORTANT: Ensure 'SendCommand' matches the Intent name in Dialogflow !!!
         if (intentName == 'SendCommand' && parameters != null) {
             // --- Parameter Extraction with Multi-Contact Handling ---
             String? file = parameters['fileName']?.toString();

             String? contact;
             dynamic contactParam = parameters['contactName'];
             if (contactParam is List && contactParam.isNotEmpty) {
                 // Extract names from the list, filter nulls/empty, join with ", "
                 contact = contactParam
                     .map((item) {
                         if (item is Map) {
                             return item['name']?.toString(); // Extract name if it's a map
                         } else if (item is String) {
                             return item; // Handle if it's just a list of strings
                         }
                         return null; // Ignore other types
                     })
                     .where((name) => name != null && name.isNotEmpty) // Filter out nulls/empty
                     .join(", "); // Join valid names
             } else if (contactParam is String && contactParam.isNotEmpty) {
                 // Handle case where it's just a single string
                 contact = contactParam;
             }
             // If extraction resulted in an empty string, set contact to null
             if (contact != null && contact.isEmpty) {
                contact = null;
             }

             String? message = parameters['messageBody']?.toString();
             // --- End Parameter Extraction ---

             // Basic validation: require file OR contact for success
             if ((file != null && file.isNotEmpty) || (contact != null && contact.isNotEmpty)) {
                 _parsedCommand = ParsedCommand(
                     originalText: textToParse,
                     fileName: file?.isEmpty ?? true ? null : file,
                     contactName: contact, // Use the potentially joined contact string
                     messageBody: message?.isEmpty ?? true ? null : message,
                     parseSuccess: true,
                 );
                  print("Parser result (from Dialogflow): Success=true, File='${_parsedCommand?.fileName}', Contact='${_parsedCommand?.contactName}', Message='${_parsedCommand?.messageBody}'");
             } else {
                 print("Dialogflow parsed 'SendCommand', but missing required file/contact parameters.");
                 _parsedCommand = ParsedCommand.failure(textToParse);
                 _currentError = "Missing file or contact name in command.";
             }
         }
         // ... (rest of the error handling as before) ...
         else if (queryResult != null) {
              print("Dialogflow intent '$intentName' not recognized or parameters missing.");
             _parsedCommand = ParsedCommand.failure(textToParse);
             _currentError = "Command not recognized by NLU.";
         }
         else {
              print("Dialogflow returned an unexpected or empty response.");
              _parsedCommand = ParsedCommand.failure(textToParse);
              _currentError = "NLU service returned empty response.";
         }

     } catch (e, s) {
         print("!!! Error calling Dialogflow or processing response: $e");
         print("!!! StackTrace: $s");
         _currentError = "Error processing command via NLU.";
         _parsedCommand = ParsedCommand.failure(textToParse);
     } finally {
         notifyListeners();
     }
  }

  /// Processes text input directly using Dialogflow.
  Future<void> processTextCommand(String textToParse) async { // Keep async if needed elsewhere, but await removed below
    // Reset parsing state for this new command
    _parsingAttempted = false;
    _parsedCommand = null;
    _currentError = "";
    // Reset STT specific fields as well for consistency
    _lastWords = textToParse; // Store the input text here
    _finalRecognizedText = textToParse;
    _finalResultReceived = true; // Treat text input as final

    print("Processing text command: '$textToParse'");

    // Call the existing parsing logic, but DON'T await it here.
    // It will run asynchronously and notify listeners when done.
    _tryFinalParse(); // REMOVED await

    // No need to notify here, _tryFinalParse handles it.
  }


  // --- Update Methods for Parsed Command (No Change Needed) ---
  // These allow the UI (HomeScreen) to update the parsed results if the user edits them.
  void updateParsedFileName(String newFileName) {
      if (_parsedCommand == null) return;
    _parsedCommand = ParsedCommand(
      originalText: _parsedCommand!.originalText,
      fileName: newFileName,
      contactName: _parsedCommand!.contactName,
      messageBody: _parsedCommand!.messageBody,
      parseSuccess: _parsedCommand!.parseSuccess, // Keep success status
    );
    print("SpeechService: Updated file name to '$newFileName'");
    notifyListeners();
   }
  void updateParsedContactName(String newContactName) {
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
  void updateParsedMessageBody(String newMessageBody) {
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
  void setParseSuccess(bool success) {
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

} // End of SpeechService class