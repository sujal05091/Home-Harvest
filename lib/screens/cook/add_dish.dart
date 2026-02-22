import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:lottie/lottie.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dishes_provider.dart';
import '../../services/storage_service.dart';
import '../../models/dish_model.dart';
import 'dart:io';

class AddDishScreen extends StatefulWidget {
  final DishModel? dishToEdit; // Optional: If provided, screen is in edit mode
  
  const AddDishScreen({super.key, this.dishToEdit});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _slotsController = TextEditingController();
  File? _imageFile;
  String? _existingImageUrl; // For edit mode
  bool _isLoading = false;
  bool get _isEditMode => widget.dishToEdit != null;
  
  // Category selection
  final Set<String> _selectedCategories = {};
  final List<Map<String, dynamic>> _availableCategories = [
    {'id': 'breakfast', 'label': 'Breakfast', 'icon': Icons.free_breakfast},
    {'id': 'lunch', 'label': 'Lunch', 'icon': Icons.lunch_dining},
    {'id': 'dinner', 'label': 'Dinner', 'icon': Icons.dinner_dining},
    {'id': 'vegetarian', 'label': 'Vegetarian', 'icon': Icons.eco},
    {'id': 'non-vegetarian', 'label': 'Non-Veg', 'icon': Icons.restaurant_menu},
    {'id': 'snacks', 'label': 'Snacks', 'icon': Icons.fastfood},
    {'id': 'desserts', 'label': 'Desserts', 'icon': Icons.cake},
    {'id': 'beverages', 'label': 'Beverages', 'icon': Icons.local_drink},
  ];

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    // Pre-fill form if editing
    if (_isEditMode && widget.dishToEdit != null) {
      final dish = widget.dishToEdit!;
      _titleController.text = dish.title;
      _descController.text = dish.description ?? '';
      _priceController.text = dish.price.toString();
      _slotsController.text = dish.availableSlots.toString();
      _existingImageUrl = dish.imageUrl;
      _selectedCategories.addAll(dish.categories ?? []);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _slotsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _storageService.pickImage();
    if (file != null) {
      setState(() => _imageFile = file);
    }
  }

  Future<void> _addDish() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Image required for new dishes, optional for edits
    if (_imageFile == null && !_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dishesProvider = Provider.of<DishesProvider>(context, listen: false);

      // Use existing ID when editing, generate new when creating
      String dishId = _isEditMode ? widget.dishToEdit!.dishId : const Uuid().v4();

      // Upload new image if selected, otherwise use existing
      String imageUrl = _existingImageUrl ?? '';
      if (_imageFile != null) {
        print('Starting image upload...');
        imageUrl = await _storageService.uploadDishImage(_imageFile!, dishId);
        print('Image uploaded: $imageUrl');
      }

      // ⚠️ CRITICAL: Validate cook has a proper location set
      final cookLocation = authProvider.currentUser!.location;
      if (cookLocation == null || (cookLocation.latitude == 0 && cookLocation.longitude == 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please set your restaurant address in Profile before adding dishes!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isLoading = false);
        return; // Stop dish creation
      }

      // Create or update dish
      final dish = DishModel(
        dishId: dishId,
        cookId: authProvider.currentUser!.uid,
        cookName: authProvider.currentUser!.name,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        ingredients: _isEditMode ? widget.dishToEdit!.ingredients : [],
        allergens: _isEditMode ? widget.dishToEdit!.allergens : [],
        categories: _selectedCategories.toList(),
        price: double.parse(_priceController.text),
        imageUrl: imageUrl,
        availableSlots: int.parse(_slotsController.text),
        isAvailable: _isEditMode ? widget.dishToEdit!.isAvailable : true,
        location: cookLocation,
        address: authProvider.currentUser!.address ?? '',
        createdAt: _isEditMode ? widget.dishToEdit!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print(_isEditMode ? 'Updating dish...' : 'Adding dish to Firestore...');
      bool success = _isEditMode 
          ? await dishesProvider.updateDish(dish)
          : await dishesProvider.addDish(dish);
      print(_isEditMode ? 'Dish updated: $success' : 'Dish added: $success');

      if (success && mounted) {
        // Show success dialog with animation
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/lottie/order_placed.json',
                    width: 150,
                    height: 150,
                    repeat: false,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isEditMode ? 'Dish Updated Successfully!' : 'Dish Added Successfully!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
        
        // Auto close dialog and navigate back after animation
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context); // Go back to dashboard
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add dish. Please try again.')),
        );
      }
    } catch (e) {
      print('Error adding dish: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // 🐛 DEBUG: Print verification status
    print('🔍 DEBUG - Cook Verification Check:');
    print('   verificationStatus: ${authProvider.currentUser?.verificationStatus}');
    print('   verified: ${authProvider.currentUser?.verified}');
    print('   Will block? ${authProvider.currentUser?.verificationStatus != 'APPROVED' && authProvider.currentUser?.verified != true}');
    
    // ✅ VERIFICATION CHECK: Block access if not approved
    if (authProvider.currentUser?.verificationStatus != 'APPROVED' && 
        authProvider.currentUser?.verified != true) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditMode ? 'Edit Dish' : 'Add Dish')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verification Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  authProvider.currentUser?.verificationStatus == 'PENDING'
                      ? 'Your verification is pending admin approval.\nYou cannot add dishes until approved.'
                      : authProvider.currentUser?.verificationStatus == 'REJECTED'
                          ? 'Your verification was rejected.\nPlease resubmit your verification.'
                          : 'Please complete your cook verification\nto start adding dishes.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/cook/verification-status');
                    },
                    icon: const Icon(Icons.verified_user),
                    label: Text(
                      authProvider.currentUser?.verificationStatus == 'PENDING'
                          ? 'View Status'
                          : 'Complete Verification',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // ✅ APPROVED: Show add dish form
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Dish' : 'Add Dish')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_imageFile!, fit: BoxFit.cover),
                              )
                            : _existingImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _existingImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_a_photo, size: 50),
                                            SizedBox(height: 10),
                                            Text('Tap to change image'),
                                          ],
                                        );
                                      },
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, size: 50),
                                      SizedBox(height: 10),
                                  Text('Add dish photo'),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Dish Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price (₹)'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _slotsController,
                      decoration: const InputDecoration(labelText: 'Available Slots'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    
                    // Category Selection
                    const Text(
                      'Select Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableCategories.map((category) {
                        final isSelected = _selectedCategories.contains(category['id']);
                        return FilterChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                category['icon'] as IconData,
                                size: 16,
                                color: isSelected ? Colors.white : const Color(0xFFFC8019),
                              ),
                              const SizedBox(width: 6),
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
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFFFC8019) : Colors.grey[300]!,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        );
                      }).toList(),
                    ),
                    if (_selectedCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Please select at least one category',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _addDish,
                      child: Text(_isEditMode ? 'Update Dish' : 'Add Dish'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
