import 'package:flutter/material.dart';
import '../../models/cook_profile_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_router.dart';

class CooksDiscoveryScreen extends StatefulWidget {
  const CooksDiscoveryScreen({super.key});

  @override
  State<CooksDiscoveryScreen> createState() => _CooksDiscoveryScreenState();
}

class _CooksDiscoveryScreenState extends State<CooksDiscoveryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<CookProfileModel> _cooks = [];
  List<CookProfileModel> _filteredCooks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // Filters
  bool _vegOnly = false;
  double _maxDistance = 10.0; // km
  double _minRating = 0.0;
  String? _selectedSpecialty;
  
  final List<String> _specialties = [
    'All',
    'North Indian',
    'South Indian',
    'Chinese',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Vegan',
    'Desserts'
  ];

  @override
  void initState() {
    super.initState();
    _loadCooks();
  }

  Future<void> _loadCooks() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userLocation = authProvider.currentUser?.location;
      
      // Get all verified cooks from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'cook')
          .where('verified', isEqualTo: true)
          .get();

      _cooks = snapshot.docs
          .map((doc) => CookProfileModel.fromMap(doc.data(), doc.id))
          .toList();

      // Calculate distances if user location is available
      if (userLocation != null) {
        for (var cook in _cooks) {
          final distance = cook.distanceFrom(userLocation);
          // Store distance for sorting
        }
      }

      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cooks: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredCooks = _cooks.where((cook) {
        // Search query filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesName = cook.name.toLowerCase().contains(query);
          final matchesSpecialty = cook.specialties.any(
            (s) => s.toLowerCase().contains(query),
          );
          if (!matchesName && !matchesSpecialty) return false;
        }

        // Veg filter
        if (_vegOnly && !cook.isVeg) return false;

        // Rating filter
        if (cook.rating < _minRating) return false;

        // Specialty filter
        if (_selectedSpecialty != null && _selectedSpecialty != 'All') {
          if (!cook.specialties.contains(_selectedSpecialty)) return false;
        }

        // Distance filter (if location available)
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser?.location != null) {
          final distance = cook.distanceFrom(authProvider.currentUser!.location);
          if (distance != null && distance > _maxDistance) return false;
        }

        return true;
      }).toList();

      // Sort by rating
      _filteredCooks.sort((a, b) => b.rating.compareTo(a.rating));
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _vegOnly = false;
                        _maxDistance = 10.0;
                        _minRating = 0.0;
                        _selectedSpecialty = null;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Veg Only Toggle
              SwitchListTile(
                title: const Text('Pure Veg Only'),
                value: _vegOnly,
                activeColor: const Color(0xFF60B246),
                onChanged: (value) {
                  setModalState(() => _vegOnly = value);
                },
              ),
              const Divider(),
              
              // Rating Filter
              const Text('Minimum Rating', style: TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _minRating,
                min: 0,
                max: 5,
                divisions: 10,
                label: _minRating.toStringAsFixed(1),
                activeColor: const Color(0xFFFC8019),
                onChanged: (value) {
                  setModalState(() => _minRating = value);
                },
              ),
              
              // Distance Filter
              const Text('Maximum Distance (km)', style: TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _maxDistance,
                min: 1,
                max: 20,
                divisions: 19,
                label: '${_maxDistance.toInt()} km',
                activeColor: const Color(0xFFFC8019),
                onChanged: (value) {
                  setModalState(() => _maxDistance = value);
                },
              ),
              
              // Specialty Filter
              const SizedBox(height: 10),
              const Text('Specialty', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _specialties.map((specialty) {
                  final isSelected = _selectedSpecialty == specialty;
                  return ChoiceChip(
                    label: Text(specialty),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFC8019),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    onSelected: (selected) {
                      setModalState(() {
                        _selectedSpecialty = selected ? specialty : null;
                      });
                    },
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC8019),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userLocation = authProvider.currentUser?.location;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Home Cooks'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search cooks or cuisines...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: _showFilterBottomSheet,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Active Filters Chips
          if (_vegOnly || _minRating > 0 || _selectedSpecialty != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_vegOnly)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: const Text('Pure Veg'),
                          backgroundColor: Colors.green.shade100,
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _vegOnly = false;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                    if (_minRating > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('${_minRating.toStringAsFixed(1)}+ ⭐'),
                          backgroundColor: Colors.orange.shade100,
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _minRating = 0;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                    if (_selectedSpecialty != null && _selectedSpecialty != 'All')
                      Chip(
                        label: Text(_selectedSpecialty!),
                        backgroundColor: Colors.blue.shade100,
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _selectedSpecialty = null;
                            _applyFilters();
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_filteredCooks.length} cooks found',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Cooks List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Lottie.asset(
                      'assets/lottie/loading_auth.json',
                      width: 100,
                      height: 100,
                    ),
                  )
                : _filteredCooks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/lottie/cheff_cooking.json',
                              width: 200,
                              height: 200,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No cooks match your filters',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _vegOnly = false;
                                  _maxDistance = 10.0;
                                  _minRating = 0.0;
                                  _selectedSpecialty = null;
                                  _applyFilters();
                                });
                              },
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCooks,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredCooks.length,
                          itemBuilder: (context, index) {
                            final cook = _filteredCooks[index];
                            final distance = userLocation != null
                                ? cook.distanceFrom(userLocation)
                                : null;

                            return _CookCard(
                              cook: cook,
                              distance: distance,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CookCard extends StatelessWidget {
  final CookProfileModel cook;
  final double? distance;

  const _CookCard({
    required this.cook,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to cook detail screen with menu
          Navigator.pushNamed(
            context,
            AppRouter.customerHome, // Temporary - will create CookDetailScreen
            arguments: {'cookId': cook.cookId},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cook Header with Photo
            ListTile(
              leading: CircleAvatar(
                radius: 30,
                backgroundImage: cook.photoUrl != null
                    ? NetworkImage(cook.photoUrl!)
                    : null,
                child: cook.photoUrl == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      cook.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (cook.verified)
                    const Icon(
                      Icons.verified,
                      color: Colors.blue,
                      size: 18,
                    ),
                  if (cook.isVeg)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VEG',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${cook.rating.toStringAsFixed(1)} (${cook.totalReviews})',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (distance != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on, color: Colors.grey, size: 16),
                        const SizedBox(width: 4),
                        Text('${distance!.toStringAsFixed(1)} km'),
                      ],
                    ],
                  ),
                  if (cook.avgPricePerMeal != null)
                    Text(
                      '₹${cook.avgPricePerMeal!.toInt()} avg per meal',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.favorite_border),
                color: Colors.red,
                onPressed: () {
                  // TODO: Implement add to favorites
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to favorites')),
                  );
                },
              ),
            ),

            // Bio
            if (cook.bio != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  cook.bio!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Specialties
            if (cook.specialties.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cook.specialties.take(4).map((specialty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        specialty,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    icon: Icons.restaurant_menu,
                    label: 'Orders',
                    value: cook.totalOrders.toString(),
                  ),
                  _StatItem(
                    icon: Icons.schedule,
                    label: 'Member',
                    value: _formatJoinDate(cook.joinedAt),
                  ),
                  _StatItem(
                    icon: Icons.check_circle,
                    label: 'Status',
                    value: cook.isAvailable ? 'Available' : 'Busy',
                    valueColor: cook.isAvailable ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatJoinDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays < 30) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}m';
    } else {
      return '${(difference.inDays / 365).floor()}y';
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor ?? Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
