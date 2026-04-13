import 'package:cloud_firestore/cloud_firestore.dart';

class DBService {
  // Singleton instance
  static final DBService instance = DBService._internal();
  
  late final FirebaseFirestore _db;
  
  // Private constructor
  DBService._internal() {
    _db = FirebaseFirestore.instance;
  }
  
  // Collection name
  final String _userCollection = 'Users';
  
  /// Create a new user document in Firestore
  Future<void> createUserInDB(String uid, String name, String email, String imageURL) async {
    try {
      await _db.collection(_userCollection).doc(uid).set({
        "name": name,
        "email": email,
        "image": imageURL,
        "lastSeen": DateTime.now().toUtc(),
        "createdAt": DateTime.now().toUtc(),
      });
      print("User created successfully in Firestore: $uid");
    } catch (e) {
      print("Error creating user in Firestore: $e");
      rethrow; // Rethrow to handle in the calling function
    }
  }
  
  /// Get user data by UID
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection(_userCollection).doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error getting user data: $e");
      return null;
    }
  }
  
  /// Update user data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection(_userCollection).doc(uid).update(data);
      print("User data updated successfully: $uid");
    } catch (e) {
      print("Error updating user data: $e");
      rethrow;
    }
  }
  
  /// Update user's last seen timestamp
  Future<void> updateLastSeen(String uid) async {
    try {
      await _db.collection(_userCollection).doc(uid).update({
        "lastSeen": DateTime.now().toUtc(),
      });
    } catch (e) {
      print("Error updating last seen: $e");
    }
  }
  
  /// Delete user document (use with caution)
  Future<void> deleteUser(String uid) async {
    try {
      await _db.collection(_userCollection).doc(uid).delete();
      print("User deleted successfully: $uid");
    } catch (e) {
      print("Error deleting user: $e");
      rethrow;
    }
  }
}