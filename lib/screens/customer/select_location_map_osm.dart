import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/osm_maps_service.dart';
import '../../widgets/osm_map_widget.dart';

/// 📍 LOCATION PICKER with OpenStreetMap (FREE!)
/// 
/// Features:
/// - Tap anywhere to select location
/// - Search address using geocoding
/// - Get current location
/// - Reverse geocoding (lat/lng to address)
/// - Returns GeoPoint + full address
class SelectLocationMapScreen extends StatefulWidget {
  final GeoPoint? initialLocation;
  final String? initialAddress;

  const SelectLocationMapScreen({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<SelectLocationMapScreen> createState() => _SelectLocationMapScreenState();
}

class _SelectLocationMapScreenState extends State<SelectLocationMapScreen> {
  final OSMMapsService _mapsService = OSMMapsService();
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = true;
  List<Location> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLocation != null) {
      // Use provided location
      setState(() {
        _selectedLocation = LatLng(
          widget.initialLocation!.latitude,
          widget.initialLocation!.longitude,
        );
        _selectedAddress = widget.initialAddress ?? '';
        _isLoadingLocation = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_selectedLocation!, 15.0);
      });
    } else {
      // Get current location
      final currentLocation = await _mapsService.getCurrentLocation();
      if (currentLocation != null) {
        setState(() {
          _selectedLocation = currentLocation;
          _isLoadingLocation = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(currentLocation, 15.0);
        });
        _getAddressFromLatLng(currentLocation);
      } else {
        // Default to India Gate, New Delhi
        setState(() {
          _selectedLocation = LatLng(28.6129, 77.2295);
          _isLoadingLocation = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_selectedLocation!, 13.0);
        });
      }
    }
  }

  /// Reverse geocoding: LatLng → Address
  Future<void> _getAddressFromLatLng(LatLng location) async {
    setState(() => _isLoadingAddress = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      debugPrint('📍 Placemarks count: ${placemarks.length}');
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        
        // Debug: Print all available fields
        debugPrint('🏠 Name: ${place.name}');
        debugPrint('🏠 Street: ${place.street}');
        debugPrint('🏠 SubLocality: ${place.subLocality}');
        debugPrint('🏠 Locality: ${place.locality}');
        debugPrint('🏠 SubAdminArea: ${place.subAdministrativeArea}');
        debugPrint('🏠 AdminArea: ${place.administrativeArea}');
        debugPrint('🏠 PostalCode: ${place.postalCode}');
        debugPrint('🏠 Country: ${place.country}');
        
        // Build address from available components
        List<String> addressParts = [];
        
        // Add name if it's a named location (like a business or landmark)
        if (place.name != null && place.name!.isNotEmpty && place.name != place.street) {
          addressParts.add(place.name!);
        }
        
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty && place.subAdministrativeArea != place.locality) {
          addressParts.add(place.subAdministrativeArea!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }
        
        debugPrint('✅ Address parts: $addressParts');
        
        setState(() {
          _selectedAddress = addressParts.isNotEmpty 
              ? addressParts.join(', ')
              : 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';
        });
      } else {
        debugPrint('❌ No placemarks found');
        setState(() {
          _selectedAddress = 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (e) {
      debugPrint('❌ Error getting address: $e');
      setState(() {
        _selectedAddress = 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';
      });
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }

  /// Forward geocoding: Address → LatLng
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(query);
      setState(() {
        _searchResults = locations;
        _showSearchResults = true;
      });
    } catch (e) {
      print('Error searching location: $e');
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not found')),
      );
    }
  }

  /// Select location from search results
  void _selectSearchResult(Location location) {
    final latLng = LatLng(location.latitude, location.longitude);
    setState(() {
      _selectedLocation = latLng;
      _showSearchResults = false;
      _searchController.clear();
    });
    _mapController.move(latLng, 16.0);
    _getAddressFromLatLng(latLng);
  }

  /// Save and return selected location
  void _saveLocation() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    Navigator.pop(context, {
      'location': GeoPoint(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      ),
      'address': _selectedAddress.isNotEmpty 
          ? _selectedAddress 
          : 'Location: ${_selectedLocation!.latitude.toStringAsFixed(4)}, '
            '${_selectedLocation!.longitude.toStringAsFixed(4)}',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          TextButton(
            onPressed: _saveLocation,
            child: const Text(
              'SAVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 🗺️ OpenStreetMap (FREE!)
                OSMMapWidget(
                  center: _selectedLocation!,
                  zoom: 15.0,
                  mapController: _mapController,
                  markers: [], // Remove markers, we'll use a center pin instead
                  onTap: (latLng) {
                    setState(() => _selectedLocation = latLng);
                    _getAddressFromLatLng(latLng);
                  },
                  showMyLocationButton: true,
                  onMyLocationPressed: () async {
                    final myLocation = await _mapsService.getCurrentLocation();
                    if (myLocation != null) {
                      setState(() => _selectedLocation = myLocation);
                      _mapController.move(myLocation, 16.0);
                      _getAddressFromLatLng(myLocation);
                    }
                  },
                  onPositionChanged: (camera, hasGesture) {
                    // Update location as user drags the map
                    if (hasGesture) {
                      final center = camera.center;
                      if (_selectedLocation != center) {
                        setState(() => _selectedLocation = center);
                        // Debounce address fetching to avoid too many requests
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_selectedLocation == center) {
                            _getAddressFromLatLng(center);
                          }
                        });
                      }
                    }
                  },
                ),

                // Center Pin (Fixed position that stays in center as map moves)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 50,
                        color: Color(0xFFFC8019),
                      ),
                      // Shadow/dot under pin
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search location...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                        _showSearchResults = false;
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            if (value.length > 3) {
                              _searchLocation(value);
                            }
                          },
                          onSubmitted: _searchLocation,
                        ),
                      ),

                      // Search Results Dropdown
                      if (_showSearchResults && _searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final location = _searchResults[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on),
                                title: Text(
                                  'Lat: ${location.latitude.toStringAsFixed(4)}, '
                                  'Lng: ${location.longitude.toStringAsFixed(4)}',
                                ),
                                onTap: () => _selectSearchResult(location),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                // Selected Address Card
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFFFC8019),
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Selected Location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_isLoadingAddress)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedAddress.isNotEmpty
                                ? _selectedAddress
                                : 'Drag map to select location',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (_selectedLocation != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                              'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveLocation,
                              icon: const Icon(Icons.check),
                              label: const Text('Confirm Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFC8019),
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
