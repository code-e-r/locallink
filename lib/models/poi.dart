// lib/models/poi.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart'; // For Color

/// A simple data model for a Point of Interest (POI).
class Poi {
  final String id;
  final String name;
  final String type; // e.g., 'bus_stop', 'auto_stand', 'printing_shop'
  final LatLng position;
  final String? details; // Optional details like timings

  Poi({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    this.details,
  });

  /// Helper to get a marker icon hue based on POI type.
  BitmapDescriptor get markerIcon {
    switch (type) {
      case 'bus_stop':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure); // Light blue
      case 'auto_stand':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange); // Orange
      case 'printing_shop':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta); // Pink/Magenta
      default:
        return BitmapDescriptor.defaultMarker; // Default red
    }
  }

  /// Helper to get a display color for the POI type.
  Color get displayColor {
    switch (type) {
      case 'bus_stop':
        return Colors.blue.shade700;
      case 'auto_stand':
        return Colors.orange.shade700;
      case 'printing_shop':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}
