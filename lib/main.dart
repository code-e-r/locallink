// lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import for Google Fonts

// Import your separate screen files
import 'package:locallinks/screens/onboarding_screen.dart';
import 'package:locallinks/screens/locallink.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Link',
      // Define a global theme for the app, including the font
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Apply Inter font as default to the whole app, except where overridden
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const OnBoardingWrapper(), // Start with the onboarding wrapper
    );
  }
}

/// A wrapper widget to manage the display of the OnBoardingScreen
/// and transition to the main TravelBuddyApp.
class OnBoardingWrapper extends StatefulWidget {
  const OnBoardingWrapper({super.key});

  @override
  State<OnBoardingWrapper> createState() => _OnBoardingWrapperState();
}

class _OnBoardingWrapperState extends State<OnBoardingWrapper> {
  bool _showOnboarding = true; // State to control if onboarding is shown

  /// Callback function to be called when onboarding is completed.
  /// Sets the state to hide the onboarding screen and show the main app.
  void _completeOnboarding() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Conditionally render the OnBoardingScreen or the main TravelBuddyApp
    if (_showOnboarding) {
      return OnBoardingScreen(onComplete: _completeOnboarding);
    } else {
      return const TravelBuddyApp();
    }
  }
}
