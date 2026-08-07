import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/attendance_session_model.dart';
import '../models/attendance_record_model.dart';

/// Service class to encapsulate Firebase Auth and Firestore interactions.
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the current Firebase User, if signed in.
  User? get currentUser => _auth.currentUser;

  /// Authenticates user using Email and Password.
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetches the user data from Firestore using the user's [uid].
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      // Re-throw to be caught and parsed in UI / Provider
      rethrow;
    }
  }

  /// Retrieves an active session matching the scanned [qrToken] that has not expired yet.
  /// To avoid requiring the developer to setup composite indexes in Firestore,
  /// we query by [qrToken] and [active] state, and perform the timestamp validation check locally.
  Future<AttendanceSessionModel?> getActiveSessionByToken(
    String qrToken,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance_sessions')
          .where('qrToken', isEqualTo: qrToken)
          .where('active', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final now = DateTime.now();
      for (var doc in querySnapshot.docs) {
        final session = AttendanceSessionModel.fromFirestore(doc);
        // Validate if session is still active and has not expired
        if (session.expiresAt.isAfter(now)) {
          return session;
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Checks if an attendance record has already been logged for the given session and student.
  Future<bool> checkDuplicateAttendance(
    String sessionId,
    String studentId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('sessionId', isEqualTo: sessionId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  /// Submits a student attendance record to Firestore.
  Future<void> submitAttendance(AttendanceRecordModel record) async {
    try {
      await _firestore.collection('attendance').add(record.toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches all attendance logs associated with the specified student ID.
  /// Result is sorted locally by timestamp in descending order.
  Future<List<AttendanceRecordModel>> getStudentAttendanceHistory(
    String studentId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .get();

      final records = querySnapshot.docs
          .map((doc) => AttendanceRecordModel.fromFirestore(doc))
          .toList();

      // Sort by date descending in-memory to prevent indexing requirements
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records;
    } catch (e) {
      rethrow;
    }
  }

  /// Seeds a mock student user in Firestore for easy testing if it doesn't exist.
  Future<void> ensureMockStudentUser({
    required String uid,
    required String email,
    required String name,
    required String studentId,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(uid);
      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        await userDoc.set({
          'name': name,
          'studentId': studentId,
          'role': 'student',
        });
      }
    } catch (e) {
      // Log error but do not disrupt app flow
      print("Error ensuring mock student: $e");
    }
  }

  /// Helper debug method to easily insert a mock active session in Firestore for testing.
  Future<String> createMockSession({
    required String qrToken,
    required double latitude,
    required double longitude,
    required Duration duration,
    required String courseName,
  }) async {
    try {
      final docRef = _firestore.collection('attendance_sessions').doc();
      final now = DateTime.now();

      final session = AttendanceSessionModel(
        sessionId: docRef.id,
        adminId: 'debug_admin_1',
        qrToken: qrToken,
        createdAt: now,
        expiresAt: now.add(duration),
        latitude: latitude,
        longitude: longitude,
        active: true,
        courseName: courseName,
      );

      await docRef.set(session.toMap());
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }
}
