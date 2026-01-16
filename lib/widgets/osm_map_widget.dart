import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Reusable OpenStreetMap Widget
class OSMMapWidget extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final Function(LatLng)? onTap;
  final Function(LatLng)? onLongPress;
  final bool showMyLocationButton;
  final VoidCallback? onMyLocationPressed;
  final MapController? mapController;

  const OSMMapWidget({
    super.key,
    required this.center,
    this.zoom = 13.0,
    this.markers = const [],
    this.polylines = const [],
    this.onTap,
    this.onLongPress,
    this.showMyLocationButton = false,
    this.onMyLocationPressed,
    this.mapController,
  });

  @override
  State<OSMMapWidget> createState() => _OSMMapWidgetState();
}

class _OSMMapWidgetState extends State<OSMMapWidget> {
  late MapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.mapController ?? MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            onTap: widget.onTap != null
                ? (tapPosition, latLng) => widget.onTap!(latLng)
                : null,
            onLongPress: widget.onLongPress != null
                ? (tapPosition, latLng) => widget.onLongPress!(latLng)
                : null,
          ),
          children: [
            // CartoDB Positron tiles (Clean & Professional)
            TileLayer(
              urlTemplate: 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.homeharvest.app',
              tileProvider: NetworkTileProvider(),
            ),

            // Polyline Layer (routes)
            if (widget.polylines.isNotEmpty)
              PolylineLayer(polylines: widget.polylines),

            // Marker Layer
            if (widget.markers.isNotEmpty)
              MarkerLayer(markers: widget.markers),
          ],
        ),

        // My Location Button
        if (widget.showMyLocationButton && widget.onMyLocationPressed != null)
          Positioned(
            bottom: 100,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              shadowColor: Colors.black26,
              child: InkWell(
                onTap: widget.onMyLocationPressed,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFC8019), Color(0xFFFF9F40)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFC8019).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),

        // Zoom Controls
        Positioned(
          bottom: 20,
          right: 16,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildZoomButton(
                    icon: Icons.add_rounded,
                    onPressed: () {
                      _controller.move(
                        _controller.camera.center,
                        _controller.camera.zoom + 1,
                      );
                    },
                    isTop: true,
                  ),
                  Container(height: 1, color: Colors.grey.shade200),
                  _buildZoomButton(
                    icon: Icons.remove_rounded,
                    onPressed: () {
                      _controller.move(
                        _controller.camera.center,
                        _controller.camera.zoom - 1,
                      );
                    },
                    isTop: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Modern Zoom Button Widget
  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isTop,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.vertical(
        top: isTop ? const Radius.circular(16) : Radius.zero,
        bottom: !isTop ? const Radius.circular(16) : Radius.zero,
      ),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: Colors.grey.shade700,
          size: 24,
        ),
      ),
    );
  }
}

/// Helper to create custom markers
class MarkerHelper {
  /// Create delivery partner marker (bike icon with pulse animation)
  static Marker createDeliveryMarker(LatLng position) {
    return Marker(
      point: position,
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse circles
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2196F3).withOpacity(0.2),
            ),
          ),
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2196F3).withOpacity(0.3),
            ),
          ),
          // Main marker
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  /// Create pickup marker (restaurant icon)
  static Marker createPickupMarker(LatLng position, String label) {
    return Marker(
      point: position,
      width: 80,
      height: 100,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  /// Create drop marker (home location)
  static Marker createDropMarker(LatLng position, String label) {
    return Marker(
      point: position,
      width: 80,
      height: 100,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFC8019),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFC8019), Color(0xFFFF6B35)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFC8019).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(
              Icons.home_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  /// Create draggable pin marker
  static Marker createDraggablePin(LatLng position) {
    return Marker(
      point: position,
      width: 40,
      height: 40,
      child: const Icon(
        Icons.location_on,
        color: Colors.red,
        size: 40,
      ),
    );
  }
}

/// Helper to create polylines
class PolylineHelper {
  /// Create route polyline
  static Polyline createRoute({
    required List<LatLng> points,
    Color color = const Color(0xFFFC8019),
    double width = 5.0,
  }) {
    return Polyline(
      points: points,
      color: color,
      strokeWidth: width,
      strokeCap: StrokeCap.round,
      strokeJoin: StrokeJoin.round,
      borderColor: Colors.white,
      borderStrokeWidth: 2.0,
      gradientColors: [
        color.withOpacity(0.7),
        color,
        color,
      ],
    );
  }
}
