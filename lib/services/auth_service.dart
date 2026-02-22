import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
    String? role,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        final userData = await getUserData(user.uid);
        
        // Check if role matches (if role is provided)
        if (userData != null && role != null && userData.role != role) {
          // Sign out the user since role doesn't match
          await _auth.signOut();
          throw Exception(
            'This email is registered as a ${userData.role}, not a $role.\n\n'
            'Please select the correct role or use a different account.'
          );
        }
        
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
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      if (e.code == 'wrong-password') {
        // Check available sign-in methods for this email
        try {
          final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
          print('Available sign-in methods for $email: $signInMethods');
          
          if (signInMethods.contains('google.com')) {
            throw Exception(
              'This email is linked to Google Sign-In.\n\n'
              'Please use the "Continue with Google" button to login.'
            );
          }
        } catch (fetchError) {
          print('Error fetching sign-in methods: $fetchError');
        }
        
        throw Exception(
          'Incorrect password.\n\n'
          'Please check your password and try again.'
        );
      } else if (e.code == 'user-not-found') {
        throw Exception('No account found with this email.\n\nPlease sign up first.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address.');
      } else if (e.code == 'user-disabled') {
        throw Exception('This account has been disabled.');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many login attempts. Please try again later.');
      } else if (e.code == 'invalid-credential') {
        throw Exception('Invalid email or password.\n\nPlease check your credentials.');
      }
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      print('Error during sign in: $e');
      rethrow;
    }
    return null;
  }

  // Sign in with Google
  Future<UserModel?> signInWithGoogle({required String role}) async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        // Check if user already exists in Firestore
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (userDoc.exists) {
          // Existing user - check if role matches
          UserModel? existingUser = await getUserData(user.uid);
          if (existingUser != null && existingUser.role != role) {
            // Sign out the user since role doesn't match
            await _googleSignIn.signOut();
            await _auth.signOut();
            throw Exception(
              'This Google account is already registered as a ${existingUser.role}.\n\n'
              'Please use a different Google account for ${role} access, or login with email/password.'
            );
          }
          return existingUser;
        } else {
          // New user - create a document with Google info
          UserModel newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            phone: user.phoneNumber ?? '',
            name: user.displayName ?? 'User',
            role: role,
            verified: role == 'customer', // Auto-verify customers, cooks need verification
            photoUrl: user.photoURL,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          Map<String, dynamic> userMap = newUser.toMap();
          
          // Set isOnline: false for riders initially
          if (role == 'rider') {
            userMap['isOnline'] = false;
          }

          await _firestore.collection('users').doc(user.uid).set(userMap);
          return newUser;
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error during Google sign in: ${e.code} - ${e.message}');
      throw Exception('Google Sign-In failed: ${e.message}');
    } catch (e) {
      print('Error during Google sign in: $e');
      
      // Check for specific Google Sign-In API errors
      if (e.toString().contains('ApiException: 10')) {
        throw Exception(
          'Google Sign-In not configured properly.\n\n'
          'Please contact app support or try email login instead.'
        );
      } else if (e.toString().contains('sign_in_failed')) {
        throw Exception(
          'Google Sign-In failed.\n'
          'Please check your internet connection and try again.'
        );
      } else if (e.toString().contains('network_error')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      
      throw Exception('Google Sign-In failed. Please try again or use email login.');
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
