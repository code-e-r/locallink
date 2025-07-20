// lib/screens/travel_buddy_app.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Removed Firebase imports for now as requested
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'dart:math';
// import 'package:travel_buddy_app/firebase_options.dart';


// Import your separate screen files
import 'package:locallinks/screens/embedded_map_screen.dart';
import 'package:locallinks/models/poi.dart';
// Removed import for public_places_map_screen.dart


class TravelBuddyApp extends StatefulWidget {
  const TravelBuddyApp({super.key});

  @override
  State<TravelBuddyApp> createState() => _TravelBuddyAppState();
}

class _TravelBuddyAppState extends State<TravelBuddyApp> {
  // Removed _currentPage as it's no longer used for navigation within this widget
  List<String> _aiSuggestions = [];
  bool _isLoading = false;
  String? _locationError;

  Position? _currentPosition;
  List<Poi> _localPois = [];

  // Removed Firebase-related state
  // String? _userId;
  // bool _hasAppliedForBuddy = false;
  // bool _isFirebaseInitialized = false;


  @override
  void initState() {
    super.initState();
    // Removed Firebase initialization
    _determinePosition();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    String errorMsg = '';

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      errorMsg = 'Location services are disabled. Please enable them in your device settings.';
      _showSnackBar(errorMsg);
      setState(() { _locationError = errorMsg; _isLoading = false; });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        errorMsg = 'Location permissions are denied. Please grant permission in app settings.';
        _showSnackBar(errorMsg);
        setState(() { _locationError = errorMsg; _isLoading = false; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      errorMsg = 'Location permissions are permanently denied, we cannot request permissions.';
      _showSnackBar(errorMsg);
      setState(() { _locationError = errorMsg; _isLoading = false; });
      return;
    }

    setState(() { _isLoading = true; _locationError = null; });
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _generateMockPois(position);
      });
      print('Current Location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
    } catch (e) {
      errorMsg = 'Failed to get current location: ${e.toString()}';
      _showSnackBar(errorMsg);
      setState(() { _locationError = errorMsg; _isLoading = false; });
      print('Error getting location: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// Generates mock POIs relative to the current position for demonstration.
  void _generateMockPois(Position currentPosition) {
    _localPois = [
      Poi(
        id: 'bus1',
        name: 'Main Bus Stop',
        type: 'bus_stop',
        position: LatLng(currentPosition.latitude + 0.005, currentPosition.longitude + 0.005),
        details: 'Buses to City Center, every 10 mins',
      ),
      Poi(
        id: 'bus2',
        name: 'Market Bus Stop',
        type: 'bus_stop',
        position: LatLng(currentPosition.latitude - 0.003, currentPosition.longitude + 0.007),
        details: 'Buses to Railway Station, every 15 mins',
      ),
      Poi(
        id: 'auto1',
        name: 'Hospital Auto Stand',
        type: 'auto_stand',
        position: LatLng(currentPosition.latitude + 0.002, currentPosition.longitude - 0.004),
        details: 'Always available',
      ),
      Poi(
        id: 'auto2',
        name: 'Mall Auto Stand',
        type: 'auto_stand',
        position: LatLng(currentPosition.latitude - 0.006, currentPosition.longitude - 0.008),
        details: 'Busy during evenings',
      ),
      Poi(
        id: 'print1',
        name: 'Quick Print Shop',
        type: 'printing_shop',
        position: LatLng(currentPosition.latitude + 0.004, currentPosition.longitude - 0.002),
        details: 'Open 9 AM - 6 PM',
      ),
    ];
  }

  // Function to show the Local Buddy service description and application dialog
  Future<void> _showLocalBuddyDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Local Buddy Service', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Local Buddy is a service offered to people with physical disabilities. '
                      'Our verified personnel provide companionship and assistance to help you reach specific places safely and comfortably.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                Text(
                  'Would you like to apply for this service?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Quit', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // FIX: Added const
              ),
              child: const Text('Apply'),
              onPressed: () {
                Navigator.of(context).pop(); // Close current dialog
                _showDisabilityInputForm(); // Show the next form
              },
            ),
          ],
        );
      },
    );
  }

  // Function to show the disability input form
  Future<void> _showDisabilityInputForm() async {
    TextEditingController disabilityController = TextEditingController();
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tell us about your disability', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: disabilityController,
            decoration: InputDecoration(
              hintText: 'e.g., "Wheelchair user", "Visually impaired"',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), // FIX: Added const
            ),
            maxLines: 3,
            minLines: 1,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // FIX: Added const
              ),
              child: const Text('Submit Application'),
              onPressed: () {
                // Simulate application submission without Firestore
                _simulateBuddyApplication(disabilityController.text);
                Navigator.of(context).pop(); // Close the form
              },
            ),
          ],
        );
      },
    );
  }

  // Function to simulate buddy application success (no Firestore interaction)
  void _simulateBuddyApplication(String disability) {
    if (disability.trim().isEmpty) {
      _showSnackBar('Please describe your disability to apply.');
      return;
    }
    _showSnackBar('Thank you for applying! We will review your application (simulated).');
    print('Simulated Buddy application submitted with disability: $disability');
  }


  @override
  Widget build(BuildContext context) { // FIX: This is the correct and only build method
    return Scaffold(
      appBar: AppBar(
        title: const Text('LocalLink', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.indigo.shade100],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    spreadRadius: 0,
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome to LocalLink!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your smart companion for new localities. Explore maps, plan trips, and get AI assistance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildActionButton(
                    text: _isLoading ? 'Getting Location...' : 'Open Interactive Map',
                    onPressed: _currentPosition == null || _isLoading ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmbeddedMapScreen(
                            initialPosition: _currentPosition,
                            pois: _localPois,
                            aiSuggestions: _aiSuggestions,
                            // Removed hasAppliedForBuddy as it's not used without Firebase
                          ),
                        ),
                      );
                    },
                    color: Colors.blue.shade600,
                    splashColor: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 16),
                  // Removed "Mark Places for All Users" button as it needs Firebase
                  _buildActionButton(
                    text: 'Local Buddy Service',
                    onPressed: _showLocalBuddyDialog,
                    color: Colors.purple.shade600,
                    textColor: Colors.white,
                    splashColor: Colors.purple.shade700,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper for building action buttons (reused from previous code)
  Widget _buildActionButton({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    Color color = Colors.blue,
    Color textColor = Colors.white,
    Color splashColor = Colors.blue,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        elevation: 5,
        shadowColor: color.withOpacity(0.3),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ).copyWith(
        overlayColor: MaterialStateProperty.all(splashColor),
      ),
      child: isLoading
          ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      )
          : Text(text),
    );
  }
}
