// ./lib/screens/connections_screen.dart (Complete Methods)

import 'dart:io'; // Required for FileSystemEntity type

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_service.dart'; // Adjust path if needed
import 'package:path/path.dart' as p; // Import path package

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

  // Helper for section headers (Not modified, but included for completeness)
  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  // Helper for connection list tiles (Not modified, but included for completeness)
  Widget _buildConnectionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isConnected,
    required bool isLoading,
    String? connectedDetails,
    required VoidCallback onConnect,
    required VoidCallback onDisconnect,
  }) {
    return ListTile(
      leading: Icon(icon, size: 30.0, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        isConnected
            ? (connectedDetails ?? 'Connected')
            : 'Not Connected',
        style: TextStyle(
            color: isConnected ? Colors.green.shade700 : Colors.grey.shade600),
      ),
      trailing: isLoading
          ? const SizedBox( // Show spinner while loading
              width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.0))
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.redAccent : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: isConnected ? onDisconnect : onConnect,
              child: Text(isConnected ? 'Disconnect' : 'Connect'),
            ),
    );
  }

  // build method (Modified significantly)
  @override
  Widget build(BuildContext context) {
    // Use Consumer to react to changes in ConnectionService
    return Consumer<ConnectionService>(
      builder: (context, connectionService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Connections'),
          ),
          body: ListView(
            children: [
              // --- LOCAL STORAGE SECTION ---
              _buildSectionHeader('Local Storage', context),
              ListTile(
                leading: Icon(Icons.folder_open_outlined, size: 30.0, color: Theme.of(context).colorScheme.primary),
                title: const Text("App Documents Directory", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  connectionService.appDocumentsPath ?? "Loading path...",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  overflow: TextOverflow.ellipsis, // Prevent long paths overflowing
                ),
                // Optional: Add trailing button if desired
                // trailing: Icon(Icons.info_outline),
              ),
              Padding( // Add buttons for local actions
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Wrap( // Use Wrap for flexible button layout
                   spacing: 8.0, // Horizontal space between buttons
                   runSpacing: 4.0, // Vertical space if buttons wrap
                   children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.list_alt_outlined, size: 18),
                        label: Text('List App Files (${connectionService.appDirectoryFiles.length})'),
                        onPressed: connectionService.isLocalLoading || connectionService.appDocumentsPath == null
                           ? null // Disable if loading or path unavailable
                           : () async {
                               await connectionService.listAppDirectoryFiles();
                               // Show results (e.g., in a dialog or navigate to a new screen)
                               // For now, just show a SnackBar
                               if (context.mounted) { // Check if widget is still in tree
                                  ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text('Found ${connectionService.appDirectoryFiles.length} items.'))
                                  );
                                  // Optional: Show Dialog with file names
                                  _showAppFilesDialog(context, connectionService.appDirectoryFiles);
                               }
                           },
                        style: ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 13)),
                      ),
                       ElevatedButton.icon(
                        icon: const Icon(Icons.file_open_outlined, size: 18),
                        label: const Text('Pick File from Device'),
                        onPressed: connectionService.isLocalLoading
                           ? null // Disable if loading
                           : () async {
                              await connectionService.pickLocalFiles();
                              if(context.mounted && connectionService.lastPickedFilePath != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Picked: ${p.basename(connectionService.lastPickedFilePath!)}'))
                                );
                              }
                           },
                         style: ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 13)),
                       ),
                   ],
                ),
              ),
              if(connectionService.lastPickedFilePath != null) // Show last picked file
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text("Last picked: ${p.basename(connectionService.lastPickedFilePath!)}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ),


              // --- CLOUD STORAGE SECTION ---
              _buildSectionHeader('Cloud Storage', context), // Renamed header slightly
              _buildConnectionTile(
                context: context,
                icon: Icons.cloud_upload_outlined,
                title: 'Google Drive',
                isConnected: connectionService.isGoogleSignedIn,
                isLoading: connectionService.isGoogleLoading,
                connectedDetails: connectionService.googleCurrentUser?.email,
                onConnect: connectionService.signInGoogle,
                onDisconnect: connectionService.signOutGoogle,
              ),
              _buildConnectionTile( // Placeholder for Dropbox
                context: context,
                icon: Icons.folder_copy_outlined,
                title: 'Dropbox',
                isConnected: connectionService.isDropboxConnected, // Use placeholder state
                isLoading: false, // Placeholder
                onConnect: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Dropbox connection not implemented yet.'))
                   );
                },
                onDisconnect: () {},
              ),

              _buildSectionHeader('Calendars', context),
              // ... (Existing placeholders) ...
              ListTile( // Placeholder tile
                 leading: const Icon(Icons.calendar_month_outlined),
                 title: const Text('Google Calendar'),
                 subtitle: const Text('Not Implemented'),
                 trailing: ElevatedButton(onPressed: null, child: Text('Connect')),
              ),

               _buildSectionHeader('Emails', context),
              // ... (Existing placeholders) ...
               ListTile( // Placeholder tile
                 leading: const Icon(Icons.mail_outline),
                 title: const Text('Gmail'),
                 subtitle: const Text('Not Implemented'),
                 trailing: ElevatedButton(onPressed: null, child: Text('Connect')),
              ),
               ListTile( // Placeholder tile
                 leading: const Icon(Icons.mail_outline),
                 title: const Text('Other Email (IMAP/SMTP)'),
                 subtitle: const Text('Not Implemented'),
                 trailing: ElevatedButton(onPressed: null, child: Text('Connect')),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Helper Dialog to Show App Files (Newly added) ---
  void _showAppFilesDialog(BuildContext context, List<FileSystemEntity> files) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Files in App Directory"),
          content: SizedBox( // Constrain size
            width: double.maxFinite,
            height: 300, // Adjust as needed
            child: files.isEmpty
                ? const Center(child: Text("No files found."))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (BuildContext context, int index) {
                      final file = files[index];
                      bool isDir = file is Directory;
                      return ListTile(
                        leading: Icon(isDir ? Icons.folder_outlined : Icons.insert_drive_file_outlined),
                        title: Text(p.basename(file.path)), // Show only file/dir name
                        dense: true,
                      );
                    },
                  ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

} // End of ConnectionsScreen StatelessWidget