import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import '../../models/address_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import 'select_location_map_osm.dart'; // NEW OpenStreetMap version

class AddAddressScreen extends StatefulWidget {
  final AddressModel? existingAddress;

  const AddAddressScreen({super.key, this.existingAddress});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullAddressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();

  String _selectedLabel = 'Home';
  bool _isDefault = false;
  bool _isLoading = false;
  GeoPoint? _location;

  @override
  void initState() {
    super.initState();
    if (widget.existingAddress != null) {
      _loadExistingAddress();
    }
  }

  void _loadExistingAddress() {
    final address = widget.existingAddress!;
    _fullAddressController.text = address.fullAddress;
    _landmarkController.text = address.landmark;
    _cityController.text = address.city;
    _stateController.text = address.state;
    _pincodeController.text = address.pincode;
    _contactNameController.text = address.contactName;
    _contactPhoneController.text = address.contactPhone;
    _selectedLabel = address.label;
    _isDefault = address.isDefault;
    _location = address.location;
  }

  @override
  void dispose() {
    _fullAddressController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      Position? position = await _locationService.getCurrentLocation();
      if (position != null) {
        _location = GeoPoint(position.latitude, position.longitude);

        // Reverse geocode to get address
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          setState(() {
            _fullAddressController.text =
                '${place.street}, ${place.subLocality}, ${place.locality}';
            _cityController.text = place.locality ?? '';
            _stateController.text = place.administrativeArea ?? '';
            _pincodeController.text = place.postalCode ?? '';
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location fetched successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🗺️ SELECT LOCATION ON MAP
  Future<void> _selectOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectLocationMapScreen(
          initialLocation: _location,
          initialAddress: _fullAddressController.text,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final GeoPoint location = result['location'];
      final String address = result['address'];

      setState(() {
        _location = location;
        
        // Parse address into fields (basic parsing)
        final parts = address.split(', ');
        if (parts.length >= 3) {
          _fullAddressController.text = parts.take(2).join(', ');
          _cityController.text = parts.length > 2 ? parts[2] : '';
          _stateController.text = parts.length > 3 ? parts[3] : '';
          _pincodeController.text = parts.length > 4 ? parts[4] : '';
        } else {
          _fullAddressController.text = address;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location selected from map')),
        );
      }
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please get current location first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final address = AddressModel(
        addressId: widget.existingAddress?.addressId ?? const Uuid().v4(),
        userId: authProvider.currentUser!.uid,
        label: _selectedLabel,
        fullAddress: _fullAddressController.text.trim(),
        landmark: _landmarkController.text.trim(),
        location: _location!,
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        contactName: _contactNameController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
        isDefault: _isDefault,
        createdAt: widget.existingAddress?.createdAt ?? DateTime.now(),
      );

      await _firestoreService.saveAddress(address);

      if (mounted) {
        Navigator.pop(context, address);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving address: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingAddress == null ? 'Add Address' : 'Edit Address'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Location Selection Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Current Location'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectOnMap,
                            icon: const Icon(Icons.map),
                            label: const Text('Select on Map'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    if (_location != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Location set: ${_location!.latitude.toStringAsFixed(6)}, ${_location!.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 20),

                    // Address Type Selection
                    const Text('Address Type', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Home', 'Office', 'Other'].map((label) {
                        return ChoiceChip(
                          label: Text(label),
                          selected: _selectedLabel == label,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedLabel = label);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Full Address
                    TextFormField(
                      controller: _fullAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Full Address',
                        hintText: 'House No, Building Name, Street Name',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Landmark
                    TextFormField(
                      controller: _landmarkController,
                      decoration: const InputDecoration(
                        labelText: 'Landmark (Optional)',
                        hintText: 'Near famous location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // City
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter city';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // State and Pincode Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'State required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _pincodeController,
                            decoration: const InputDecoration(
                              labelText: 'Pincode',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              if (value.length != 6) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Contact Name
                    TextFormField(
                      controller: _contactNameController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter contact name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contact Phone
                    TextFormField(
                      controller: _contactPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone',
                        border: OutlineInputBorder(),
                        prefixText: '+91 ',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (value.length != 10) {
                          return 'Invalid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Set as Default
                    CheckboxListTile(
                      title: const Text('Set as default address'),
                      value: _isDefault,
                      onChanged: (value) => setState(() => _isDefault = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton(
                      onPressed: _saveAddress,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: const Color(0xFFFC8019),
                      ),
                      child: const Text(
                        'Save Address',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
