import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
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
  final Map<String, AttendanceSessionModel> _localSessions = {};
  final List<AttendanceRecordModel> _localAttendance = [];
  String? _localCurrentUid;

  void _initLocalStore() {
    const defaultUid = 'demo_student_123';
    _localUsers[defaultUid] = UserModel(
      uid: defaultUid,
      name: 'Ahmad Amin',
      studentId: 'SE-2026-4482',
      role: 'student',
    );

    final now = DateTime.now();
    const defaultSessionId = 'demo_session_1';
    _localSessions[defaultSessionId] = AttendanceSessionModel(
      sessionId: defaultSessionId,
      adminId: 'admin_1',
      qrToken: 'SE_TEST_TOKEN_2026',
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 12)),
      latitude: 0.0,
      longitude: 0.0,
      active: true,
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

    _localCurrentUid = 'demo_student_123';
    if (!_localUsers.containsKey(_localCurrentUid)) {
      _localUsers[_localCurrentUid!] = UserModel(
        uid: _localCurrentUid!,
        name: email.split('@').first,
        studentId: 'STU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        role: 'student',
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

    final existingIds = records.map((r) => r.sessionId).toSet();
    for (var localRecord in _localAttendance) {
      if (localRecord.studentId == studentId && !existingIds.contains(localRecord.sessionId)) {
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

  Future<String> createMockSession({
    required String qrToken,
    required double latitude,
    required double longitude,
    required Duration duration,
    required String courseName,
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
