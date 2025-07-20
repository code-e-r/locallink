// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import for Google Fonts

/// The OnBoardingScreen as provided by the user, adapted for responsiveness and
/// with a "Continue" button to proceed to the main app.
class OnBoardingScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const OnBoardingScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final size = MediaQuery.of(context).size;

    // Define the original Figma container dimensions for proportional scaling
    const double figmaContainerWidth = 412;
    const double figmaContainerHeight = 917;

    return Scaffold(
      // Apply the specific dark background color from the Figma design
      backgroundColor: const Color.fromARGB(255, 18, 32, 47),
      body: Center( // Center the main content container
        child: Container(
          // Make the container responsive, taking a large portion of screen width and height
          // Using a fixed aspect ratio or a percentage of screen size is better than fixed pixels
          width: size.width * 0.95, // Take 95% of screen width
          height: size.height * 0.95, // Take 95% of screen height
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white, // The white background of the inner container
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50), // Rounded corners as per Figma
            ),
          ),
          child: Stack(
            children: [
              // Positioned image, adjusted for responsiveness
              Positioned(
                // Scale positions proportionally to the new container size
                left: size.width * (12 / figmaContainerWidth),
                top: size.height * (157 / figmaContainerHeight),
                child: Opacity(
                  opacity: 0.70,
                  child: Container(
                    // Scale dimensions proportionally
                    width: size.width * (440.06 / figmaContainerWidth),
                    height: size.height * (315.49 / figmaContainerHeight),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage("https://placehold.co/440x315"), // Placeholder image URL
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              // "Navigate with confidence..." text
              Positioned(
                left: size.width * (36 / figmaContainerWidth),
                top: size.height * (38 / figmaContainerHeight),
                child: SizedBox(
                  width: size.width * (332 / figmaContainerWidth),
                  child: Text(
                    'Navigate with confidence, wherever you are.',
                    style: GoogleFonts.roboto( // Use Roboto font
                      color: Colors.white,
                      fontSize: size.width * (36 / figmaContainerWidth) * 0.9, // Responsive font size
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // "WELCOME TO" text
              Positioned(
                left: size.width * (28 / figmaContainerWidth),
                top: size.height * (632 / figmaContainerHeight),
                child: SizedBox(
                  width: size.width * (160 / figmaContainerWidth),
                  height: size.height * (23 / figmaContainerHeight),
                  child: Text(
                    'WELCOME TO\n',
                    style: GoogleFonts.poppins( // Use Poppins font
                      color: Colors.black,
                      fontSize: size.width * (24 / figmaContainerWidth) * 0.9, // Responsive font size
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // "LocalLink" text
              Positioned(
                left: size.width * (28 / figmaContainerWidth),
                top: size.height * (655 / figmaContainerHeight),
                child: Text(
                  'LocalLink',
                  style: GoogleFonts.poppins( // Use Poppins font
                    color: const Color(0xFF0A4E97),
                    fontSize: size.width * (48 / figmaContainerWidth) * 0.9, // Responsive font size
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // "Continue" Button
              Positioned(
                bottom: size.height * ( (figmaContainerHeight - 819 - 46) / figmaContainerHeight), // Position from bottom
                left: size.width * (42 / figmaContainerWidth),
                right: size.width * (42 / figmaContainerWidth),
                child: ElevatedButton(
                  onPressed: onComplete, // Call the callback to complete onboarding
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8BD00), // Yellow background from Figma
                    foregroundColor: Colors.black, // Black text from Figma
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(48), // Rounded corners from Figma
                    ),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.2),
                    textStyle: GoogleFonts.poppins( // Use Poppins font
                      fontSize: size.width * (19 / figmaContainerWidth) * 1.1, // Responsive font size
                      fontWeight: FontWeight.w600,
                    ),
                    minimumSize: Size(size.width * (327 / figmaContainerWidth), size.height * (46 / figmaContainerHeight)), // Responsive size
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
