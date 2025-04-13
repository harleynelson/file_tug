// ./lib/main.dart (Entire File)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/speech_service.dart';    // Adjust path if needed
import 'services/connection_service.dart'; // Adjust path if needed
import 'screens/home_screen.dart';      // Adjust path if needed

void main() {
  // Ensure Flutter bindings are initialized for async operations in main if needed
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use MultiProvider to provide multiple services
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpeechService()),
        ChangeNotifierProvider(create: (_) => ConnectionService()), // Add ConnectionService
      ],
      child: MaterialApp(
        title: 'Realtor Assistant',
        theme: ThemeData(
          primarySwatch: Colors.blue, // Or your preferred theme color
          visualDensity: VisualDensity.adaptivePlatformDensity,
           // Optional: Define consistent color scheme
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
             secondary: Colors.amber, // Example secondary color
          ),
        ),
        home: const HomeScreen(), // Start with the HomeScreen
      ),
    );
  }
}