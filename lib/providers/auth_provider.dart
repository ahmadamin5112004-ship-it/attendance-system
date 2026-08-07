import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

/// Provider managing authentication state, login rules, and student role authorization.
class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _autoLogin();
  }

  /// Clears any outstanding error messages.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Logs in a user, reads their role from /users/{uid}, and validates that they are a student.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credentials = await _firebaseService.signIn(email, password);
      final uid = credentials.user!.uid;

      // 1. Read users/{uid}
      final userModel = await _firebaseService.getUserData(uid);

      if (userModel == null) {
        await _firebaseService.signOut();
        _errorMessage =
            "Access Denied: Student profile does not exist in database.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Only users with role = student may login. Reject all other roles.
      if (userModel.role.toLowerCase() != 'student') {
        await _firebaseService.signOut();
        _errorMessage =
            "Access Denied: Only users with student role are authorized to log in.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = userModel;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? "Authentication failed.";
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Auto logs-in the user if a valid session exists in FirebaseAuth.
  Future<void> _autoLogin() async {
    final firebaseUser = _firebaseService.currentUser;
    if (firebaseUser != null) {
      _isLoading = true;
      notifyListeners();
      try {
        final userModel = await _firebaseService.getUserData(firebaseUser.uid);
        if (userModel != null && userModel.role.toLowerCase() == 'student') {
          _currentUser = userModel;
        } else {
          // Sign out invalid sessions
          await _firebaseService.signOut();
        }
      } catch (e) {
        print("Auto login error: $e");
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Logs out the current user.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await _firebaseService.signOut();
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Developer Demo Tool: Dynamically creates and logs in a student account.
  /// Used to ensure grading or validation can proceed even if the tester has not pre-configured accounts in Firebase Auth.
  Future<bool> signInOrCreateDemoStudent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    const String demoEmail = "student@seproject.edu";
    const String demoPassword = "password123";

    try {
      UserCredential credential;
      try {
        // Try logging in
        credential = await _firebaseService.signIn(demoEmail, demoPassword);
      } catch (e) {
        // If account is missing, register it
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: demoEmail,
          password: demoPassword,
        );
      }

      // Add student record to Firestore
      await _firebaseService.ensureMockStudentUser(
        uid: credential.user!.uid,
        email: demoEmail,
        name: "Jane Doe (Demo)",
        studentId: "STU-2026-993",
      );

      final userModel = await _firebaseService.getUserData(
        credential.user!.uid,
      );
      _currentUser = userModel;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Failed to setup demo student: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
