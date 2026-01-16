import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/verification_model.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() => _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final _descController = TextEditingController();

  List<File> _selectedImages = [];
  bool _isSubmitting = false;

  Map<String, bool> _checklist = {
    'cleanKitchen': false,
    'properStorage': false,
    'handWashing': false,
    'freshIngredients': false,
  };

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _storageService.pickMultipleImages(maxImages: 5);
    setState(() => _selectedImages = images);
  }

  Future<void> _submitVerification() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one photo')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Upload images
      List<String> imageUrls = await _storageService.uploadVerificationImages(
        _selectedImages,
        authProvider.currentUser!.uid,
      );

      // Create verification document
      final verification = VerificationModel(
        verificationId: const Uuid().v4(),
        cookId: authProvider.currentUser!.uid,
        cookName: authProvider.currentUser!.name,
        cookEmail: authProvider.currentUser!.email,
        cookPhone: authProvider.currentUser!.phone,
        images: imageUrls,
        description: _descController.text.trim(),
        hygieneChecklist: _checklist,
        status: VerificationStatus.PENDING,
        createdAt: DateTime.now(),
      );

      await _firestoreService.submitVerification(verification);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification submitted! Awaiting admin approval')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cook Verification')),
      body: StreamBuilder<VerificationModel?>(
        stream: _firestoreService.getCookVerification(authProvider.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final verification = snapshot.data!;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      verification.status == VerificationStatus.APPROVED
                          ? Icons.check_circle
                          : verification.status == VerificationStatus.REJECTED
                              ? Icons.cancel
                              : Icons.pending,
                      size: 100,
                      color: verification.status == VerificationStatus.APPROVED
                          ? Colors.green
                          : verification.status == VerificationStatus.REJECTED
                              ? Colors.red
                              : Colors.orange,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      verification.status.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    if (verification.adminNotes != null) ...[
                      const SizedBox(height: 20),
                      Text('Admin Notes: ${verification.adminNotes}'),
                    ],
                  ],
                ),
              ),
            );
          }

          // Show verification form
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Submit Verification Documents',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_a_photo),
                  label: Text('Add Photos (${_selectedImages.length}/5)'),
                ),
                const SizedBox(height: 20),
                if (_selectedImages.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Image.file(_selectedImages[index], width: 100, fit: BoxFit.cover),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Tell us about your kitchen and cooking experience',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                const Text('Hygiene Checklist:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._checklist.keys.map((key) {
                  return CheckboxListTile(
                    title: Text(key),
                    value: _checklist[key],
                    onChanged: (val) => setState(() => _checklist[key] = val!),
                  );
                }),
                const SizedBox(height: 30),
                _isSubmitting
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submitVerification,
                        child: const Text('Submit for Verification'),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
