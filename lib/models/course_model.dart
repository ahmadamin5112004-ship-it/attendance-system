import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Course added by a teacher/Sir.
/// Stored in Firestore at /courses/{courseId}
class CourseModel {
  final String courseId;
  final String courseCode;
  final String courseName;
  final String teacherId;
  final String teacherName;
  final DateTime createdAt;

  CourseModel({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
    required this.createdAt,
  });

  /// Factory constructor to create a [CourseModel] from a Firestore [DocumentSnapshot].
  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    final dynamic rawCreatedAt = data['createdAt'];
    DateTime parsedCreatedAt = DateTime.now();
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    }

    return CourseModel(
      courseId: doc.id,
      courseCode: data['courseCode'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      createdAt: parsedCreatedAt,
    );
  }

  /// Converts the [CourseModel] instance to a Map structure for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
