import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a User in the system.
/// Typically stored in Firestore at /users/{uid}
class UserModel {
  final String uid;
  final String name;
  final String studentId;
  final String role;

  UserModel({
    required this.uid,
    required this.name,
    required this.studentId,
    required this.role,
  });

  /// Factory constructor to create a [UserModel] from a Firestore [DocumentSnapshot].
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] as String? ?? 'Unknown Student',
      studentId: data['studentId'] as String? ?? 'N/A',
      role: data['role'] as String? ?? 'student',
    );
  }

  /// Converts the [UserModel] instance to a Map structure for Firestore.
  Map<String, dynamic> toMap() {
    return {'name': name, 'studentId': studentId, 'role': role};
  }
}
