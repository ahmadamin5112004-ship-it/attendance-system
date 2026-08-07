import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an attendance log submitted by a student.
/// Typically stored in Firestore at /attendance/{attendanceId}
class AttendanceRecordModel {
  final String attendanceId;
  final String sessionId;
  final String studentId;
  final String studentName;
  final DateTime timestamp;
  final double distance;
  final String? courseName; // Cached course name for easy listing in UI history

  AttendanceRecordModel({
    required this.attendanceId,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.timestamp,
    required this.distance,
    this.courseName,
  });

  /// Factory constructor to create an [AttendanceRecordModel] from a Firestore [DocumentSnapshot].
  factory AttendanceRecordModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse timestamp safely
    final dynamic rawTimestamp = data['timestamp'];
    DateTime parsedTimestamp = DateTime.now();
    if (rawTimestamp is Timestamp) {
      parsedTimestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedTimestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    }

    // Parse distance safely (could be int or double)
    double parsedDistance = 0.0;
    if (data['distance'] != null) {
      parsedDistance = (data['distance'] is num)
          ? (data['distance'] as num).toDouble()
          : double.tryParse(data['distance'].toString()) ?? 0.0;
    }

    return AttendanceRecordModel(
      attendanceId: doc.id,
      sessionId: data['sessionId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      timestamp: parsedTimestamp,
      distance: parsedDistance,
      courseName: data['courseName'] as String?,
    );
  }

  /// Converts the [AttendanceRecordModel] instance to a Map structure for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'studentId': studentId,
      'studentName': studentName,
      'timestamp': Timestamp.fromDate(timestamp),
      'distance': distance,
      if (courseName != null) 'courseName': courseName,
    };
  }
}
