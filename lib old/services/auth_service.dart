import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser {
    return _auth.currentUser;
  }

  String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  String? get currentUserEmail {
    return _auth.currentUser?.email;
  }

  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  Future<UserCredential> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;

    if (user == null) {
      throw Exception('Unable to create user');
    }

    await _firestore.collection('userdata').doc(user.uid).set({
      'username': username,
      'email': email,
      'uid': user.uid,
      'notificationsEnabled': true,
      'defaultTaskSorting': 'Due Date',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}