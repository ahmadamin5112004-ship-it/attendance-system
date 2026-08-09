import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/course_model.dart';
import '../models/attendance_session_model.dart';
import '../models/attendance_record_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';

/// Provider handling Courses, QR validation, distance computation, duplicate checks, and submission logs.
class AttendanceProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final LocationService _locationService = LocationService();

  List<CourseModel> _courses = [];
  bool _isLoadingCourses = false;

  List<AttendanceRecordModel> _history = [];
  List<AttendanceRecordModel> _courseAttendanceHistory = [];
  bool _isLoadingHistory = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<CourseModel> get courses => _courses;
  bool get isLoadingCourses => _isLoadingCourses;

  List<AttendanceRecordModel> get history => _history;
  List<AttendanceRecordModel> get courseAttendanceHistory => _courseAttendanceHistory;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadCourses({String teacherId = ''}) async {
    _isLoadingCourses = true;
    notifyListeners();
    try {
      _courses = await _attendanceService.getCoursesForTeacher(teacherId);
    } catch (e) {
      _errorMessage = "Failed to load courses: ${e.toString()}";
    } finally {
      _isLoadingCourses = false;
      notifyListeners();
    }
  }

  Future<CourseModel?> addCourse({
    required String courseCode,
    required String courseName,
    required String teacherId,
    required String teacherName,
  }) async {
    _errorMessage = null;
    try {
      final newCourse = await _attendanceService.createCourse(
        courseCode: courseCode,
        courseName: courseName,
        teacherId: teacherId,
        teacherName: teacherName,
      );
      await loadCourses(teacherId: teacherId);
      return newCourse;
    } catch (e) {
      _errorMessage = "Failed to create course: ${e.toString()}";
      notifyListeners();
      return null;
    }
  }

  Future<AttendanceSessionModel?> startCourseSession({
    required CourseModel course,
    required String adminId,
    required Duration duration,
  }) async {
    _errorMessage = null;
    try {
      final position = await _locationService.getCurrentLocation();
      final String qrToken = "COURSE_${course.courseCode}_${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}";

      final session = await _attendanceService.createCourseSession(
        courseId: course.courseId,
        courseCode: course.courseCode,
        courseName: course.courseName,
        adminId: adminId,
        qrToken: qrToken,
        latitude: position.latitude,
        longitude: position.longitude,
        duration: duration,
      );
      notifyListeners();
      return session;
    } catch (e) {
      _errorMessage = "Failed to start attendance session: ${e.toString()}";
      notifyListeners();
      return null;
    }
  }

  Future<void> loadCourseAttendanceHistory(String courseId) async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      _courseAttendanceHistory = await _attendanceService.getCourseAttendanceHistory(courseId);
    } catch (e) {
      _errorMessage = "Failed to load course attendance: ${e.toString()}";
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
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
        throw "Invalid or expired QR code.";
      }

      if (session.expiresAt.isBefore(DateTime.now())) {
        throw "Attendance session has expired.";
      }

      final bool isDuplicate = await _attendanceService.checkDuplicateAttendance(
        session.sessionId,
        student.studentId,
      );

      if (isDuplicate) {
        throw "Attendance already submitted for this session.";
      }

      final double distance = _locationService.calculateDistance(
        startLatitude: session.latitude,
        startLongitude: session.longitude,
        endLatitude: studentLatitude,
        endLongitude: studentLongitude,
      );

      final record = AttendanceRecordModel(
        attendanceId: 'att_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: session.sessionId,
        studentId: student.studentId,
        studentName: student.name,
        timestamp: DateTime.now(),
        distance: distance,
        courseId: session.courseId,
        courseCode: session.courseCode,
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
