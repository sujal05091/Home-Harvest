import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  // TODO: Replace with your Cloudinary credentials
  // Sign up at https://cloudinary.com/ (FREE - no credit card needed)
  // Get credentials from: https://cloudinary.com/console
  static const String CLOUDINARY_CLOUD_NAME = 'dycudtwkj';
  static const String CLOUDINARY_UPLOAD_PRESET = 'home_harvest_preset';
  
  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    CLOUDINARY_CLOUD_NAME,
    CLOUDINARY_UPLOAD_PRESET,
    cache: false,
  );
  final ImagePicker _picker = ImagePicker();

  // Pick image from camera or gallery
  Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  // Pick multiple images
  Future<List<File>> pickMultipleImages({int maxImages = 5}) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isEmpty) return [];

      return images
          .take(maxImages)
          .map((xFile) => File(xFile.path))
          .toList();
    } catch (e) {
      throw Exception('Failed to pick images: $e');
    }
  }

  // Upload dish image to Cloudinary
  Future<String> uploadDishImage(File imageFile, String dishId) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'home_harvest/dishes',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload dish image: $e');
    }
  }

  // Upload verification images to Cloudinary
  Future<List<String>> uploadVerificationImages(
      List<File> imageFiles, String userId) async {
    List<String> imageUrls = [];

    try {
      for (int i = 0; i < imageFiles.length; i++) {
        CloudinaryResponse response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            imageFiles[i].path,
            folder: 'home_harvest/cook_verification/$userId/images',
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        imageUrls.add(response.secureUrl);
      }

      return imageUrls;
    } catch (e) {
      throw Exception('Failed to upload verification images: $e');
    }
  }

  /// Pick a video from gallery (max 60 seconds recommended)
  Future<File?> pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60), // Max 60 seconds
      );

      if (pickedFile != null) {
        File videoFile = File(pickedFile.path);
        
        // Check file size (max 50MB)
        int fileSize = await videoFile.length();
        const int maxSize = 50 * 1024 * 1024; // 50MB in bytes
        
        if (fileSize > maxSize) {
          throw Exception('Video size exceeds 50MB limit. Please select a shorter video.');
        }
        
        return videoFile;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick video: $e');
    }
  }

  /// Upload verification video to Cloudinary (max 50MB)
  Future<String> uploadVerificationVideo(File videoFile, String userId) async {
    try {
      // Verify file size again before upload
      int fileSize = await videoFile.length();
      const int maxSize = 50 * 1024 * 1024; // 50MB
      
      if (fileSize > maxSize) {
        throw Exception('Video size exceeds 50MB limit');
      }

      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          folder: 'home_harvest/cook_verification/$userId/video',
          resourceType: CloudinaryResourceType.Video,
        ),
      );
      
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload verification video: $e');
    }
  }

  // Upload profile image to Cloudinary
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'home_harvest/profiles',
          publicId: userId,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  // Delete image from Cloudinary
  // Note: cloudinary_public package doesn't support delete operation
  // For delete functionality, you would need to use cloudinary package (requires API secret)
  // or implement delete via backend API
  Future<void> deleteImage(String imageUrl) async {
    // Placeholder for delete functionality
    // In production, implement this via a backend endpoint that uses Cloudinary Admin API
    print('Delete image called for: $imageUrl');
    print('Note: Direct delete not supported with unsigned uploads.');
    print('Implement via backend API if needed.');
  }
}
