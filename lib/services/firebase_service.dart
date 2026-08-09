import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/course_model.dart';
import '../models/attendance_session_model.dart';
import '../models/attendance_record_model.dart';

/// Service class encapsulating database operations with local store fallback.
class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal() {
    _initLocalStore();
  }

  bool _isFirebaseAvailable = false;
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  void setFirebaseAvailable(bool available) {
    _isFirebaseAvailable = available;
  }

  // --- Local Storage Fallback ---
  final Map<String, UserModel> _localUsers = {};
  final Map<String, CourseModel> _localCourses = {};
  final Map<String, AttendanceSessionModel> _localSessions = {};
  final List<AttendanceRecordModel> _localAttendance = [];
  String? _localCurrentUid;

  void _initLocalStore() {
    const defaultStudentUid = 'demo_student_123';
    _localUsers[defaultStudentUid] = UserModel(
      uid: defaultStudentUid,
      name: 'Ahmad Amin',
      studentId: 'SE-2026-4482',
      role: 'student',
    );

    const defaultTeacherUid = 'demo_teacher_456';
    _localUsers[defaultTeacherUid] = UserModel(
      uid: defaultTeacherUid,
      name: 'Dr. Alan Turing (Sir)',
      studentId: 'FAC-1001',
      role: 'teacher',
    );

    // Initial default courses added by Sir
    final now = DateTime.now();
    const defaultCourse1Id = 'course_cs402';
    _localCourses[defaultCourse1Id] = CourseModel(
      courseId: defaultCourse1Id,
      courseCode: 'CS-402',
      courseName: 'Software Engineering',
      teacherId: defaultTeacherUid,
      teacherName: 'Dr. Alan Turing',
      createdAt: now.subtract(const Duration(days: 10)),
    );

    const defaultCourse2Id = 'course_cs301';
    _localCourses[defaultCourse2Id] = CourseModel(
      courseId: defaultCourse2Id,
      courseCode: 'CS-301',
      courseName: 'Database Systems',
      teacherId: defaultTeacherUid,
      teacherName: 'Dr. Alan Turing',
      createdAt: now.subtract(const Duration(days: 5)),
    );

    const defaultSessionId = 'demo_session_1';
    _localSessions[defaultSessionId] = AttendanceSessionModel(
      sessionId: defaultSessionId,
      adminId: defaultTeacherUid,
      qrToken: 'SE_TEST_TOKEN_2026',
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 12)),
      latitude: 0.0,
      longitude: 0.0,
      active: true,
      courseId: defaultCourse1Id,
      courseCode: 'CS-402',
      courseName: 'Software Engineering CS-402',
    );
  }

  User? get currentUser {
    if (_isFirebaseAvailable) {
      try {
        return FirebaseAuth.instance.currentUser;
      } catch (_) {}
    }
    return null;
  }

  String? get currentLocalUid => _localCurrentUid;

  Future<void> signIn(String email, String password) async {
    if (_isFirebaseAvailable) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
        return;
      } catch (e) {
        if (e is! FirebaseAuthException) rethrow;
      }
    }

    if (email.contains('teacher') || email.contains('sir')) {
      _localCurrentUid = 'demo_teacher_456';
    } else {
      _localCurrentUid = 'demo_student_123';
    }

    if (!_localUsers.containsKey(_localCurrentUid)) {
      _localUsers[_localCurrentUid!] = UserModel(
        uid: _localCurrentUid!,
        name: email.split('@').first,
        studentId: _localCurrentUid == 'demo_teacher_456' ? 'FAC-1001' : 'STU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        role: _localCurrentUid == 'demo_teacher_456' ? 'teacher' : 'student',
      );
    }
  }

  Future<void> signOut() async {
    if (_isFirebaseAvailable) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    _localCurrentUid = null;
  }

  Future<UserModel?> getUserData(String uid) async {
    if (_isFirebaseAvailable) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromFirestore(doc);
        }
      } catch (_) {}
    }
    return _localUsers[uid] ?? _localUsers['demo_student_123'];
  }

  // --- Course Operations ---
  Future<CourseModel> createCourse({
    required String courseCode,
    required String courseName,
    required String teacherId,
    required String teacherName,
  }) async {
    final now = DateTime.now();
    final courseId = 'course_${now.millisecondsSinceEpoch}';

    final course = CourseModel(
      courseId: courseId,
      courseCode: courseCode,
      courseName: courseName,
      teacherId: teacherId,
      teacherName: teacherName,
      createdAt: now,
    );

    _localCourses[courseId] = course;

    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance.collection('courses').doc(courseId).set(course.toMap());
      } catch (_) {}
    }

    return course;
  }

  Future<List<CourseModel>> getCourses() async {
    List<CourseModel> courses = [];
    if (_isFirebaseAvailable) {
      try {
        final snapshot = await FirebaseFirestore.instance.collection('courses').get();
        courses = snapshot.docs.map((doc) => CourseModel.fromFirestore(doc)).toList();
      } catch (_) {}
    }

    final existingIds = courses.map((c) => c.courseId).toSet();
    for (var local in _localCourses.values) {
      if (!existingIds.contains(local.courseId)) {
        courses.add(local);
      }
    }

    courses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return courses;
  }

  Future<List<CourseModel>> getCoursesForTeacher(String teacherId) async {
    final allCourses = await getCourses();
    return allCourses.where((c) => c.teacherId == teacherId || teacherId.isEmpty).toList();
  }

  Future<AttendanceSessionModel?> getActiveSessionByToken(String qrToken) async {
    if (_isFirebaseAvailable) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('attendance_sessions')
            .where('qrToken', isEqualTo: qrToken)
            .where('active', isEqualTo: true)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final now = DateTime.now();
          for (var doc in querySnapshot.docs) {
            final session = AttendanceSessionModel.fromFirestore(doc);
            if (session.expiresAt.isAfter(now)) {
              return session;
            }
          }
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    for (var session in _localSessions.values) {
      if (session.qrToken == qrToken && session.active && session.expiresAt.isAfter(now)) {
        return session;
      }
    }
    return null;
  }

  Future<bool> checkDuplicateAttendance(String sessionId, String studentId) async {
    if (_isFirebaseAvailable) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('sessionId', isEqualTo: sessionId)
            .where('studentId', isEqualTo: studentId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          return true;
        }
      } catch (_) {}
    }

    return _localAttendance.any((rec) => rec.sessionId == sessionId && rec.studentId == studentId);
  }

  Future<void> submitAttendance(AttendanceRecordModel record) async {
    _localAttendance.add(record);

    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance.collection('attendance').add(record.toMap());
      } catch (_) {}
    }
  }

  Future<List<AttendanceRecordModel>> getStudentAttendanceHistory(String studentId) async {
    List<AttendanceRecordModel> records = [];

    if (_isFirebaseAvailable) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('studentId', isEqualTo: studentId)
            .get();

        records = querySnapshot.docs
            .map((doc) => AttendanceRecordModel.fromFirestore(doc))
            .toList();
      } catch (_) {}
    }

    final existingIds = records.map((r) => r.sessionId + r.studentId).toSet();
    for (var localRecord in _localAttendance) {
      if (localRecord.studentId == studentId && !existingIds.contains(localRecord.sessionId + localRecord.studentId)) {
        records.add(localRecord);
      }
    }

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  Future<List<AttendanceRecordModel>> getCourseAttendanceHistory(String courseId) async {
    List<AttendanceRecordModel> records = [];

    if (_isFirebaseAvailable) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('courseId', isEqualTo: courseId)
            .get();

        records = querySnapshot.docs
            .map((doc) => AttendanceRecordModel.fromFirestore(doc))
            .toList();
      } catch (_) {}
    }

    for (var localRecord in _localAttendance) {
      if (localRecord.courseId == courseId && !records.any((r) => r.attendanceId == localRecord.attendanceId && r.attendanceId.isNotEmpty)) {
        records.add(localRecord);
      }
    }

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  Future<void> ensureMockStudentUser({
    required String uid,
    required String email,
    required String name,
    required String studentId,
  }) async {
    final userModel = UserModel(
      uid: uid,
      name: name,
      studentId: studentId,
      role: 'student',
    );
    _localUsers[uid] = userModel;

    if (_isFirebaseAvailable) {
      try {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
        final snapshot = await userDoc.get();
        if (!snapshot.exists) {
          await userDoc.set(userModel.toMap());
        }
      } catch (_) {}
    }
  }

  Future<void> ensureMockTeacherUser({
    required String uid,
    required String email,
    required String name,
    required String teacherId,
  }) async {
    final userModel = UserModel(
      uid: uid,
      name: name,
      studentId: teacherId,
      role: 'teacher',
    );
    _localUsers[uid] = userModel;

    if (_isFirebaseAvailable) {
      try {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
        final snapshot = await userDoc.get();
        if (!snapshot.exists) {
          await userDoc.set(userModel.toMap());
        }
      } catch (_) {}
    }
  }

  Future<AttendanceSessionModel> createCourseSession({
    required String courseId,
    required String courseCode,
    required String courseName,
    required String adminId,
    required String qrToken,
    required double latitude,
    required double longitude,
    required Duration duration,
  }) async {
    final now = DateTime.now();
    final sessionId = 'session_${now.millisecondsSinceEpoch}';

    final session = AttendanceSessionModel(
      sessionId: sessionId,
      adminId: adminId,
      qrToken: qrToken,
      createdAt: now,
      expiresAt: now.add(duration),
      latitude: latitude,
      longitude: longitude,
      active: true,
      courseId: courseId,
      courseCode: courseCode,
      courseName: '$courseCode: $courseName',
    );

    _localSessions[sessionId] = session;

    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance.collection('attendance_sessions').doc(sessionId).set(session.toMap());
      } catch (_) {}
    }

    return session;
  }

  Future<String> createMockSession({
    required String qrToken,
    required double latitude,
    required double longitude,
    required Duration duration,
    required String courseName,
    String? courseId,
    String? courseCode,
  }) async {
    final now = DateTime.now();
    final sessionId = 'session_${now.millisecondsSinceEpoch}';

    final session = AttendanceSessionModel(
      sessionId: sessionId,
      adminId: 'admin_demo',
      qrToken: qrToken,
      createdAt: now,
      expiresAt: now.add(duration),
      latitude: latitude,
      longitude: longitude,
      active: true,
      courseId: courseId ?? 'course_cs402',
      courseCode: courseCode ?? 'CS-402',
      courseName: courseName,
    );

    _localSessions[sessionId] = session;

    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance.collection('attendance_sessions').doc(sessionId).set(session.toMap());
      } catch (_) {}
    }

    return sessionId;
  }
}

