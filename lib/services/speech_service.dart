// ./lib/services/speech_service.dart (Entire File - Updated Parsing & Update Logic)

import 'dart:async';

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:dialog_flowtter/dialog_flowtter.dart';
// Updated model import
import '../models/parsed_command.dart';
// TODO: Import ConnectionService and ContactService when needed

class SpeechService with ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  DialogFlowtter? _dialogFlowtter;
  // Inject services if needed:
  // final ConnectionService _connectionService;
  // final ContactService _contactService;
  // SpeechService(this._connectionService, this._contactService);

  bool _isSpeechEnabled = false;
  bool _isListening = false;
  String _lastWords = "";
  String _currentError = "";
  ParsedCommand? _parsedCommand;
  String? _finalRecognizedText;
  bool _finalResultReceived = false;
  bool _parsingAttempted = false;
  bool _associationAttempted = false;
  Timer? _listenTimer;
  bool _manualStopRequested = false;
  final Duration _maxListenDuration = const Duration(seconds: 30);

  // --- Getters ---
  bool get isListening => _isListening;
  bool get isSpeechEnabled => _isSpeechEnabled;
  String get recognizedWords => _lastWords;
  String get lastError => _currentError;
  ParsedCommand? get parsedCommand => _parsedCommand;

  // --- Initialization (mostly unchanged) ---
  Future<void> initialize() async {
    _resetState();
    try {
      await _initializeDialogflow();
      _isSpeechEnabled = await _speechToText.initialize(
        onError: _statusErrorListener,
        onStatus: _statusListener,
      );
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
  void _resetState() {
      _lastWords = "";
     _currentError = "";
     _parsedCommand = null;
     _finalRecognizedText = null;
     _finalResultReceived = false;
     _parsingAttempted = false;
     _associationAttempted = false; // Reset association flag
     _manualStopRequested = false;
     _cancelTimer();
  }
  void _cancelTimer() {
      _listenTimer?.cancel();
      _listenTimer = null;
  }

  // --- Listening Control (unchanged) ---
  void startListening() {
    if (!_isSpeechEnabled || _isListening) return;

    _resetState(); // Full reset before starting
    _isListening = true;
    _manualStopRequested = false;
    notifyListeners();

    print("Starting speech listening (max ${_maxListenDuration.inSeconds} seconds or manual stop)...");

    _cancelTimer();
    _listenTimer = Timer(_maxListenDuration, _onTimerExpired);

    _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: _maxListenDuration,
      pauseFor: const Duration(seconds: 10),
      localeId: "en_US",
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
    );
  }
  void _onTimerExpired() {
    print("Listen timer expired after ${_maxListenDuration.inSeconds} seconds.");
    if (_isListening) {
        print("Timer causing stop. Stopping listening.");
        _speechToText.stop();
        // Let status listener handle state change and parsing/association
    }
     _listenTimer = null;
  }
  void stopListening() {
     if (!_isListening) {
      print("StopListening called but already not listening.");
      return;
    }
    print("StopListening called manually.");
    _manualStopRequested = true;
    _cancelTimer();

    _speechToText.stop();

    // --- Directly handle state change and trigger parsing/association on manual stop ---
    bool wasListening = _isListening;
    _isListening = false;
    print("--> State updated: No Longer Listening (Manual stop)");

    if (wasListening) {
        _tryFinalParseAndAssociate(); // Trigger parse & association immediately
    }
    // -----------------------------------------------------------------------------------
  }

  // --- SpeechToText Callbacks (unchanged) ---
  void _onSpeechResult(SpeechRecognitionResult result) {
     _lastWords = result.recognizedWords;

    if (result.finalResult) {
      print("--> FinalResult flag received from STT. Storing final text: '$_lastWords'");
      _finalRecognizedText = result.recognizedWords;
      _finalResultReceived = true;
    }

    if(_isListening) {
        notifyListeners();
    }
  }
  void _statusListener(String status) {
     print('STT status changed: $status - Current _isListening state: $_isListening');
    bool wasListening = _isListening;

    if (status == SpeechToText.listeningStatus) {
        if (!wasListening) {
           _isListening = true;
           _currentError = "";
           print("--> State confirmed: Now Listening");
           notifyListeners();
        }
    } else if (status == SpeechToText.notListeningStatus || status == SpeechToText.doneStatus) {
        if (wasListening && !_manualStopRequested) { // Only trigger if not manually stopped
            _isListening = false;
            print("--> State updated: No Longer Listening (Reason: STT Status '$status')");
            _tryFinalParseAndAssociate(); // Trigger parse & association when STT stops naturally
        } else if (wasListening && _manualStopRequested) {
            print("--> STT Status '$status' received after manual stop. State already updated.");
            // Ensure state is false if somehow missed in stopListening
            if (_isListening) {
                _isListening = false;
                notifyListeners();
            }
        } else {
             print("--> STT Status '$status' received but state was already not listening or manual stop occurred.");
        }
    }
  }
  void _statusErrorListener(dynamic errorNotification) {
      print('!!! STT Error Received: ${errorNotification.errorMsg} - Listening state was: $_isListening');
      _currentError = "STT Error: ${errorNotification.errorMsg}";

      if (_isListening) {
          _isListening = false;
          _cancelTimer();
          print("--> State updated: No Longer Listening due to STT error.");
          _tryFinalParseAndAssociate(parseOnError: true); // Attempt parse/association on error
      } else {
         notifyListeners(); // Update UI to show the error
      }
  }


  // --- Combined Parsing and Association Logic (Updated for new model fields) ---
  void _tryFinalParseAndAssociate({bool parseOnError = false}) async {
     if (_parsingAttempted) {
        print("--> Final parse/association already attempted for this session.");
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
     _manualStopRequested = false; // Reset flag

     String? textToParse = _finalRecognizedText ?? (_lastWords.isNotEmpty ? _lastWords : null);
     if (textToParse == null || textToParse.isEmpty) {
        print("No text available to parse.");
        _parsedCommand = ParsedCommand.failure("");
        notifyListeners(); // Notify UI about the failure
        return;
     }

     print("Sending to Dialogflow: '$textToParse'");
     // Set initial state before async call
     _parsedCommand = null;
     _currentError = "";
     _associationAttempted = false; // Reset for this attempt
     notifyListeners(); // Show 'processing' or clear previous result

     ParsedCommand? initialParsedResult;
     try {
         DetectIntentResponse response = await _dialogFlowtter!.detectIntent(queryInput: QueryInput(text: TextInput(text: textToParse)));
         QueryResult? queryResult = response.queryResult;
         String intentName = queryResult?.intent?.displayName ?? "unknown";
         Map<String, dynamic>? parameters = queryResult?.parameters;
         print("Dialogflow Intent: $intentName, Parameters: ${parameters ?? 'None'}");

         if (intentName == 'SendCommand' && parameters != null) {
             // --- Extract parameters (same logic) ---
             String? fileParam = parameters['fileName']?.toString();
             String? contactParamValue; // Extracted contact name string
             dynamic contactParam = parameters['contactName'];
             if (contactParam is List && contactParam.isNotEmpty) {
                contactParamValue = contactParam
                     .map((item) => (item is Map ? item['name']?.toString() : (item is String ? item : null)))
                     .where((name) => name != null && name.isNotEmpty)
                     .join(", ");
              }
             else if (contactParam is String && contactParam.isNotEmpty) { contactParamValue = contactParam; }
             if (contactParamValue != null && contactParamValue.isEmpty) contactParamValue = null;
             String? messageParam = parameters['messageBody']?.toString();

             // --- Populate ParsedCommand (using original and current fields) ---
             if ((fileParam != null && fileParam.isNotEmpty) || (contactParamValue != null && contactParamValue.isNotEmpty)) {
                 initialParsedResult = ParsedCommand(
                     originalText: textToParse,
                     // Populate original fields
                     originalFileName: fileParam?.isEmpty ?? true ? null : fileParam,
                     originalContactName: contactParamValue,
                     originalMessageBody: messageParam?.isEmpty ?? true ? null : messageParam,
                     // Populate current fields (initially same as original)
                     fileName: fileParam?.isEmpty ?? true ? null : fileParam,
                     contactName: contactParamValue,
                     messageBody: messageParam?.isEmpty ?? true ? null : messageParam,
                     // Set status
                     parseSuccess: true,
                     fileStatus: (fileParam != null && fileParam.isNotEmpty) ? AssociationStatus.pending : AssociationStatus.notFound,
                     contactStatus: (contactParamValue != null && contactParamValue.isNotEmpty) ? AssociationStatus.pending : AssociationStatus.notFound,
                 );
                 print("Dialogflow Parse SUCCESS (Initial): File='${initialParsedResult.fileName}', Contact='${initialParsedResult.contactName}' (Status: Pending)");
             } else {
                 print("Dialogflow Parse FAILURE: Missing required file/contact parameters.");
                 _parsedCommand = ParsedCommand.failure(textToParse);
                 _currentError = "Missing file or contact name in command.";
              }
         } else {
             print("Dialogflow Parse FAILURE: Intent '$intentName' not recognized or parameters missing.");
             _parsedCommand = ParsedCommand.failure(textToParse);
             _currentError = "Command not recognized by NLU.";
          }
     } catch (e, s) {
         print("!!! Error calling Dialogflow or processing response: $e");
         print("!!! StackTrace: $s");
         _currentError = "Error processing command via NLU.";
         _parsedCommand = ParsedCommand.failure(textToParse);
         // Don't proceed to association on Dialogflow error
         initialParsedResult = null;
      }

     // --- Trigger Association Phase (Unchanged logic, works on initialParsedResult) ---
     if (initialParsedResult != null) {
        _parsedCommand = initialParsedResult; notifyListeners(); // Show initial parse
        print("--- Starting Association Phase ---");
        _associationAttempted = true;
        await _performAssociation(_parsedCommand!); // Runs association logic
        print("--- Association Phase Complete ---");
     } else { notifyListeners(); } // Update UI if parsing failed
  }

  /// Placeholder method to perform file and contact association (Unchanged)
  Future<void> _performAssociation(ParsedCommand commandToUpdate) async {
      ParsedCommand workingCommand = commandToUpdate;
      bool changed = false;
      // --- Associate File (Simulated logic - unchanged) ---
      if (workingCommand.fileName != null && workingCommand.fileStatus == AssociationStatus.pending) {
         print("Associating File: '${workingCommand.fileName}'");
         // ** Placeholder ** - Replace with actual ConnectionService call
         await Future.delayed(const Duration(milliseconds: 500)); // Simulate
         final mockFilePath = "/path/to/mock/${workingCommand.fileName}.pdf";
         workingCommand = workingCommand.copyWith(fileStatus: AssociationStatus.foundSingle, resolvedFilePath: () => mockFilePath);
         print("File Association Result: FoundSingle -> $mockFilePath");
         changed = true;
      }
      // --- Associate Contact (Simulated logic - unchanged) ---
       if (workingCommand.contactName != null && workingCommand.contactStatus == AssociationStatus.pending) {
           print("Associating Contact: '${workingCommand.contactName}'");
            // ** Placeholder ** - Replace with actual ContactService/flutter_contacts call
           await Future.delayed(const Duration(milliseconds: 600)); // Simulate
           workingCommand = workingCommand.copyWith(contactStatus: AssociationStatus.foundMultiple, resolvedContactId: () => null);
           print("Contact Association Result: FoundMultiple");
           changed = true;
       }
      // --- Update State ---
      if (changed) { _parsedCommand = workingCommand; notifyListeners(); }
      else { print("No association changes detected."); }
  }

  /// Processes text input directly (Unchanged)
  Future<void> processTextCommand(String textToParse) async {
    _parsingAttempted = false; _associationAttempted = false; _parsedCommand = null;
    _currentError = ""; _lastWords = textToParse; _finalRecognizedText = textToParse; _finalResultReceived = true;
    print("Processing text command: '$textToParse'");
    _tryFinalParseAndAssociate(); // Run the full logic
  }


  // --- Update Methods for Parsed Command (Updated to modify only CURRENT fields) ---

  /// Called when user manually selects a file using the file picker.
  void userSelectedFile(String filePath, String? displayedFileName) {
      if (_parsedCommand == null) return;
      print("SpeechService: User selected file '$filePath'. Updating CURRENT fileName.");
      _parsedCommand = _parsedCommand!.copyWith(
          // ** Only update the current fileName **
          fileName: displayedFileName != null ? () => displayedFileName : _parsedCommand!.fileName.asValueGetter,
          // Update status and resolved path
          fileStatus: AssociationStatus.userSelected,
          resolvedFilePath: () => filePath,
          // Ensure parseSuccess is true if we now have a required field
          parseSuccess: (_parsedCommand!.contactName != null || (displayedFileName != null && displayedFileName.isNotEmpty)) || _parsedCommand!.parseSuccess,
      );
      notifyListeners();
  }

  /// Called when user manually selects a contact.
  void userSelectedContact(String contactId, String displayedContactName) {
      if (_parsedCommand == null) return;
      print("SpeechService: User selected contact '$displayedContactName'. Updating CURRENT contactName.");
       _parsedCommand = _parsedCommand!.copyWith(
          // ** Only update the current contactName **
          contactName: () => displayedContactName,
          // Update status and resolved ID
          contactStatus: AssociationStatus.userSelected,
          resolvedContactId: () => contactId,
           // Ensure parseSuccess is true
          parseSuccess: (_parsedCommand!.fileName != null || displayedContactName.isNotEmpty) || _parsedCommand!.parseSuccess,
      );
      notifyListeners();
  }

  /// Called when user edits the message body via the UI.
  void userEditedMessageBody(String newMessageBody) {
      if (_parsedCommand == null) return;
       print("SpeechService: User edited message body. Updating CURRENT messageBody.");
      _parsedCommand = _parsedCommand!.copyWith(
        // ** Only update the current messageBody **
        messageBody: () => newMessageBody.isEmpty ? null : newMessageBody,
        // Ensure parseSuccess is true
        parseSuccess: (_parsedCommand!.fileName != null || _parsedCommand!.contactName != null) || _parsedCommand!.parseSuccess,
      );
      notifyListeners();
  }

  // --- Methods below handle editing the NAME itself (might need re-association) ---

  /// Called if user *edits the file name text* directly (less common)
  void userEditedFileName(String newFileName) {
      if (_parsedCommand == null) return;
      print("SpeechService: User edited file NAME to '$newFileName'. Resetting association.");
      _parsedCommand = _parsedCommand!.copyWith(
        // Update current name
        fileName: () => newFileName.isEmpty ? null : newFileName,
        // Reset status and resolved path - needs re-association
        fileStatus: AssociationStatus.pending,
        resolvedFilePath: () => null,
        // Keep originalFileName as is
      );
      // TODO: Trigger re-association for the file (e.g., call _performAssociation again)
      notifyListeners();
  }

   /// Called if user *edits the contact name text* directly (less common)
   void userEditedContactName(String newContactName) {
      if (_parsedCommand == null) return;
       print("SpeechService: User edited contact NAME to '$newContactName'. Resetting association.");
      _parsedCommand = _parsedCommand!.copyWith(
        // Update current name
        contactName: () => newContactName.isEmpty ? null : newContactName,
        // Reset status and resolved ID - needs re-association
        contactStatus: AssociationStatus.pending,
        resolvedContactId: () => null,
         // Keep originalContactName as is
      );
      // TODO: Trigger re-association for the contact
      notifyListeners();
  }

   // setParseSuccess might be less needed now, but kept for flexibility
   void setParseSuccess(bool success) {
      if (_parsedCommand == null) return;
     _parsedCommand = _parsedCommand!.copyWith(parseSuccess: success);
     print("SpeechService: Updated parse success to '$success'");
    notifyListeners();
   }

} // End of SpeechService class