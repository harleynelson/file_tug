// ./lib/services/connection_service.dart (Entire File - Significant Additions)
import 'dart:io'; // Import Dart IO for File and Directory operations

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:path_provider/path_provider.dart'; // Import path_provider
import 'package:path/path.dart' as p; // Import path package with prefix 'p'

class ConnectionService with ChangeNotifier {
  // --- Google Sign In ---
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
      drive.DriveApi.driveFileScope,
    ],
  );
  GoogleSignInAccount? _currentUser;
  bool _isGoogleLoading = false;

  // --- Local Storage ---
  String? _appDocumentsPath; // Path to the app's private documents directory
  List<FileSystemEntity> _appDirectoryFiles = []; // List of files in the app dir
  bool _isLocalLoading = false;
  String? _lastPickedFilePath; // Path of the last file selected via file picker

  // --- Getters ---
  // Google
  GoogleSignInAccount? get googleCurrentUser => _currentUser;
  bool get isGoogleSignedIn => _currentUser != null;
  bool get isGoogleLoading => _isGoogleLoading;
  // Local
  String? get appDocumentsPath => _appDocumentsPath;
  List<FileSystemEntity> get appDirectoryFiles => _appDirectoryFiles;
  bool get isLocalLoading => _isLocalLoading;
  String? get lastPickedFilePath => _lastPickedFilePath;
  bool get isLocalStorageAvailable => _appDocumentsPath != null; // Local is always 'available' if path found


  ConnectionService() {
    _initialize();
  }

  // --- Initialization ---
  Future<void> _initialize() async {
    // Google Sign In Listener
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
      _isGoogleLoading = false;
      print("Google User Changed: ${_currentUser?.email}");
      notifyListeners();
    });
    _googleSignIn.signInSilently(); // Check silent sign in

    // Local Storage Initialization
    await _loadAppDirectoryPath(); // Load local path on startup
    // Optionally list files on startup (might be slow if many files)
    // if (_appDocumentsPath != null) {
    //   await listAppDirectoryFiles();
    // }
     notifyListeners(); // Notify after path is loaded
  }

  // --- Google Methods ---
  Future<void> signInGoogle() async {
    if (_isGoogleLoading) return;
    _isGoogleLoading = true;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _isGoogleLoading = false;
        notifyListeners();
      }
      print("Sign in attempt completed.");
    } catch (error) {
      print('Error signing in with Google: $error');
      _isGoogleLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOutGoogle() async {
    if (_isGoogleLoading) return;
    _isGoogleLoading = true;
    notifyListeners();
    try {
      await _googleSignIn.disconnect();
      print("Sign out attempt completed.");
    } catch (error) {
      print('Error signing out from Google: $error');
    }
    _isGoogleLoading = false;
     notifyListeners();
  }

  // --- Local Storage Methods ---
  Future<void> _loadAppDirectoryPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
      print("App Documents Path: $_appDocumentsPath");
    } catch (e) {
      print("Error getting app documents directory: $e");
      _appDocumentsPath = null; // Ensure it's null on error
    }
    // No need to notify here, _initialize will notify
  }

  /// Lists files directly within the app's documents directory.
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

  /// Allows user to pick one or more files using the native file picker.
  Future<void> pickLocalFiles({bool allowMultiple = false}) async {
    if (_isLocalLoading) return;
    _isLocalLoading = true;
    _lastPickedFilePath = null; // Clear previous pick
    notifyListeners();

    try {
      // You can customize type, allowedExtensions etc.
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Or FileType.custom, FileType.media, etc.
        allowMultiple: allowMultiple,
        // allowedExtensions: ['pdf', 'doc', 'jpg'], // Example filter
      );

      if (result != null) {
        if (allowMultiple) {
          // Handle multiple files - maybe store List<String> paths
          print("Picked ${result.files.length} files");
          // For simplicity now, just store the first path if multiple picked
          _lastPickedFilePath = result.files.first.path;
        } else if (result.files.single.path != null) {
          // Handle single file
           _lastPickedFilePath = result.files.single.path!;
           print("Picked file: $_lastPickedFilePath");
        } else {
           print("Picked file has no path.");
           _lastPickedFilePath = null;
        }
      } else {
        // User canceled the picker
        print("User cancelled file picking.");
        _lastPickedFilePath = null;
      }
    } catch (e) {
      // Handle exceptions (e.g., permission errors, platform issues)
      print("Error picking files: $e");
       _lastPickedFilePath = null;
    } finally {
      _isLocalLoading = false;
      notifyListeners();
    }
  }

  // --- Placeholder for saving files to app directory (Example) ---
  Future<File?> saveFileToAppDirectory(PlatformFile fileToSave) async {
     if (_appDocumentsPath == null) return null;
     try {
        final String destinationPath = p.join(_appDocumentsPath!, fileToSave.name);
        final File destinationFile = File(destinationPath);
        // Assuming fileToSave.path has the temporary path from file_picker
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


  // --- Placeholder for other services ---
  // Add similar properties and methods for Dropbox etc. later
  bool get isDropboxConnected => false; // Placeholder
  Future<void> connectDropbox() async { /* ... */ }
  Future<void> disconnectDropbox() async { /* ... */ }
}