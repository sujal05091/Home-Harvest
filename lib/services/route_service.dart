import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// 🗺️ ROUTE CALCULATION SERVICE
/// Fetches shortest road path using OSRM public API
class RouteService {
  // OSRM public server (free, no API key needed)
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  
  /// Fetch road-based route between two points
  /// Returns list of LatLng points along the route
  static Future<List<LatLng>> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      // OSRM route API format: /route/v1/driving/{lon},{lat};{lon},{lat}
      final url = Uri.parse(
        '$_osrmBaseUrl/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          
          // Convert [lon, lat] to LatLng objects
          return coordinates.map((coord) {
            return LatLng(
              coord[1] as double, // latitude
              coord[0] as double, // longitude
            );
          }).toList();
        }
      }
      
      // Fallback: return straight line if API fails
      print('⚠️ OSRM API failed, using straight line');
      return [start, end];
      
    } catch (e) {
      print('❌ Route fetch error: $e');
      // Fallback: return straight line
      return [start, end];
    }
  }
  
  /// Fetch multi-waypoint route (Rider → Pickup → Drop)
  static Future<List<LatLng>> getMultiWaypointRoute({
    required LatLng riderLocation,
    required LatLng pickupLocation,
    required LatLng dropLocation,
  }) async {
    try {
      // Build waypoints string: rider;pickup;drop
      final waypoints = '${riderLocation.longitude},${riderLocation.latitude};'
          '${pickupLocation.longitude},${pickupLocation.latitude};'
          '${dropLocation.longitude},${dropLocation.latitude}';
      
      final url = Uri.parse(
        '$_osrmBaseUrl/route/v1/driving/$waypoints?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          
          return coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();
        }
      }
      
      // Fallback: return straight lines
      return [riderLocation, pickupLocation, dropLocation];
      
    } catch (e) {
      print('❌ Multi-waypoint route error: $e');
      return [riderLocation, pickupLocation, dropLocation];
    }
  }
  
  /// Generate curved (parabolic) dotted line for Phase A
  /// Visual route before rider accepts
  static List<LatLng> generateCurvedRoute({
    required LatLng start,
    required LatLng end,
    int segments = 50,
  }) {
    final List<LatLng> curvedPoints = [];
    
    // Calculate midpoint with arc height
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    
    // Arc height (offset from straight line)
    final distance = _calculateDistance(start, end);
    final arcHeight = distance * 0.15; // 15% of distance
    
    // Generate parabolic curve
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      
      // Quadratic bezier curve
      final lat = _quadraticBezier(
        start.latitude,
        midLat + arcHeight,
        end.latitude,
        t,
      );
      final lng = _quadraticBezier(
        start.longitude,
        midLng,
        end.longitude,
        t,
      );
      
      curvedPoints.add(LatLng(lat, lng));
    }
    
    return curvedPoints;
  }
  
  /// Quadratic Bezier interpolation
  static double _quadraticBezier(double p0, double p1, double p2, double t) {
    final oneMinusT = 1.0 - t;
    return (oneMinusT * oneMinusT * p0) +
           (2 * oneMinusT * t * p1) +
           (t * t * p2);
  }
  
  /// Calculate distance between two points (in degrees)
  static double _calculateDistance(LatLng p1, LatLng p2) {
    final latDiff = p2.latitude - p1.latitude;
    final lngDiff = p2.longitude - p1.longitude;
    return (latDiff * latDiff + lngDiff * lngDiff);
  }
}
