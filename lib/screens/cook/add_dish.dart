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
  const AddDishScreen({super.key});

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
  bool _isLoading = false;

  final StorageService _storageService = StorageService();

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
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dishesProvider = Provider.of<DishesProvider>(context, listen: false);

      // Generate dish ID
      String dishId = const Uuid().v4();

      print('Starting image upload...');
      // Upload image
      String imageUrl = await _storageService.uploadDishImage(_imageFile!, dishId);
      print('Image uploaded: $imageUrl');

      // Create dish
      final dish = DishModel(
        dishId: dishId,
        cookId: authProvider.currentUser!.uid,
        cookName: authProvider.currentUser!.name,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        ingredients: [],
        allergens: [],
        price: double.parse(_priceController.text),
        imageUrl: imageUrl,
        availableSlots: int.parse(_slotsController.text),
        location: authProvider.currentUser!.location ?? const GeoPoint(0, 0),
        address: authProvider.currentUser!.address ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Adding dish to Firestore...');
      bool success = await dishesProvider.addDish(dish);
      print('Dish added: $success');

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
                  const Text(
                    'Dish Added Successfully!',
                    style: TextStyle(
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Dish')),
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
                            ? Image.file(_imageFile!, fit: BoxFit.cover)
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
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _addDish,
                      child: const Text('Add Dish'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
