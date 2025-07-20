# locallink
Local Link: Your Smart Companion for Unfamiliar Areas
# Project Overview
The Local Link is an innovative and adaptable system designed to empower travelers to confidently navigate and explore unfamiliar local areas. It addresses the common challenges of fragmented and unreliable local transport information and points of interest. Our solution provides a comprehensive platform to aggregate and organize travel options, timings, and essential local insights based on user preferences and constraints.
Unlike conventional navigation tools that often focus on long-distance or popular tourist destinations, our system deeply integrates with local nuances, bridging critical information gaps and significantly enhancing the overall travel experience for everyone.
# Key Features
#Aggregated Local Transport Options: Consolidates information on various local transport modes, including public buses, auto-rickshaws, and other private services, providing a holistic view of available options.
Interactive Map Integration: Features a dynamic and intuitive map displaying key transport hubs (like bus stands and auto stands) and allowing users to visualize their routes, current location, and surroundings.
Intelligent Chatbox for Suggestions: Offers a conversational interface where users can receive personalized travel recommendations, optimized route suggestions, and answers to their specific queries.
Community-Driven Data Collection: To overcome the challenge of dynamic and often unrecorded local data, the system intelligently prompts users via pop-up questions to contribute real-time information on bus stops and timings. This fosters a collaborative, self-updating, and highly accurate information network.
Customizable Itineraries: Users can effortlessly tailor their travel plans based on their available time, current location, specific interests, and any unique requirements.
Inclusive "Travel Buddy" Feature: A unique and impactful feature designed for physically disabled persons. Users can request and be assigned a verified travel buddy from our company. These trained and trusted personnel provide personalized assistance, ensuring a safer, more comfortable, and truly accessible travel experience.
# Problem Solved
Travelers frequently encounter confusion, wasted time, and inefficient journeys due to the lack of structured, reliable, and real-time information on local transport options and points of interest in new environments. Existing solutions often fall short in providing the granular, localized details necessary for seamless navigation. Our project directly tackles these pain points by offering a reliable, dynamic, and user-centric solution that makes local exploration enjoyable and stress-free for all, especially those with accessibility needs.
# Technologies Used
Frontend: Flutter (for building a beautiful, natively compiled, multi-platform application from a single codebase)
Mapping: google_maps_flutter (for interactive map display and functionalities)
Backend & Database:
AI/LLM: Gemini API for intelligent suggestions and conversational interactions
# Getting Started
Follow these steps to set up and run the Local Link application on your local machine.
# Prerequisites
Flutter SDK: Ensure you have Flutter installed and configured. Follow the official Flutter installation guide: https://flutter.dev/docs/get-started/install
Google Maps API Key: You will need an API key from the Google Cloud Console with the Google Maps SDK for Android, iOS, and Web (if applicable) enabled.
Installation
Clone the repository:
Install Flutter dependencies:
Navigate to the project root directory and run:
flutter pub get
Google Maps API Key Setup
This step is crucial for the map functionality.
Android:
Open android/app/src/main/AndroidManifest.xml and add the following inside the <application> tag:
<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
(Replace YOUR_GOOGLE_MAPS_API_KEY with your actual key)
# Running the Application
After setting up the API key, you can run the app on your preferred device or emulator:
flutter run
# How to Use
Explore the Map: Pan and zoom to explore local areas.
Get AI suggestion: based on your reason to visit, AI will suggest a checklist of things you might need
Get optimized route: Based on the
Request Travel Buddy: Navigate to the dedicated "Travel Buddy" section (or button) to request assistance from a verified company personnel.
Screenshots / GIFs

# Future Enhancements
Integration with more official transport data sources as they become available.
Advanced routing algorithms that dynamically incorporate crowdsourced data and real-time traffic.
Enhanced in-app communication features for seamless interaction between users and travel buddies.
Expansion of the "Travel Buddy" service network to cover more regions and specific assistance types.
Personalized recommendations for local events, attractions, and dining based on user interests and current location.
User profiles and ratings for contributors and travel buddies to build trust and community.
Add Bus Stops: Tap anywhere on the map to place a new bus stop marker.
Contribute Data: Click the "Ask Bus Timings" button to provide information on bus routes and schedules via a pop-up dialog.

