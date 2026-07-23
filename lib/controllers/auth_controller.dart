import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthController {
  final AuthService _authService = AuthService();

  User? get currentUser => _authService.currentUser;
  String? get currentUserId => _authService.currentUserId;
  String? get currentUserEmail => _authService.currentUserEmail;
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  /// Validates password strength:
  /// - Min 6 characters
  /// - At least one uppercase letter (A-Z)
  /// - At least one number (0-9)
  /// - At least one special character
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Please enter a password.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters long.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one capital letter (A-Z).';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number (0-9).';
    }
    if (!password.contains(RegExp(r'[^a-zA-Z0-9]'))) {
      return 'Password must contain at least one special character (!@#\$%^&* etc).';
    }
    return null;
  }

  /// Returns list of unmet password requirement labels
  static List<String> getUnmetPasswordRequirements(String password) {
    final List<String> unmet = [];
    if (password.length < 6) {
      unmet.add('At least 6 characters');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      unmet.add('At least one capital letter (A-Z)');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      unmet.add('At least one number (0-9)');
    }
    if (!password.contains(RegExp(r'[^a-zA-Z0-9]'))) {
      unmet.add('At least one special character (!@#\$% etc)');
    }
    return unmet;
  }

  /// Validates email format
  static String? validateEmail(String email) {
    if (email.trim().isEmpty) {
      return 'Please enter your email.';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Checks if a username is already taken in the Firestore 'userdata' collection
  Future<bool> isUsernameTaken(String username) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection('userdata')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Login user with Email OR Username + Password
  Future<UserCredential> login({
    required String identifier, // Email or Username
    required String password,
  }) async {
    final cleanIdentifier = identifier.trim();
    final cleanPassword = password.trim();

    if (cleanIdentifier.isEmpty) {
      throw const FormatException('EMPTY_IDENTIFIER');
    }
    if (cleanPassword.isEmpty) {
      throw const FormatException('EMPTY_PASSWORD');
    }

    String emailToUse = cleanIdentifier;

    if (cleanIdentifier.contains('@')) {
      // Check email format
      final formatError = validateEmail(cleanIdentifier);
      if (formatError != null) {
        throw const FormatException('INVALID_EMAIL_FORMAT');
      }

      // Check if email exists in database
      final snapshot = await FirebaseFirestore.instance
          .collection('userdata')
          .where('email', isEqualTo: cleanIdentifier)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw const FormatException('USER_NOT_FOUND');
      }
    } else {
      // Input is a username
      final snapshot = await FirebaseFirestore.instance
          .collection('userdata')
          .where('username', isEqualTo: cleanIdentifier)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw const FormatException('USER_NOT_FOUND');
      }

      final userData = snapshot.docs.first.data();
      final fetchedEmail = userData['email']?.toString();

      if (fetchedEmail == null || fetchedEmail.isEmpty) {
        throw const FormatException('USER_NOT_FOUND');
      }

      emailToUse = fetchedEmail;
    }

    try {
      return await _authService.login(
        email: emailToUse,
        password: cleanPassword,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        throw const FormatException('USER_NOT_FOUND');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const FormatException('WRONG_PASSWORD');
      } else if (e.code == 'user-disabled') {
        throw const FormatException('USER_DISABLED');
      } else {
        throw FormatException(e.message ?? 'Login failed.');
      }
    }
  }

  /// Register user and create user profile in Firestore
  Future<UserCredential> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (username.trim().isEmpty) {
      throw const FormatException('Please enter your username.');
    }

    final taken = await isUsernameTaken(username);
    if (taken) {
      throw const FormatException('Username is already taken.');
    }

    final emailError = validateEmail(email);
    if (emailError != null) {
      throw FormatException(emailError);
    }

    final passwordError = validatePassword(password);
    if (passwordError != null) {
      throw FormatException(passwordError);
    }

    if (password.trim() != confirmPassword.trim()) {
      throw const FormatException('Passwords do not match.');
    }

    return await _authService.register(
      username: username.trim(),
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    final emailError = validateEmail(email);
    if (emailError != null) {
      throw FormatException(emailError);
    }

    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  /// Logout user
  Future<void> logout() async {
    await _authService.logout();
  }
}
