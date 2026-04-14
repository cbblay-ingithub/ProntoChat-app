import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class CloudStorageService {
  static final CloudStorageService instance = CloudStorageService._internal();
  
  late final FirebaseStorage _storage;
  
  // Collection paths
  final String _profileImagesPath = 'profile_images';
  
  CloudStorageService._internal() {
    _storage = FirebaseStorage.instance;
  }
  
  /// Upload user profile image
  /// Returns the download URL of the uploaded image
  Future<String> uploadUserImage(String uid, File image) async {
    try {
      // Create a reference to the location in Firebase Storage
      Reference storageRef = _storage.ref().child(_profileImagesPath).child('$uid.jpg');
      
      // Upload the file
      TaskSnapshot uploadTask = await storageRef.putFile(image);
      
      // Get the download URL
      String downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print("Image uploaded successfully for user: $uid");
      return downloadUrl;
    } catch (e) {
      print("Error uploading user image: $e");
      rethrow; // Rethrow to handle in the calling function
    }
  }
  
  /// Upload user profile image with custom file name
  Future<String> uploadUserImageWithCustomName(String uid, File image, {String? fileName}) async {
    try {
      String finalFileName = fileName ?? '$uid.jpg';
      Reference storageRef = _storage.ref().child(_profileImagesPath).child(finalFileName);
      
      // Add metadata (optional)
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uid': uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      TaskSnapshot uploadTask = await storageRef.putFile(image, metadata);
      String downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print("Image uploaded successfully: $finalFileName");
      return downloadUrl;
    } catch (e) {
      print("Error uploading user image: $e");
      rethrow;
    }
  }
  
  /// Get download URL for existing user image
  Future<String?> getUserImageUrl(String uid) async {
    try {
      Reference storageRef = _storage.ref().child(_profileImagesPath).child('$uid.jpg');
      String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error getting user image URL: $e");
      return null; // Return null if image doesn't exist
    }
  }
  
  /// Delete user image
  Future<void> deleteUserImage(String uid) async {
    try {
      Reference storageRef = _storage.ref().child(_profileImagesPath).child('$uid.jpg');
      await storageRef.delete();
      print("Image deleted successfully for user: $uid");
    } catch (e) {
      print("Error deleting user image: $e");
      rethrow;
    }
  }
  
  /// Update user image (delete old, upload new)
  Future<String> updateUserImage(String uid, File newImage) async {
    try {
      // Delete old image if exists
      try {
        await deleteUserImage(uid);
      } catch (e) {
        print("No existing image to delete or error deleting: $e");
      }
      
      // Upload new image
      return await uploadUserImage(uid, newImage);
    } catch (e) {
      print("Error updating user image: $e");
      rethrow;
    }
  }
  
  /// Compress and upload image (optional - requires flutter_image_compress package)
  Future<String> uploadCompressedImage(String uid, File image) async {
    try {
      // Note: You'll need to add flutter_image_compress package for this
      // For now, this is a placeholder
      return await uploadUserImage(uid, image);
    } catch (e) {
      print("Error uploading compressed image: $e");
      rethrow;
    }
  }
}