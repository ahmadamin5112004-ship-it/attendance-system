import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/attendance_session_model.dart';
import '../models/attendance_record_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';

/// Provider handling QR validation, distance computation, duplicate checks, and submission logs.
class AttendanceProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final LocationService _locationService = LocationService();

  List<AttendanceRecordModel> _history = [];
  bool _isLoadingHistory = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<AttendanceRecordModel> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadAttendanceHistory(String studentId) async {
    _isLoadingHistory = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _history = await _attendanceService.getStudentAttendanceHistory(studentId);
    } catch (e) {
      _errorMessage = "Failed to load history: ${e.toString()}";
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<bool> scanAndSubmitAttendance({
    required String qrToken,
    required UserModel student,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final position = await _locationService.getCurrentLocation();
      final double studentLatitude = position.latitude;
      final double studentLongitude = position.longitude;

      final session = await _attendanceService.getActiveSessionByToken(qrToken);

      if (session == null) {
        throw "Invalid QR";
      }

      if (session.expiresAt.isBefore(DateTime.now())) {
        throw "Invalid QR";
      }

      final bool isDuplicate = await _attendanceService.checkDuplicateAttendance(
        session.sessionId,
        student.studentId,
      );

      if (isDuplicate) {
        throw "Attendance already submitted.";
      }

      final double distance = _locationService.calculateDistance(
        startLatitude: session.latitude,
        startLongitude: session.longitude,
        endLatitude: studentLatitude,
        endLongitude: studentLongitude,
      );

      final record = AttendanceRecordModel(
        attendanceId: '',
        sessionId: session.sessionId,
        studentId: student.studentId,
        studentName: student.name,
        timestamp: DateTime.now(),
        distance: distance,
        courseName: session.courseName,
      );

      await _attendanceService.submitAttendance(record);

      await loadAttendanceHistory(student.studentId);

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<String> createDebugSession({
    required String qrToken,
    required double latitude,
    required double longitude,
    required String courseName,
  }) async {
    return await _attendanceService.createMockSession(
      qrToken: qrToken,
      latitude: latitude,
      longitude: longitude,
      duration: const Duration(hours: 12),
      courseName: courseName,
    );
  }
}
