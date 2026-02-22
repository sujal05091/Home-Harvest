import 'package:flutter/material.dart';

class FilterPopup extends StatefulWidget {
  final String? initialLocation;
  final String? initialSortBy;
  final List<String>? initialCategories;
  final double? initialMaxPrice;
  final Function(Map<String, dynamic>)? onApplyFilter;

  const FilterPopup({
    super.key,
    this.initialLocation,
    this.initialSortBy,
    this.initialCategories,
    this.initialMaxPrice,
    this.onApplyFilter,
  });

  static void show(
    BuildContext context, {
    String? initialLocation,
    String? initialSortBy,
    List<String>? initialCategories,
    double? initialMaxPrice,
    Function(Map<String, dynamic>)? onApplyFilter,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterPopup(
        initialLocation: initialLocation,
        initialSortBy: initialSortBy,
        initialCategories: initialCategories,
        initialMaxPrice: initialMaxPrice,
        onApplyFilter: onApplyFilter,
      ),
    );
  }

  @override
  State<FilterPopup> createState() => _FilterPopupState();
}

class _FilterPopupState extends State<FilterPopup> {
  final _locationController = TextEditingController();
  String _selectedSortBy = 'recommended';
  final Set<String> _selectedCategories = {};
  double _maxPrice = 500.0;

  final List<Map<String, dynamic>> _sortOptions = [
    {'id': 'recommended', 'label': 'Recommended', 'icon': Icons.local_fire_department, 'color': Colors.orange},
    {'id': 'nearest', 'label': 'Nearest', 'icon': Icons.near_me, 'color': Colors.green},
    {'id': 'fastest', 'label': 'Fastest', 'icon': Icons.electric_bolt, 'color': Colors.amber},
  ];

  final List<Map<String, dynamic>> _categories = [
    {'id': 'breakfast', 'label': 'Breakfast', 'icon': Icons.free_breakfast},
    {'id': 'lunch', 'label': 'Lunch', 'icon': Icons.lunch_dining},
    {'id': 'dinner', 'label': 'Dinner', 'icon': Icons.dinner_dining},
    {'id': 'home-cooked', 'label': 'Home-Cooked', 'icon': Icons.home},
    {'id': 'tiffin', 'label': 'Tiffin Service', 'icon': Icons.food_bank},
    {'id': 'north-indian', 'label': 'North Indian', 'icon': Icons.restaurant},
    {'id': 'south-indian', 'label': 'South Indian', 'icon': Icons.ramen_dining},
    {'id': 'desserts', 'label': 'Desserts', 'icon': Icons.cake},
  ];

  @override
  void initState() {
    super.initState();
    _locationController.text = widget.initialLocation ?? '';
    _selectedSortBy = widget.initialSortBy ?? 'recommended';
    if (widget.initialCategories != null) {
      _selectedCategories.addAll(widget.initialCategories!);
    }
    _maxPrice = widget.initialMaxPrice ?? 500.0;
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final filters = {
      'location': _locationController.text,
      'sortBy': _selectedSortBy,
      'categories': _selectedCategories.toList(),
      'maxPrice': _maxPrice,
    };

    widget.onApplyFilter?.call(filters);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(0, 45, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Location search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Enter your location',
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon: const Icon(Icons.location_on_outlined, size: 24),
                suffixIcon: IconButton(
                  icon: Icon(Icons.my_location, size: 24, color: Colors.grey[600]),
                  onPressed: () {
                    // TODO: Get current location
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFFC8019)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sort by section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: _sortOptions.map((option) {
                    final isSelected = _selectedSortBy == option['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              option['icon'] as IconData,
                              size: 16,
                              color: isSelected ? Colors.white : option['color'] as Color,
                            ),
                            const SizedBox(width: 8),
                            Text(option['label'] as String),
                          ],
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedSortBy = option['id'] as String;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFFFC8019),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFFC8019) : Colors.grey[300]!,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Categories section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = _selectedCategories.contains(category['id']);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category['icon'] as IconData,
                              size: 16,
                              color: isSelected ? Colors.white : const Color(0xFFFC8019),
                            ),
                            const SizedBox(width: 8),
                            Text(category['label'] as String),
                          ],
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategories.add(category['id'] as String);
                            } else {
                              _selectedCategories.remove(category['id']);
                            }
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFFFC8019),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFFC8019) : Colors.grey[300]!,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Price range section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Price Range',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Up to ₹${_maxPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFC8019),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFFFC8019),
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: const Color(0xFFFC8019),
                    overlayColor: const Color(0xFFFC8019).withOpacity(0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _maxPrice,
                    min: 0,
                    max: 1000,
                    divisions: 20,
                    onChanged: (value) {
                      setState(() {
                        _maxPrice = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Apply Filter button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _applyFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC8019),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply Filter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
