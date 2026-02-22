import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/verification_model.dart';
import '../../theme.dart';

/// ✅ PROFESSIONAL Cook Verification Form
/// Collects all required information for cook verification
class CookVerificationFormScreen extends StatefulWidget {
  const CookVerificationFormScreen({super.key});

  @override
  State<CookVerificationFormScreen> createState() => _CookVerificationFormScreenState();
}

class _CookVerificationFormScreenState extends State<CookVerificationFormScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _kitchenNameController = TextEditingController();
  final _kitchenAddressController = TextEditingController();
  final _experienceController = TextEditingController();
  final _fssaiController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _specialityController = TextEditingController();
  
  // Form state
  List<File> _kitchenImages = [];
  File? _kitchenVideo;
  String _cookingType = 'Both'; // Veg / Non-Veg / Both
  List<String> _ingredientsList = [];
  List<String> _specialityList = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _kitchenNameController.dispose();
    _kitchenAddressController.dispose();
    _experienceController.dispose();
    _fssaiController.dispose();
    _ingredientsController.dispose();
    _specialityController.dispose();
    super.dispose();
  }

  // ========================================
  // 📷 MEDIA PICKERS
  // ========================================
  
  Future<void> _pickKitchenImages() async {
    try {
      final images = await _storageService.pickMultipleImages(maxImages: 10);
      setState(() => _kitchenImages = images);
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  Future<void> _pickKitchenVideo() async {
    try {
      final video = await _storageService.pickVideo();
      setState(() => _kitchenVideo = video);
    } catch (e) {
      _showError('Failed to pick video: $e');
    }
  }

  // ========================================
  // ✅ SUBMIT VERIFICATION
  // ========================================
  
  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill all required fields');
      return;
    }

    if (_kitchenImages.isEmpty) {
      _showError('Please upload at least one kitchen photo');
      return;
    }

    if (_ingredientsList.isEmpty) {
      _showError('Please add at least one ingredient');
      return;
    }

    if (_specialityList.isEmpty) {
      _showError('Please add at least one speciality dish');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser!.uid;

      // ⏳ Upload kitchen images
      List<String> kitchenImageUrls = await _storageService.uploadVerificationImages(
        _kitchenImages,
        userId,
      );

      // ⏳ Upload kitchen video (if provided)
      String? videoUrl;
      if (_kitchenVideo != null) {
        videoUrl = await _storageService.uploadVerificationVideo(_kitchenVideo!, userId);
      }

      // ✅ Create verification document
      final verification = VerificationModel(
        verificationId: const Uuid().v4(),
        cookId: userId,
        cookName: authProvider.currentUser!.name,
        cookEmail: authProvider.currentUser!.email,
        cookPhone: authProvider.currentUser!.phone,
        
        // Enhanced fields
        kitchenName: _kitchenNameController.text.trim(),
        kitchenAddress: _kitchenAddressController.text.trim(),
        kitchenImages: kitchenImageUrls,
        kitchenVideoUrl: videoUrl,
        ingredientsUsed: _ingredientsList,
        cookingType: _cookingType,
        experienceYears: int.tryParse(_experienceController.text) ?? 0,
        specialityDishes: _specialityList,
        fssaiNumber: _fssaiController.text.trim().isEmpty 
            ? null 
            : _fssaiController.text.trim(),
        
        // Legacy fields (kept for backward compatibility)
        images: kitchenImageUrls,
        description: 'Kitchen: ${_kitchenNameController.text}',
        hygieneChecklist: {},
        
        // Status
        status: VerificationStatus.PENDING, // ✅ ALWAYS PENDING
        createdAt: DateTime.now(),
      );

      // ✅ Submit to Firestore (auto-updates user verificationStatus to PENDING)
      await _firestoreService.submitVerification(verification);

      if (mounted) {
        // ✅ Show success and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Verification submitted! Awaiting admin approval'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to submit: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ========================================
  // 🎨 UI BUILDERS
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cook Verification'),
        backgroundColor: AppTheme.primaryOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 20),
              _buildKitchenDetailsSection(),
              const SizedBox(height: 20),
              _buildMediaSection(),
              const SizedBox(height: 20),
              _buildIngredientsSection(),
              const SizedBox(height: 20),
              _buildExperienceSection(),
              const SizedBox(height: 20),
              _buildSpecialitySection(),
              const SizedBox(height: 20),
              _buildFSSAISection(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Info card explaining the process
  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Verification Process',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '• Your verification will be reviewed by our admin team\n'
              '• Required: Kitchen photos, ingredients, specialities\n'
              '• Optional: Kitchen video, FSSAI certificate\n'
              '• You can start adding dishes only after approval',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  /// Kitchen name and address
  Widget _buildKitchenDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🏠 Kitchen Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kitchenNameController,
              decoration: const InputDecoration(
                labelText: 'Kitchen Name *',
                hintText: 'e.g., Mom\'s Kitchen',
                prefixIcon: Icon(Icons.kitchen),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true 
                  ? 'Kitchen name is required' 
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kitchenAddressController,
              decoration: const InputDecoration(
                labelText: 'Kitchen Address *',
                hintText: 'Full address with area/locality',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) => value?.isEmpty ?? true 
                  ? 'Kitchen address is required' 
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Kitchen photos and video upload
  Widget _buildMediaSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📷 Kitchen Photos & Video',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload clear photos of your kitchen setup',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Kitchen Images Button
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _pickKitchenImages,
              icon: const Icon(Icons.add_a_photo),
              label: Text('Add Kitchen Photos (${_kitchenImages.length})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            // Kitchen Images Preview
            if (_kitchenImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kitchenImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _kitchenImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _kitchenImages.removeAt(index));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Kitchen Video Button
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _pickKitchenVideo,
              icon: const Icon(Icons.videocam),
              label: Text(_kitchenVideo == null 
                  ? 'Add Kitchen Video (Optional)' 
                  : '✓ Video Added'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kitchenVideo == null 
                    ? Colors.grey 
                    : Colors.green,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '⏱️ Max 60 seconds, Max 50MB',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// Ingredients input
  Widget _buildIngredientsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🥗 Ingredients Used',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add ingredients you commonly use (e.g., tomato, onion, rice)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ingredientsController,
                    decoration: const InputDecoration(
                      hintText: 'Enter ingredient name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addIngredient(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addIngredient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ingredientsList.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _ingredientsList.remove(ingredient));
                  },
                  backgroundColor: Colors.green[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _addIngredient() {
    final ingredient = _ingredientsController.text.trim();
    if (ingredient.isNotEmpty && !_ingredientsList.contains(ingredient)) {
      setState(() {
        _ingredientsList.add(ingredient);
        _ingredientsController.clear();
      });
    }
  }

  /// Experience and cooking type
  Widget _buildExperienceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👨‍🍳 Experience & Cooking Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _experienceController,
              decoration: const InputDecoration(
                labelText: 'Experience (Years) *',
                hintText: 'e.g., 5',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) => value?.isEmpty ?? true 
                  ? 'Experience is required' 
                  : null,
            ),
            const SizedBox(height: 16),
            const Text(
              'Cooking Type *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCookingTypeChip('Veg', Icons.eco),
                const SizedBox(width: 8),
                _buildCookingTypeChip('Non-Veg', Icons.restaurant_menu),
                const SizedBox(width: 8),
                _buildCookingTypeChip('Both', Icons.fastfood),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCookingTypeChip(String type, IconData icon) {
    final isSelected = _cookingType == type;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(type),
        ],
      ),
      onSelected: (_) {
        setState(() => _cookingType = type);
      },
      selectedColor: AppTheme.primaryOrange,
      checkmarkColor: Colors.white,
    );
  }

  /// Speciality dishes
  Widget _buildSpecialitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⭐ Speciality Dishes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'What dishes are you best at? (e.g., Biryani, Pasta)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _specialityController,
                    decoration: const InputDecoration(
                      hintText: 'Enter dish name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addSpeciality(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addSpeciality,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _specialityList.map((dish) {
                return Chip(
                  label: Text(dish),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _specialityList.remove(dish));
                  },
                  backgroundColor: Colors.orange[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _addSpeciality() {
    final dish = _specialityController.text.trim();
    if (dish.isNotEmpty && !_specialityList.contains(dish)) {
      setState(() {
        _specialityList.add(dish);
        _specialityController.clear();
      });
    }
  }

  /// FSSAI certificate (optional)
  Widget _buildFSSAISection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📋 FSSAI Certificate (Optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Food Safety and Standards Authority of India license',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fssaiController,
              decoration: const InputDecoration(
                labelText: 'FSSAI Number',
                hintText: '14-digit license number',
                prefixIcon: Icon(Icons.verified_user),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  /// Submit button
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitVerification,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryOrange,
        padding: const EdgeInsets.all(16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text('Submit for Verification'),
    );
  }
}
