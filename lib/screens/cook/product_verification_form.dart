import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/verification_model.dart';
import '../../theme.dart';

/// ?? Product Seller Verification Form
/// Collects workplace info, images/video, FSSAI number, and special products.
class ProductVerificationFormScreen extends StatefulWidget {
  const ProductVerificationFormScreen({super.key});

  @override
  State<ProductVerificationFormScreen> createState() =>
      _ProductVerificationFormScreenState();
}

class _ProductVerificationFormScreenState
    extends State<ProductVerificationFormScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _formKey = GlobalKey<FormState>();

  final _workplaceNameCtrl = TextEditingController();
  final _workplaceAddressCtrl = TextEditingController();
  final _fssaiCtrl = TextEditingController();
  final _productTagCtrl = TextEditingController();
  final _ingredientTagCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  List<File> _workplaceImages = [];
  File? _workplaceVideo;
  List<String> _specialProducts = [];
  List<String> _ingredientsUsed = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _workplaceNameCtrl.dispose();
    _workplaceAddressCtrl.dispose();
    _fssaiCtrl.dispose();
    _productTagCtrl.dispose();
    _ingredientTagCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  // --- Media pickers -----------------------------------------------------

  Future<void> _pickImages() async {
    final images = await _storageService.pickMultipleImages(maxImages: 10);
    setState(() => _workplaceImages = images);
  }

  Future<void> _pickVideo() async {
    final video = await _storageService.pickVideo();
    setState(() => _workplaceVideo = video);
  }

  // --- Product tag helpers ------------------------------------------------

  void _addProduct() {
    final v = _productTagCtrl.text.trim();
    if (v.isNotEmpty && !_specialProducts.contains(v)) {
      setState(() {
        _specialProducts.add(v);
        _productTagCtrl.clear();
      });
    }
  }

  void _removeProduct(String p) =>
      setState(() => _specialProducts.remove(p));

  void _addIngredient() {
    final v = _ingredientTagCtrl.text.trim();
    if (v.isNotEmpty && !_ingredientsUsed.contains(v)) {
      setState(() {
        _ingredientsUsed.add(v);
        _ingredientTagCtrl.clear();
      });
    }
  }

  void _removeIngredient(String i) =>
      setState(() => _ingredientsUsed.remove(i));

  // --- Submit -------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_workplaceImages.isEmpty) {
      _showError('Please upload at least one workplace photo');
      return;
    }
    if (_specialProducts.isEmpty) {
      _showError('Please add at least one product (e.g. Pickle, Masala)');
      return;
    }
    if (_ingredientsUsed.isEmpty) {
      _showError('Please add at least one ingredient used');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser!.uid;

      final imageUrls = await _storageService.uploadVerificationImages(
          _workplaceImages, uid);

      String? videoUrl;
      if (_workplaceVideo != null) {
        videoUrl =
            await _storageService.uploadVerificationVideo(_workplaceVideo!, uid);
      }

      final model = ProductVerificationModel(
        verificationId: const Uuid().v4(),
        sellerId: uid,
        sellerName: auth.currentUser!.name,
        sellerEmail: auth.currentUser!.email,
        sellerPhone: auth.currentUser!.phone,
        workplaceName: _workplaceNameCtrl.text.trim(),
        workplaceAddress: _workplaceAddressCtrl.text.trim(),
        workplaceImages: imageUrls,
        workplaceVideoUrl: videoUrl,
        specialProducts: _specialProducts,
        ingredientsUsed: _ingredientsUsed,
        experienceYears: int.tryParse(_experienceCtrl.text.trim()) ?? 0,
        fssaiNumber: _fssaiCtrl.text.trim().isEmpty
            ? null
            : _fssaiCtrl.text.trim(),
        status: VerificationStatus.PENDING,
        createdAt: DateTime.now(),
      );

      await _firestoreService.submitProductVerification(model);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('? Product verification submitted! Awaiting admin approval.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to submit: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Seller Verification'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
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
              _buildWorkplaceDetails(),
              const SizedBox(height: 20),
              _buildMediaSection(),
              const SizedBox(height: 20),
              _buildProductsSection(),
              const SizedBox(height: 20),
              _buildIngredientsSection(),
              const SizedBox(height: 20),
              _buildExperienceSection(),
              const SizedBox(height: 20),
              _buildFssaiSection(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Verification Process',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800])),
            ]),
            const SizedBox(height: 8),
            Text(
              '� Upload photos & video of your preparation workplace\n'
              '� List all products you sell (pickles, masala, etc.)\n'
              '� Add ingredients you use in your products\n'
              '� Mention years of experience\n'
              '� FSSAI number is strongly recommended\n'
              '� Review takes 24�48 hours',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkplaceDetails() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('?? Workplace Details',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _workplaceNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Workplace / Brand Name *',
                hintText: "e.g., Amma's Pickles",
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Workplace name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _workplaceAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Workplace Address *',
                hintText: 'Full address with area / locality',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Workplace address is required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('?? Workplace Photos & Video',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Show your clean and hygienic preparation area.',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 16),

            // Photos
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo_library),
              label: Text(
                _workplaceImages.isEmpty
                    ? 'Upload Workplace Photos *'
                    : '${_workplaceImages.length} photo(s) selected ?',
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _workplaceImages.isEmpty
                      ? Colors.orange
                      : Colors.green,
                ),
                foregroundColor: _workplaceImages.isEmpty
                    ? Colors.orange
                    : Colors.green,
              ),
            ),
            if (_workplaceImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _workplaceImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_workplaceImages[i],
                        width: 80, height: 80, fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Video
            OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.videocam),
              label: Text(
                _workplaceVideo == null
                    ? 'Upload Workplace Video (Recommended)'
                    : 'Video selected ?',
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: _workplaceVideo == null
                        ? Colors.grey
                        : Colors.green),
                foregroundColor: _workplaceVideo == null
                    ? Colors.grey[700]
                    : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('?? Products You Sell *',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('e.g. Pickle, Masala, Papad, Sweets, Herbal Powder �',
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _productTagCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Type a product',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onFieldSubmitted: (_) => _addProduct(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_specialProducts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _specialProducts
                    .map((p) => Chip(
                          label: Text(p),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeProduct(p),
                          backgroundColor:
                              const Color(0xFFFC8019).withOpacity(0.12),
                          labelStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFFFC8019)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('?? Ingredients Used *',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('e.g. Turmeric, Mustard Oil, Rock Salt, Vinegar �',
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ingredientTagCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Type an ingredient',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onFieldSubmitted: (_) => _addIngredient(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addIngredient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_ingredientsUsed.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ingredientsUsed
                    .map((i) => Chip(
                          label: Text(i),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeIngredient(i),
                          backgroundColor: Colors.green.withOpacity(0.12),
                          labelStyle: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.green[700]),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('? Experience',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _experienceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Years of Experience Making These Products',
                hintText: 'e.g. 5',
                prefixIcon: Icon(Icons.workspace_premium_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFssaiSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('?? FSSAI Certification',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Strongly recommended for home food product sellers.',
              style:
                  GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fssaiCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'FSSAI Certificate Number (Optional)',
                prefixIcon: Icon(Icons.verified_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:
            GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
          : const Text('Submit for Verification'),
    );
  }
}
