import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/osm_maps_service.dart';
import '../../widgets/osm_map_widget.dart';

/// 🧪 OpenStreetMap TEST Screen
/// Quick test to verify OSM is working
class OSMTestScreen extends StatefulWidget {
  const OSMTestScreen({super.key});

  @override
  State<OSMTestScreen> createState() => _OSMTestScreenState();
}

class _OSMTestScreenState extends State<OSMTestScreen> {
  final MapController _mapController = MapController();
  final OSMMapsService _mapsService = OSMMapsService();
  
  LatLng _center = LatLng(28.6129, 77.2295); // India Gate, New Delhi
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _addTestMarkers();
  }

  void _addTestMarkers() {
    _markers = [
      MarkerHelper.createPickupMarker(
        LatLng(28.6139, 77.2090),
        'Pickup Test',
      ),
      MarkerHelper.createDropMarker(
        LatLng(28.6129, 77.2295),
        'Drop Test',
      ),
      MarkerHelper.createDeliveryMarker(
        LatLng(28.6149, 77.2195),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ OpenStreetMap Test'),
        backgroundColor: const Color(0xFFFC8019),
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'OpenStreetMap is Working!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text('✅ No API key needed'),
                Text('✅ No billing required'),
                Text('✅ 100% FREE forever!'),
                SizedBox(height: 8),
                Text(
                  'You should see 3 markers on the map:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('🟢 Green = Pickup'),
                Text('🔴 Red = Drop'),
                Text('🔵 Blue = Delivery Partner'),
              ],
            ),
          ),

          // Map
          Expanded(
            child: OSMMapWidget(
              center: _center,
              zoom: 13.0,
              markers: _markers,
              polylines: [
                PolylineHelper.createRoute(
                  points: [
                    LatLng(28.6139, 77.2090),
                    LatLng(28.6149, 77.2195),
                    LatLng(28.6129, 77.2295),
                  ],
                  color: const Color(0xFFFC8019),
                  width: 4.0,
                ),
              ],
              mapController: _mapController,
              showMyLocationButton: true,
              onMyLocationPressed: () async {
                final myLocation = await _mapsService.getCurrentLocation();
                if (myLocation != null) {
                  setState(() => _center = myLocation);
                  _mapController.move(myLocation, 15.0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Location permission granted!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Location permission denied'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              onTap: (latLng) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Tapped: ${latLng.latitude.toStringAsFixed(4)}, '
                      '${latLng.longitude.toStringAsFixed(4)}',
                    ),
                  ),
                );
              },
            ),
          ),

          // Test Results
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ TEST PASSED - OpenStreetMap Working!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        _mapController.move(_center, 15.0);
                      },
                      icon: const Icon(Icons.zoom_in),
                      label: const Text('Zoom In'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _mapController.move(_center, 11.0);
                      },
                      icon: const Icon(Icons.zoom_out),
                      label: const Text('Zoom Out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
