import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

/// Provider managing authentication state, student role verification, and offline fallback login.
class AuthProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _autoLogin();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _attendanceService.signIn(email, password);
      final uid = _attendanceService.currentUser?.uid ?? _attendanceService.currentLocalUid ?? 'demo_student_123';

      final userModel = await _attendanceService.getUserData(uid);

      if (userModel == null) {
        await _attendanceService.signOut();
        _errorMessage = "Access Denied: Student profile does not exist in database.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (userModel.role.toLowerCase() != 'student') {
        await _attendanceService.signOut();
        _errorMessage = "Access Denied: Only users with student role are authorized to log in.";
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

  Future<void> _autoLogin() async {
    final firebaseUser = _attendanceService.currentUser;
    final uid = firebaseUser?.uid ?? _attendanceService.currentLocalUid;
    if (uid != null) {
      _isLoading = true;
      notifyListeners();
      try {
        final userModel = await _attendanceService.getUserData(uid);
        if (userModel != null && userModel.role.toLowerCase() == 'student') {
          _currentUser = userModel;
        }
      } catch (e) {
        print("Auto login error: $e");
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await _attendanceService.signOut();
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signInOrCreateDemoStudent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    const String demoEmail = "student@seproject.edu";
    const String demoPassword = "password123";

    try {
      await _attendanceService.signIn(demoEmail, demoPassword);
      final uid = _attendanceService.currentUser?.uid ?? _attendanceService.currentLocalUid ?? 'demo_student_123';

      await _attendanceService.ensureMockStudentUser(
        uid: uid,
        email: demoEmail,
        name: "Jane Doe (Demo)",
        studentId: "STU-2026-993",
      );

      final userModel = await _attendanceService.getUserData(uid);
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
