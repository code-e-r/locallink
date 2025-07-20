// lib/screens/embedded_map_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:locallinks/models/poi.dart';
import 'package:http/http.dart' as http; // For API call
import 'dart:convert'; // For JSON encoding/decoding
import 'dart:async'; // For Timer for simulated tracking

// Import the new AI Chat Widget
import 'package:locallinks/widgets/ai_chat_widget.dart';


class EmbeddedMapScreen extends StatefulWidget {
  final Position? initialPosition;
  final List<Poi> pois; // Initial POIs (e.g., from generated mock data)
  final List<String> aiSuggestions; // AI suggestions from the previous screen

  const EmbeddedMapScreen({
    super.key,
    this.initialPosition,
    this.pois = const [],
    this.aiSuggestions = const [], // Default to empty list
  });

  @override
  State<EmbeddedMapScreen> createState() => _EmbeddedMapScreenState();
}

class _EmbeddedMapScreenState extends State<EmbeddedMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {}; // To store route polylines
  LatLng? _currentLatLng;
  List<LatLng> _routePoints = []; // Stores selected points for routing

  String? _routeDistance; // State to store calculated route distance
  String? _routeDuration; // State to store calculated route duration
  String _selectedTravelMode = 'driving'; // Default travel mode for manual route calculation

  Marker? _trackingMarker; // Marker for simulated live tracking
  Timer? _trackingTimer; // Timer for simulated live tracking

  List<Map<String, dynamic>> _aiChecklist = []; // To store AI-generated checklist items: [{'text': 'item', 'checked': false}]
  List<Map<String, String>> _chatHistory = []; // To store AI chat history

  // IMPORTANT: Use your friend's Google Maps Platform API Key here
  // This key is used for Google Maps rendering, Directions API, and Places API calls.
  // Ensure "Maps SDK for Android", "Maps SDK for iOS", "Directions API", and "Places API" are enabled for this key.
  // Also, ensure "Geocoding API" is enabled for converting place names to coordinates.
  final String _googleMapsApiKey = "AIzaSyBv1DRscH0ZgZ78LM6vOcViMacxSF5BEYU"; // <--- PASTE YOUR FRIEND'S API KEY HERE

  final TextEditingController _searchController = TextEditingController(); // Controller for search bar

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentLatLng = LatLng(
        widget.initialPosition!.latitude,
        widget.initialPosition!.longitude,
      );
      _addMarker(
        markerId: 'currentLocation',
        position: _currentLatLng!,
        title: 'My Current Location',
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
      _routePoints.add(_currentLatLng!); // Add current location as the first point
    }

    // Add initial POIs passed from TravelBuddyApp (mock data)
    for (var poi in widget.pois) {
      _addMarker(
        markerId: poi.id,
        position: poi.position,
        title: poi.name,
        snippet: poi.details ?? poi.type.replaceAll('_', ' ').toUpperCase(),
        icon: poi.markerIcon,
      );
    }

    // Trigger nearby searches based on initial AI suggestions
    _processInitialAiSuggestionsForMap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _trackingTimer?.cancel(); // Cancel timer to prevent memory leaks
    super.dispose();
  }

  /// Processes initial AI suggestions from the previous screen to populate map.
  void _processInitialAiSuggestionsForMap() {
    if (_currentLatLng == null) {
      print('Initial AI suggestion processing deferred: current location not available yet.');
      return;
    }

    for (String suggestion in widget.aiSuggestions) {
      String lowerSuggestion = suggestion.toLowerCase();
      if (lowerSuggestion.contains('printing shop') || lowerSuggestion.contains('print shop')) {
        _searchNearbyPlaces('printing_shop');
      }
      if (lowerSuggestion.contains('bus stop') || lowerSuggestion.contains('bus station')) {
        _searchNearbyPlaces('bus_station');
      }
      if (lowerSuggestion.contains('auto stand') || lowerSuggestion.contains('taxi stand')) {
        _searchNearbyPlaces('taxi_stand');
      }
      // Add more conditions for other types of places AI might suggest
    }
  }

  /// Callback from AIChatWidget to add a new message to the chat history.
  void _handleNewChatMessage(Map<String, String> message) {
    setState(() {
      _chatHistory.add(message);
    });
  }

  /// Callback from AIChatWidget to trigger a map search based on AI's command.
  void _handleChatSearchCommand(String type) {
    print('Received search command from AI chat: $type');
    if (_currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot search nearby places: current location not available.')),
      );
      return;
    }
    // Clear previous search results markers before new search
    _clearDynamicMarkers();
    _searchNearbyPlaces(type);
  }

  /// Callback from AIChatWidget to trigger a text search and route calculation.
  void _handleChatTextSearchCommand(String query) async {
    print('Received text search command from AI chat: $query');
    if (_currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot search: current location not available.')),
      );
      return;
    }
    // Clear previous search results markers before new search
    _clearDynamicMarkers();

    // Perform the text search
    final String placesApiUrl =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?'
        'query=${Uri.encodeComponent(query)}&'
        'location=${_currentLatLng!.latitude},${_currentLatLng!.longitude}&' // Bias results to current location
        'radius=50000&' // Search radius in meters (50km for text search)
        'key=$_googleMapsApiKey';

    print('Places API URL (Text Search): $placesApiUrl');

    try {
      final response = await http.get(Uri.parse(placesApiUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Places API Response Status (Text Search from Chat): ${data['status']}');
        print('Places API Raw Response (Text Search from Chat): ${json.encode(data)}');

        if (data['results'] != null && data['results'].isNotEmpty) {
          final lat = data['results'][0]['geometry']['location']['lat'];
          final lng = data['results'][0]['geometry']['location']['lng'];
          final name = data['results'][0]['name'];
          final placeId = data['results'][0]['place_id'];
          final searchedLatLng = LatLng(lat, lng);

          // Add marker for the searched place
          _addMarker(
            markerId: placeId,
            position: searchedLatLng,
            title: name,
            snippet: 'AI Search Result',
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          );

          // Clear existing route points and set new ones for route calculation
          _routePoints.clear();
          _routePoints.add(_currentLatLng!); // Start from current location
          _routePoints.add(searchedLatLng); // End at the searched place

          // Set travel mode for this simple trip
          _selectedTravelMode = 'driving'; // Default to driving for simple text search route

          // Calculate and display the route
          _getRoute();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Found "$name". Calculating route...')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No results found for "$query" from AI chat.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching search results from AI chat: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching places from AI chat: ${e.toString()}')),
      );
    }
  }

  /// Callback from AIChatWidget to trigger simple A-to-B trip planning.
  Future<void> _handleSimpleTripCommand(String originName, String destinationName, String mode) async {
    print('Received simple trip command from AI chat: $originName to $destinationName by $mode');
    if (_currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot plan trip: current location not available.')),
      );
      return;
    }

    _clearStopsAndRoute(); // Clear existing markers, polylines, and route points

    // Geocode Origin and Destination
    LatLng? originLatLng;
    if (originName.toLowerCase() == 'my current location') {
      originLatLng = _currentLatLng;
      print('Geocoding: Origin is current location: $originLatLng');
    } else {
      originLatLng = await _geocodeAddress(originName);
      print('Geocoding: Origin $originName -> $originLatLng');
    }
    LatLng? destinationLatLng = await _geocodeAddress(destinationName);
    print('Geocoding: Destination $destinationName -> $destinationLatLng');


    if (originLatLng == null || destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find coordinates for $originName or $destinationName.')),
      );
      print('Simple Trip: Failed to geocode origin or destination.');
      return;
    }

    // Add markers for origin and destination
    _addMarker(
      markerId: 'simple_origin',
      position: originLatLng,
      title: '$originName (Start)',
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );
    _addMarker(
      markerId: 'simple_destination',
      position: destinationLatLng,
      title: '$destinationName (End)',
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    // Set route points for a single segment
    _routePoints.clear();
    _routePoints.add(originLatLng);
    _routePoints.add(destinationLatLng);

    // Set selected travel mode and calculate route
    setState(() {
      _selectedTravelMode = mode; // Use the mode provided by AI
    });
    _getRoute();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Planning trip from $originName to $destinationName by $mode...')),
    );
  }


  /// Callback from AIChatWidget to trigger multi-segment trip planning.
  Future<void> _handleTripSegmentCommand(List<Map<String, String>> segments) async {
    print('Received multi-segment trip plan command from AI chat: $segments');
    if (_currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot plan trip: current location not available.')),
      );
      return;
    }

    _clearStopsAndRoute(); // Clear existing markers, polylines, and route points

    // Ensure the first segment's origin is correctly handled
    LatLng? firstSegmentOriginLatLng;
    if (segments.first['origin']?.toLowerCase() == 'my current location') {
      firstSegmentOriginLatLng = _currentLatLng;
      print('Multi-segment: First origin is current location: $firstSegmentOriginLatLng');
    } else {
      firstSegmentOriginLatLng = await _geocodeAddress(segments.first['origin']!);
      print('Multi-segment: First origin ${segments.first['origin']} -> $firstSegmentOriginLatLng');
    }

    if (firstSegmentOriginLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find coordinates for initial origin: ${segments.first['origin']}.')),
      );
      print('Multi-segment trip: Failed to geocode first segment origin.');
      return;
    }

    // Clear all existing markers except the current location to prepare for new trip markers
    setState(() {
      _markers.clear();
      _addMarker(
        markerId: 'currentLocation',
        position: _currentLatLng!,
        title: 'My Current Location',
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    });

    // Reset polylines for new segments
    _polylines.clear();

    List<LatLng> fullRoutePolylineForTracking = []; // Accumulate for overall tracking
    String totalTripDistance = '0 m';
    String totalTripDuration = '0 secs';

    LatLng currentSegmentOrigin = firstSegmentOriginLatLng; // Start with the first origin

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final originName = segment['origin']!; // This origin is conceptual for AI, actual is currentSegmentOrigin
      final destinationName = segment['destination']!;
      final travelMode = segment['mode']!;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Planning segment ${i + 1}: $originName to $destinationName by $travelMode...')),
      );

      // Geocode the destination of the current segment
      LatLng? segDestLatLng = await _geocodeAddress(destinationName);

      if (segDestLatLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find coordinates for destination: $destinationName.')),
        );
        print('Multi-segment trip: Failed to geocode segment destination: $destinationName.');
        return; // Stop if geocoding fails
      }

      // Add markers for segment origin/destination if not already present
      if (!_markers.any((m) => m.position == currentSegmentOrigin)) {
        _addMarker(
          markerId: 'segment_origin_$i',
          position: currentSegmentOrigin,
          title: '$originName (Start)',
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        );
      }
      if (!_markers.any((m) => m.position == segDestLatLng)) {
        _addMarker(
          markerId: 'segment_destination_$i',
          position: segDestLatLng,
          title: '$destinationName (End)',
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }

      // Get Directions for the segment
      final segmentRouteData = await _getDirectionsForSegment(currentSegmentOrigin, segDestLatLng, travelMode);

      if (segmentRouteData != null) {
        final List<LatLng> segmentPolylineCoordinates = segmentRouteData['polylineCoordinates'];
        fullRoutePolylineForTracking.addAll(segmentPolylineCoordinates); // Add to overall tracking polyline

        // Add this segment's polyline to the map with its specific color
        setState(() {
          Polyline segmentPolyline = Polyline(
            polylineId: PolylineId("segment_route_$i"), // Unique ID for each segment
            color: _getPolylineColor(travelMode), // Color based on mode
            points: segmentPolylineCoordinates,
            width: 5,
          );
          _polylines.add(segmentPolyline);
        });

        totalTripDistance = _sumDistances(totalTripDistance, segmentRouteData['distance']);
        totalTripDuration = _sumDurations(totalTripDuration, segmentRouteData['duration']);
        currentSegmentOrigin = segDestLatLng; // Next segment starts from this destination
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not plan route for segment ${i + 1}.')),
        );
        print('Multi-segment trip: Failed to get directions for segment ${i + 1}.');
        return; // Stop if segment route fails
      }
    }

    // After all segments are processed, update overall route details and start tracking
    if (fullRoutePolylineForTracking.isNotEmpty) {
      setState(() {
        _routeDistance = totalTripDistance;
        _routeDuration = totalTripDuration;
        _selectedTravelMode = segments.first['mode']!; // Display mode of first segment as representative
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          _boundsFromLatLngList(fullRoutePolylineForTracking),
          50.0,
        ),
      );

      _startTrackingSimulation(fullRoutePolylineForTracking);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No complete route could be planned.')),
      );
      print('Multi-segment trip: Full route polyline is empty after all segments.');
    }
  }

  /// Helper to get a color for a polyline based on travel mode.
  Color _getPolylineColor(String mode) {
    switch (mode) {
      case 'driving':
        return Colors.blue.shade700;
      case 'walking':
        return Colors.green.shade700;
      case 'bicycling':
        return Colors.orange.shade700;
      case 'transit':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700; // Default color for unrecognized modes
    }
  }

  /// Helper to geocode an address string to LatLng.
  Future<LatLng?> _geocodeAddress(String address) async {
    final String geocodingUrl =
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'address=${Uri.encodeComponent(address)}&'
        'key=$_googleMapsApiKey';

    print('Geocoding API URL: $geocodingUrl');
    try {
      final response = await http.get(Uri.parse(geocodingUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Geocoding API Response Status: ${data['status']}');
        if (data.containsKey('error_message')) {
          print('Geocoding API Error Message: ${data['error_message']}');
        }
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        } else {
          print('Geocoding API: No results for $address. Status: ${data['status']}');
          return null;
        }
      } else {
        print('Geocoding API HTTP Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error geocoding $address: $e');
      return null;
    }
  }

  /// Helper to get directions for a single segment.
  Future<Map<String, dynamic>?> _getDirectionsForSegment(LatLng origin, LatLng destination, String mode) async {
    final String directionsUrl =
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        'mode=$mode&'
        'key=$_googleMapsApiKey';

    print('Directions API URL (Segment): $directionsUrl');
    try {
      final response = await http.get(Uri.parse(directionsUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Directions API Response Status (Segment): ${data['status']}');
        if (data.containsKey('error_message')) {
          print('Directions API Error Message (Segment): ${data['error_message']}');
        }
        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final String encodedPolyline = route['overview_polyline']['points'];
          final List<LatLng> polylineCoordinates = _decodePolyline(encodedPolyline);

          double segmentDistanceMeters = 0;
          int segmentDurationSeconds = 0;
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            for (var leg in route['legs']) {
              if (leg['distance'] != null && leg['distance']['value'] != null) {
                segmentDistanceMeters += (leg['distance']['value'] as num).toDouble();
              }
              if (leg['duration'] != null && leg['duration']['value'] != null) {
                segmentDurationSeconds += (leg['duration']['value'] as num).toInt();
              }
            }
          }

          return {
            'polylineCoordinates': polylineCoordinates,
            'distance': _formatDistance(segmentDistanceMeters),
            'duration': _formatDuration(segmentDurationSeconds),
          };
        } else {
          print('Directions API (Segment): No route found. Status: ${data['status']}');
          return null;
        }
      } else {
        print('Directions API HTTP Error (Segment): ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting directions for segment: $e');
      return null;
    }
  }

  /// Helper to sum distances (e.g., "10 km" + "500 m").
  String _sumDistances(String dist1, String dist2) {
    // Simple parsing, can be made more robust
    double val1 = double.tryParse(dist1.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    double val2 = double.tryParse(dist2.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    bool isKm1 = dist1.toLowerCase().contains('km');
    bool isKm2 = dist2.toLowerCase().contains('km');

    double totalMeters = 0;
    if (isKm1) totalMeters += val1 * 1000; else totalMeters += val1;
    if (isKm2) totalMeters += val2 * 1000; else totalMeters += val2;

    return _formatDistance(totalMeters);
  }

  /// Helper to sum durations (e.g., "10 mins" + "1 hour").
  String _sumDurations(String dur1, String dur2) {
    // Simple parsing, can be made more robust
    int totalSeconds = 0;

    RegExp minsReg = RegExp(r'(\d+)\s*min');
    RegExp hoursReg = RegExp(r'(\d+)\s*hour');
    RegExp secsReg = RegExp(r'(\d+)\s*sec');

    int parseDurationToSeconds(String durationString) {
      int seconds = 0;
      if (minsReg.hasMatch(durationString)) {
        seconds += (int.tryParse(minsReg.firstMatch(durationString)!.group(1)!) ?? 0) * 60;
      }
      if (hoursReg.hasMatch(durationString)) {
        seconds += (int.tryParse(hoursReg.firstMatch(durationString)!.group(1)!) ?? 0) * 3600;
      }
      if (secsReg.hasMatch(durationString)) {
        seconds += (int.tryParse(secsReg.firstMatch(durationString)!.group(1)!) ?? 0);
      }
      return seconds;
    }

    totalSeconds += parseDurationToSeconds(dur1);
    totalSeconds += parseDurationToSeconds(dur2);

    return _formatDuration(totalSeconds);
  }


  /// Callback from AIChatWidget to trigger a suggested POI search.
  void _handleSuggestPoiCommand(String type) {
    print('Received suggest POI command from AI chat: $type');
    _searchNearbyPlaces(type, radius: 5000); // Increased radius for suggested POIs
  }

  /// Callback from AIChatWidget to display a checklist.
  void _handleChecklistCommand(List<String> items) {
    print('Received checklist command from AI chat: $items');
    setState(() {
      // Initialize checklist items as Map<String, dynamic> for interactivity
      _aiChecklist = items.map((item) => {'text': item, 'checked': false}).toList();
    });
    // Optionally, show a dialog or SnackBar to highlight the checklist
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI suggested a checklist! Check the map screen.')),
    );
  }


  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLatLng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLatLng!, 15.0),
      );
    } else if (widget.pois.isNotEmpty) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(widget.pois.first.position, 15.0),
      );
    }
  }

  // Method to add a new marker when user taps on the map
  void _onMapTap(LatLng tappedPoint) {
    // Generate a unique ID for the new marker
    String markerId = 'custom_stop_${_markers.length + 1}'; // Use _markers.length for unique ID
    _addMarker(
      markerId: markerId,
      position: tappedPoint,
      title: 'Stop ${_routePoints.length + 1}', // Title based on route points count
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Green marker for custom stops
    );
    setState(() {
      _routePoints.add(tappedPoint); // Add the tapped point to our route list
    });
    print('Added stop: ${tappedPoint.latitude}, ${tappedPoint.longitude}');
  }

  void _addMarker({
    required String markerId,
    required LatLng position,
    required String title,
    String? snippet,
    BitmapDescriptor icon = BitmapDescriptor.defaultMarker,
  }) {
    final marker = Marker(
        markerId: MarkerId(markerId),
        position: position,
        infoWindow: InfoWindow(title: title, snippet: snippet),
        icon: icon,
        onTap: () {
          // Optional: Handle marker tap, e.g., show details or add to route
          print('Tapped on marker: $title');
        }
    );
    setState(() {
      _markers.add(marker);
      print('Marker Added: ID: $markerId, Title: $title, Position: $position'); // Debugging print
    });
  }

  /// Clears all markers that are NOT the current location, initial POIs, or manually added route points.
  /// This effectively removes previous search results.
  void _clearDynamicMarkers() {
    setState(() {
      _markers.removeWhere((marker) {
        // Keep current location marker
        if (marker.markerId.value == 'currentLocation') return false;

        // Keep pre-defined POI markers
        if (widget.pois.any((poi) => poi.id == marker.markerId.value)) return false;

        // Keep manually added route point markers (green ones)
        if (_routePoints.any((point) => point == marker.position)) return false;

        // If none of the above, it's a dynamic search result marker, so remove it
        return true;
      });
      print('Dynamic markers cleared. Remaining markers count: ${_markers.length}'); // Debugging print
    });
  }


  // Function to search for nearby places using Google Places API (Nearby Search)
  Future<void> _searchNearbyPlaces(String type, {double radius = 1000}) async {
    if (_currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot search nearby places: current location not available.')),
      );
      return;
    }

    // Clear previous search results markers before new search
    _clearDynamicMarkers();

    final String placesApiUrl =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=${_currentLatLng!.latitude},${_currentLatLng!.longitude}&'
        'radius=$radius&' // Search radius in meters
        'type=$type&' // Type of place to search (e.g., 'bus_station', 'atm', 'restaurant')
        'key=$_googleMapsApiKey';

    print('Places API URL (Nearby Search): $placesApiUrl');

    try {
      final response = await http.get(Uri.parse(placesApiUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        print('Places API Response Status (Nearby Search): ${data['status']}');
        if (data.containsKey('error_message')) {
          print('Places API Error Message (Nearby Search): ${data['error_message']}');
        }
        print('Places API Raw Response (Nearby Search): ${json.encode(data)}');

        if (data['results'] != null && data['results'].isNotEmpty) {
          int addedCount = 0;
          for (var place in data['results']) {
            final lat = place['geometry']['location']['lat'];
            final lng = place['geometry']['location']['lng'];
            final name = place['name'];
            final placeId = place['place_id'];

            // Only add marker if it's not already present
            if (!_markers.any((m) => m.markerId.value == placeId)) {
              _addMarker(
                markerId: placeId,
                position: LatLng(lat, lng),
                title: name,
                snippet: type.replaceAll('_', ' ').toUpperCase(),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet), // Violet for search results
              );
              addedCount++;
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Found $addedCount new nearby ${type.replaceAll('_', ' ')}s.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No nearby ${type.replaceAll('_', ' ')} found.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching nearby places: ${response.statusCode}')),
        );
        print('Places API HTTP Error (Nearby Search): ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching nearby places: ${e.toString()}')),
      );
      print('Error calling Google Places API (Nearby Search): $e');
    }
  }

  // Function to search for places by text query using Google Places API (Text Search)
  Future<void> _searchPlacesByText(String query) async {
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search query.')),
      );
      return;
    }
    if (_currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot search: current location not available.')),
      );
      return;
    }

    // Clear previous search results markers before new search
    _clearDynamicMarkers();

    final String placesApiUrl =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?'
        'query=${Uri.encodeComponent(query)}&'
        'location=${_currentLatLng!.latitude},${_currentLatLng!.longitude}&' // Bias results to current location
        'radius=50000&' // Search radius in meters (50km for text search)
        'key=$_googleMapsApiKey';

    print('Places API URL (Text Search): $placesApiUrl');

    try {
      final response = await http.get(Uri.parse(placesApiUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        print('Places API Response Status (Text Search): ${data['status']}');
        if (data.containsKey('error_message')) {
          print('Places API Error Message (Text Search): ${data['error_message']}');
        }
        print('Places API Raw Response (Text Search): ${json.encode(data)}');


        if (data['results'] != null && data['results'].isNotEmpty) {
          int addedCount = 0;
          for (var place in data['results']) {
            final lat = place['geometry']['location']['lat'];
            final lng = place['geometry']['location']['lng'];
            final name = place['name'];
            final placeId = place['place_id'];

            // Calculate distance to the found place
            String distanceText = '';
            if (_currentLatLng != null) {
              final distanceData = await _getDistance(
                LatLng(_currentLatLng!.latitude, _currentLatLng!.longitude),
                LatLng(lat, lng),
              );
              if (distanceData != null) {
                distanceText = 'Distance: ${distanceData['distance']} (${distanceData['duration']})';
              }
            }

            if (!_markers.any((m) => m.markerId.value == placeId)) {
              _addMarker(
                markerId: placeId,
                position: LatLng(lat, lng),
                title: name,
                snippet: distanceText.isNotEmpty ? '$distanceText, Search Result' : 'Search Result',
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan), // Cyan for text search results
              );
              addedCount++;
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Found $addedCount new results for "$query".')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No results found for "$query".')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching search results: ${response.statusCode}')),
        );
        print('Places API HTTP Error (Text Search): ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching places: ${e.toString()}')),
      );
      print('Error calling Google Places API (Text Search): $e');
    }
  }

  /// Calculates distance and duration between two LatLng points using Distance Matrix API.
  Future<Map<String, String>?> _getDistance(LatLng origin, LatLng destination) async {
    final String distanceMatrixUrl =
        'https://maps.googleapis.com/maps/api/distancematrix/json?'
        'origins=${origin.latitude},${origin.longitude}&'
        'destinations=${destination.latitude},${destination.longitude}&'
        'key=$_googleMapsApiKey';

    print('Distance Matrix API URL: $distanceMatrixUrl');

    try {
      final response = await http.get(Uri.parse(distanceMatrixUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Distance Matrix API Response Status: ${data['status']}');
        if (data.containsKey('error_message')) {
          print('Distance Matrix API Error Message: ${data['error_message']}');
        }
        print('Distance Matrix Raw Response: ${json.encode(data)}');

        if (data['rows'] != null && data['rows'].isNotEmpty &&
            data['rows'][0]['elements'] != null && data['rows'][0]['elements'].isNotEmpty &&
            data['rows'][0]['elements'][0]['status'] == 'OK') {
          final element = data['rows'][0]['elements'][0];
          return {
            'distance': element['distance']['text'],
            'duration': element['duration']['text'],
          };
        } else {
          print('Distance Matrix API: No valid distance data found. Status: ${data['status']}');
          return null;
        }
      } else {
        print('Distance Matrix API HTTP Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calling Distance Matrix API: $e');
      return null;
    }
  }


  // Function to calculate and draw the route using Google Directions API directly
  Future<void> _getRoute() async {
    if (_routePoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least two points to calculate a route.')),
      );
      return;
    }

    _polylines.clear(); // Clear existing polylines
    setState(() {
      _routeDistance = null; // Clear previous route details
      _routeDuration = null;
      _trackingTimer?.cancel(); // Stop any existing tracking simulation
      _trackingMarker = null; // Remove tracking marker
    });

    LatLng origin = _routePoints.first;
    LatLng destination = _routePoints.last;

    String waypointsString = '';
    if (_routePoints.length > 2) {
      // Create waypoints string for intermediate stops
      waypointsString = '&waypoints=optimize:true'; // Optimize order
      for (int i = 1; i < _routePoints.length - 1; i++) {
        waypointsString += '|${_routePoints[i].latitude},${_routePoints[i].longitude}';
      }
    }

    // Construct the Google Directions API URL
    final String directionsUrl =
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        'mode=$_selectedTravelMode&' // Use selected travel mode
        'key=$_googleMapsApiKey';

    print('Directions API URL: $directionsUrl'); // Debugging: Log API URL

    try {
      final response = await http.get(Uri.parse(directionsUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Debugging: Print the full API response status and message
        print('Directions API Response Status: ${data['status']}');
        if (data.containsKey('error_message')) {
          print('Directions API Error Message: ${data['error_message']}');
        }

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final String encodedPolyline = route['overview_polyline']['points'];
          final List<LatLng> polylineCoordinates = _decodePolyline(encodedPolyline);

          // Extract distance and duration from the route
          String totalDistance = 'N/A';
          String totalDuration = 'N/A';

          if (route['legs'] != null && route['legs'].isNotEmpty) {
            double distMeters = 0;
            int durSeconds = 0;
            for (var leg in route['legs']) {
              if (leg['distance'] != null && leg['distance']['value'] != null) {
                distMeters += (leg['distance']['value'] as num).toDouble(); // Cast to num then to Double
              }
              if (leg['duration'] != null && leg['duration']['value'] != null) {
                durSeconds += (leg['duration']['value'] as num).toInt(); // Cast to num then to Int
              }
            }
            totalDistance = _formatDistance(distMeters);
            totalDuration = _formatDuration(durSeconds);
          }


          setState(() {
            _routeDistance = totalDistance;
            _routeDuration = totalDuration;
          });


          if (polylineCoordinates.isNotEmpty) {
            setState(() {
              Polyline polyline = Polyline(
                polylineId: const PolylineId("route"),
                color: _getPolylineColor(_selectedTravelMode), // Use color based on selected mode
                points: polylineCoordinates,
                width: 5,
              );
              _polylines.add(polyline);
            });

            // Optionally, zoom camera to fit the route
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(
                _boundsFromLatLngList(polylineCoordinates),
                50.0, // Padding
              ),
            );

            // Start simulated tracking
            _startTrackingSimulation(polylineCoordinates);

          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not decode route polyline.')),
            );
            print('Directions API: Empty polyline coordinates after decoding.');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not find a route. Status: ${data['status'] ?? 'Unknown'}')),
          );
          print('Directions API Response: ${data['status']} - ${data['error_message'] ?? ''}');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching route: ${response.statusCode}')),
        );
        print('Directions API HTTP Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating route: ${e.toString()}')),
      );
      print('Error calling Google Directions API: $e');
    }
  }

  // Helper function to format distance (e.g., from meters to km)
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  // Helper function to format duration (e.g., from seconds to minutes/hours)
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds secs';
    } else if (seconds < 3600) {
      return '${(seconds / 60).toStringAsFixed(0)} mins';
    } else {
      double hours = seconds / 3600;
      return '${hours.toStringAsFixed(1)} hours';
    }
  }


  // Helper function to decode Google's encoded polyline string
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  // Helper function to calculate bounds from a list of LatLng points
  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null || x0 > latLng.latitude) x0 = latLng.latitude;
      if (x1 == null || x1 < latLng.latitude) x1 = latLng.latitude;
      if (y0 == null || y0 > latLng.longitude) y0 = latLng.longitude;
      if (y1 == null || y1 < latLng.longitude) y1 = latLng.longitude;
    }
    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  // Function to clear all custom stops and routes
  void _clearStopsAndRoute() {
    setState(() {
      // Remove all markers except the initial POIs and current location
      // This retains the blue 'My Current Location' marker and any pre-defined POI markers
      _markers.retainWhere((marker) =>
      marker.markerId.value == 'currentLocation' ||
          widget.pois.any((poi) => poi.id == marker.markerId.value));

      // Clear route points, keeping only the initial current location if it exists
      _routePoints.clear();
      if (_currentLatLng != null) {
        _routePoints.add(_currentLatLng!);
      }

      _polylines.clear(); // Clear all polylines
      _routeDistance = null; // Clear route details
      _routeDuration = null;
      _trackingTimer?.cancel(); // Stop tracking simulation
      _trackingMarker = null; // Remove tracking marker
      _aiChecklist = []; // Clear checklist
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleared all custom stops and routes.')),
    );
  }

  /// Simulates live tracking by animating a marker along the route.
  void _startTrackingSimulation(List<LatLng> polylineCoordinates) {
    _trackingTimer?.cancel(); // Cancel any existing timer

    if (polylineCoordinates.isEmpty) return;

    int currentIndex = 0;
    _trackingMarker = Marker(
      markerId: const MarkerId('trackingMarker'),
      position: polylineCoordinates[0],
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow), // Yellow marker for tracking
      infoWindow: const InfoWindow(title: 'Tracking'),
    );
    setState(() {
      // Remove old tracking marker if it exists
      _markers.removeWhere((m) => m.markerId.value == 'trackingMarker');
      _markers.add(_trackingMarker!);
    });

    _trackingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (currentIndex < polylineCoordinates.length - 1) {
        currentIndex++;
        setState(() {
          _trackingMarker = _trackingMarker!.copyWith(
            positionParam: polylineCoordinates[currentIndex],
          );
          _markers.removeWhere((m) => m.markerId.value == 'trackingMarker');
          _markers.add(_trackingMarker!);
        });
        // Optionally move camera with the tracking marker
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(polylineCoordinates[currentIndex]),
        );
      } else {
        timer.cancel(); // Stop animation when end of route is reached
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route simulation complete!')),
        );
        setState(() {
          _trackingMarker = null; // Remove tracking marker at the end
          _markers.removeWhere((m) => m.markerId.value == 'trackingMarker');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool canDisplayMap = _currentLatLng != null || widget.pois.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Map', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack( // Use Stack to layer the search bar on top of the map
        children: [
          canDisplayMap
              ? GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLatLng ?? (widget.pois.isNotEmpty ? widget.pois.first.position : const LatLng(0, 0)),
              zoom: _currentLatLng != null || widget.pois.isNotEmpty ? 15.0 : 2.0,
            ),
            markers: _markers,
            polylines: _polylines, // Display polylines
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            onTap: _onMapTap, // Enable map tapping to add stops
          )
              : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Getting map ready...'),
                Text('Ensure location services are enabled and API key is correct.'),
              ],
            ),
          ),
          // Search Bar Overlay
          Positioned(
            top: 10.0,
            left: 10.0,
            right: 10.0,
            child: SafeArea( // Ensures it doesn't overlap with notches/status bar
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for places...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Colors.blue),
                      onPressed: () {
                        _searchPlacesByText(_searchController.text);
                        FocusScope.of(context).unfocus(); // Dismiss keyboard
                      },
                    ),
                  ),
                  onSubmitted: (value) {
                    _searchPlacesByText(value);
                  },
                ),
              ),
            ),
          ),
          // Route Details Display
          if (_routeDistance != null && _routeDuration != null)
            Positioned(
              top: 80.0, // Position below search bar
              left: 10.0,
              right: 10.0,
              child: SafeArea(
                child: Card(
                  elevation: 8.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  color: Colors.blue.shade50.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route Details:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                        ),
                        const SizedBox(height: 4),
                        Text('Distance: $_routeDistance', style: TextStyle(color: Colors.grey.shade800)),
                        Text('Duration: $_routeDuration', style: TextStyle(color: Colors.grey.shade800)),
                        Text('Mode: ${_selectedTravelMode.toUpperCase()}', style: TextStyle(color: Colors.grey.shade800)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // AI Checklist Display (interactive version)
          if (_aiChecklist.isNotEmpty)
            Positioned(
              bottom: 10.0, // Position above FABs
              left: 10.0,
              right: 10.0,
              child: SafeArea(
                child: Card(
                  elevation: 8.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  color: Colors.green.shade50.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Checklist:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                        const SizedBox(height: 4),
                        // Corrected to use _aiChecklist as Map<String, dynamic>
                        ..._aiChecklist.asMap().entries.map((entry) {
                          int idx = entry.key;
                          Map<String, dynamic> item = entry.value;
                          return Row(
                            children: [
                              Checkbox(
                                value: item['checked'],
                                onChanged: (bool? newValue) {
                                  setState(() {
                                    _aiChecklist[idx]['checked'] = newValue!;
                                  });
                                },
                                activeColor: Colors.green.shade600,
                              ),
                              Expanded(
                                child: Text(
                                  item['text'],
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    decoration: item['checked'] ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Travel Mode Selection (only visible if a route is planned or being planned)
          if (_routePoints.length >= 2 || _polylines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTravelMode,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTravelMode = newValue;
                            // Recalculate route if points exist and mode changes
                            if (_routePoints.length >= 2) {
                              _getRoute();
                            }
                          });
                        }
                      },
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'driving',
                          child: Row(
                            children: [
                              Icon(Icons.directions_car, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Driving'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'walking',
                          child: Row(
                            children: [
                              Icon(Icons.directions_walk, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Walking'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'bicycling',
                          child: Row(
                            children: [
                              Icon(Icons.directions_bike, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Bicycling'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'transit',
                          child: Row(
                            children: [
                              Icon(Icons.directions_transit, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('Transit'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Clear Stops and Route Button
          if (_routePoints.length > 1 || _polylines.isNotEmpty || _aiChecklist.isNotEmpty) // Show if any dynamic elements exist
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: FloatingActionButton.extended(
                heroTag: "clearBtn",
                onPressed: _clearStopsAndRoute,
                label: const Text('Clear All'), // Changed to clear all dynamic elements
                icon: const Icon(Icons.clear),
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
            ),
          // Calculate Route Button (for manually added points)
          if (_routePoints.length >= 2 && _polylines.isEmpty) // Only show if manual points and no route yet
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: FloatingActionButton.extended(
                heroTag: "routeBtn",
                onPressed: _getRoute,
                label: const Text('Calculate Route'),
                icon: const Icon(Icons.directions_car),
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          // AI Chat Button
          FloatingActionButton(
            heroTag: "aiChatBtn",
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) {
                  return AIChatWidget(
                    onSearchCommand: _handleChatSearchCommand,
                    onTextSearchCommand: _handleChatTextSearchCommand,
                    onTripPlanCommand: _handleTripSegmentCommand,
                    onSuggestPoiCommand: _handleSuggestPoiCommand,
                    onChecklistCommand: _handleChecklistCommand,
                    onSimpleTripCommand: _handleSimpleTripCommand,
                    messages: _chatHistory,
                    onNewMessage: _handleNewChatMessage,
                  );
                },
              );
            },
            backgroundColor: Colors.purple.shade600,
            child: const Icon(Icons.chat, color: Colors.white),
          ),
          const SizedBox(height: 16),
          // Back Button
          FloatingActionButton(
            heroTag: "backBtn",
            onPressed: () {
              Navigator.pop(context);
            },
            backgroundColor: Colors.blue.shade600,
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
