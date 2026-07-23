import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final bool notificationsEnabled;
  final String defaultTaskSorting;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.notificationsEnabled = true,
    this.defaultTaskSorting = 'Due Date',
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedDate;
    final dynamic rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      parsedDate = rawCreated.toDate();
    } else if (rawCreated is DateTime) {
      parsedDate = rawCreated;
    } else if (rawCreated is String) {
      parsedDate = DateTime.tryParse(rawCreated);
    }

    return UserModel(
      uid: map['uid'] ?? docId,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      notificationsEnabled:
          map['notificationsEnabled'] ?? map['notification'] ?? true,
      defaultTaskSorting:
          map['defaultTaskSorting'] ?? map['sorting'] ?? 'Due Date',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'notificationsEnabled': notificationsEnabled,
      'defaultTaskSorting': defaultTaskSorting,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
