import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Route information from OSRM
class RouteInfo {
  final List<LatLng> points;        // Route polyline points
  final double distanceInMeters;    // Actual road distance in meters
  final double durationInSeconds;   // Estimated time in seconds
  final double distanceInKm;        // Distance in kilometers
  
  RouteInfo({
    required this.points,
    required this.distanceInMeters,
    required this.durationInSeconds,
  }) : distanceInKm = distanceInMeters / 1000.0;  // Convert to km
  
  @override
  String toString() {
    return 'RouteInfo(distance: ${distanceInKm.toStringAsFixed(2)} km, duration: ${(durationInSeconds / 60).toStringAsFixed(1)} min, points: ${points.length})';
  }
}

/// 🗺️ ROUTE CALCULATION SERVICE
/// Fetches shortest road path using OSRM public API
class RouteService {
  // OSRM public server (free, no API key needed)
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  
  /// Fetch road-based route WITH distance and duration
  /// Returns RouteInfo containing route data from OSRM
  static Future<RouteInfo> getRouteInfo({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      // OSRM route API format: /route/v1/driving/{lon},{lat};{lon},{lat}
      final url = Uri.parse(
        '$_osrmBaseUrl/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );

      print('🗺️ [OSRM] Fetching route: ${start.latitude},${start.longitude} → ${end.latitude},${end.longitude}');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          // Extract distance and duration
          final distanceInMeters = (route['distance'] as num).toDouble();
          final durationInSeconds = (route['duration'] as num).toDouble();
          
          // Extract coordinates
          final coordinates = route['geometry']['coordinates'] as List;
          final points = coordinates.map((coord) {
            return LatLng(
              coord[1] as double, // latitude
              coord[0] as double, // longitude
            );
          }).toList();
          
          final routeInfo = RouteInfo(
            points: points,
            distanceInMeters: distanceInMeters,
            durationInSeconds: durationInSeconds,
          );
          
          print('✅ [OSRM] Route fetched: ${routeInfo}');
          return routeInfo;
        }
      }
      
      print('⚠️ [OSRM] API failed with status: ${response.statusCode}');
      // Fallback: return straight line with calculated distance
      return _createFallbackRoute(start, end);
      
    } catch (e) {
      print('❌ [OSRM] Route fetch error: $e');
      // Fallback: return straight line with Haversine distance
      return _createFallbackRoute(start, end);
    }
  }
  
  /// Fetch road-based route (legacy - returns only points)
  /// Use getRouteInfo() for complete data including distance
  static Future<List<LatLng>> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final routeInfo = await getRouteInfo(start: start, end: end);
    return routeInfo.points;
  }
  
  /// Fetch multi-waypoint route WITH distance (Rider → Pickup → Drop)
  static Future<RouteInfo> getMultiWaypointRouteInfo({
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

      print('🗺️ [OSRM] Fetching multi-waypoint route');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          final distanceInMeters = (route['distance'] as num).toDouble();
          final durationInSeconds = (route['duration'] as num).toDouble();
          final coordinates = route['geometry']['coordinates'] as List;
          
          final points = coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();
          
          final routeInfo = RouteInfo(
            points: points,
            distanceInMeters: distanceInMeters,
            durationInSeconds: durationInSeconds,
          );
          
          print('✅ [OSRM] Multi-waypoint route: ${routeInfo}');
          return routeInfo;
        }
      }
      
      // Fallback: calculate combined distance
      final dist1 = _haversineDistance(riderLocation, pickupLocation);
      final dist2 = _haversineDistance(pickupLocation, dropLocation);
      return RouteInfo(
        points: [riderLocation, pickupLocation, dropLocation],
        distanceInMeters: (dist1 + dist2) * 1000,
        durationInSeconds: ((dist1 + dist2) / 25) * 3600, // Assume 25 km/h
      );
      
    } catch (e) {
      print('❌ [OSRM] Multi-waypoint route error: $e');
      final dist1 = _haversineDistance(riderLocation, pickupLocation);
      final dist2 = _haversineDistance(pickupLocation, dropLocation);
      return RouteInfo(
        points: [riderLocation, pickupLocation, dropLocation],
        distanceInMeters: (dist1 + dist2) * 1000,
        durationInSeconds: ((dist1 + dist2) / 25) * 3600,
      );
    }
  }
  
  /// Fetch multi-waypoint route (legacy - returns only points)
  static Future<List<LatLng>> getMultiWaypointRoute({
    required LatLng riderLocation,
    required LatLng pickupLocation,
    required LatLng dropLocation,
  }) async {
    final routeInfo = await getMultiWaypointRouteInfo(
      riderLocation: riderLocation,
      pickupLocation: pickupLocation,
      dropLocation: dropLocation,
    );
    return routeInfo.points;
  }
  
  /// Create fallback route with Haversine distance
  static RouteInfo _createFallbackRoute(LatLng start, LatLng end) {
    final distanceKm = _haversineDistance(start, end);
    return RouteInfo(
      points: [start, end],
      distanceInMeters: distanceKm * 1000,
      durationInSeconds: (distanceKm / 25) * 3600, // Assume 25 km/h average speed
    );
  }
  
  /// Calculate Haversine distance in kilometers
  static double _haversineDistance(LatLng from, LatLng to) {
    const R = 6371; // Earth radius in km
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(_toRadians(from.latitude)) * cos(_toRadians(to.latitude)) *
              sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  
  static double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
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
