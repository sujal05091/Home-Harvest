import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Create user document in Firestore
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          phone: phone,
          name: name,
          role: role,
          verified: false, // Cooks need verification
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        Map<String, dynamic> userMap = newUser.toMap();
        
        // 🚴 Set isOnline: false for riders initially
        if (role == 'rider') {
          userMap['isOnline'] = false;
        }

        await _firestore.collection('users').doc(user.uid).set(userMap);
        return newUser;
      }
    } catch (e) {
      print('Error during signup: $e');
      rethrow;
    }
    return null;
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        final userData = await getUserData(user.uid);
        
        // 🚴 If rider is logging in, set them as online automatically
        if (userData != null && userData.role == 'rider') {
          await _firestore.collection('users').doc(user.uid).update({
            'isOnline': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('✅ Rider set to ONLINE status on login');
        }
        
        return userData;
      }
    } catch (e) {
      print('Error during sign in: $e');
      rethrow;
    }
    return null;
  }

  // Sign in with phone number (OTP)
  // TODO: Implement phone authentication flow
  Future<void> signInWithPhone(String phoneNumber) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        print('Phone verification failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        // Store verificationId for later use
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  // Update user data
  Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }

  // Update FCM token
  Future<void> updateFCMToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    // 🚴 Set rider to offline before signing out
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userData = await getUserData(user.uid);
        if (userData != null && userData.role == 'rider') {
          await _firestore.collection('users').doc(user.uid).update({
            'isOnline': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('✅ Rider set to OFFLINE status on logout');
        }
      } catch (e) {
        print('⚠️ Error updating online status during logout: $e');
      }
    }
    
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow;
    }
  }
}
