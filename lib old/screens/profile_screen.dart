import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() {
    return _ProfileScreenState();
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userSubscription;

  String username = 'User';
  String email = '';

  bool notificationsEnabled = true;
  String defaultTaskSorting = 'Due Date';

  final List<String> sortingOptions = [
    'Due Date',
    'Priority',
    'Status',
    'Category',
  ];

  static const Color backgroundColour = Color(0xffF6F7FB);
  static const Color primaryColour = Color(0xff4F46E5);
  static const Color cardColour = Colors.white;
  static const Color titleTextColour = Color(0xff111827);
  static const Color subtitleTextColour = Color(0xff6B7280);
  static const Color redColour = Color(0xffEF4444);

  @override
  void initState() {
    super.initState();
    _listenToCurrentUser();
    _syncEmailFromAuth();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _listenToCurrentUser() {
    final user = _authService.currentUser;

    if (user == null) {
      debugPrint('No logged-in user found');
      return;
    }

    _userSubscription = FirebaseFirestore.instance
        .collection('userdata')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) {
        return;
      }

      final data = snapshot.data();

      if (data == null) {
        return;
      }

      final loadedSorting =
          data['defaultTaskSorting']?.toString() ?? 'Due Date';

      setState(() {
        username = data['username']?.toString() ?? 'User';
        email = data['email']?.toString() ?? user.email ?? '';

        notificationsEnabled =
            data['notificationsEnabled'] as bool? ?? true;

        defaultTaskSorting = sortingOptions.contains(loadedSorting)
            ? loadedSorting
            : 'Due Date';
      });
    });
  }

  Future<void> _updateUserData(
    Map<String, dynamic> updatedData,
  ) async {
    final user = _authService.currentUser;

    if (user == null) {
      throw Exception('No logged-in user');
    }

    await FirebaseFirestore.instance
        .collection('userdata')
        .doc(user.uid)
        .set(
      {
        ...updatedData,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String _firstLetter(String text) {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      return '?';
    }

    return trimmedText[0].toUpperCase();
  }

  String _limitedUsername(String text) {
    final trimmedText = text.trim();

    if (trimmedText.length > 15) {
      return '${trimmedText.substring(0, 14)}…';
    }

    return trimmedText;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _changeUsername() async {
    final controller = TextEditingController(text: username);

    final newUsername = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Username'),
          content: TextField(
            controller: controller,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'New username',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(context, value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newUsername == null) {
      return;
    }

    final oldUsername = username;

    setState(() {
      username = newUsername;
    });

    try {
      await _updateUserData({
        'username': newUsername,
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        username = oldUsername;
      });

      _showMessage('Unable to update username');
    }
  }

  Future<void> _changePassword() async {
    final userEmail = _authService.currentUserEmail;

    if (userEmail == null || userEmail.isEmpty) {
      _showMessage('No email found for this account');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: userEmail,
      );

      if (!mounted) return;

      _showMessage('Password reset email sent');
    } catch (error) {
      _showMessage('Unable to send password reset email');
    }
  }

  Future<void> _reauthenticateUser(String currentPassword) async {
    final user = _authService.currentUser;

    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No logged-in user found',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> _syncEmailFromAuth() async {
    final oldUser = _authService.currentUser;

    if (oldUser == null) {
      return;
    }

    await oldUser.reload();

    final refreshedUser = FirebaseAuth.instance.currentUser;
    final authEmail = refreshedUser?.email;

    if (authEmail == null || authEmail.isEmpty) {
      return;
    }

    await _updateUserData({
      'email': authEmail,
      'pendingEmail': FieldValue.delete(),
    });

    if (!mounted) return;

    setState(() {
      email = authEmail;
    });
  }

  Future<void> _changeEmail() async {
    final newEmailController = TextEditingController(text: email);
    final currentPasswordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'New email',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newEmail = newEmailController.text.trim();
                final currentPassword =
                    currentPasswordController.text.trim();

                if (newEmail.isEmpty ||
                    !newEmail.contains('@') ||
                    currentPassword.isEmpty) {
                  return;
                }

                Navigator.pop(context, {
                  'newEmail': newEmail,
                  'currentPassword': currentPassword,
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    newEmailController.dispose();
    currentPasswordController.dispose();

    if (result == null) {
      return;
    }

    final newEmail = result['newEmail']!;
    final currentPassword = result['currentPassword']!;

    final user = _authService.currentUser;

    if (user == null) {
      _showMessage('No logged-in user found');
      return;
    }

    try {
      await _reauthenticateUser(currentPassword);

      await user.verifyBeforeUpdateEmail(newEmail);

      await _updateUserData({
        'pendingEmail': newEmail,
      });

      if (!mounted) return;

      _showMessage(
        'Verification email sent. After verifying, log in again to sync your email.',
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        _showMessage('Current password is incorrect');
      } else if (error.code == 'email-already-in-use') {
        _showMessage('This email is already in use');
      } else if (error.code == 'invalid-email') {
        _showMessage('Invalid email format');
      } else if (error.code == 'requires-recent-login') {
        _showMessage('Please re-enter your current password');
      } else {
        _showMessage('Unable to update email: ${error.code}');
      }
    } catch (error) {
      _showMessage('Unable to update email');
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
  }

  @override
  Widget build(BuildContext context) {
    final displayUsername = _limitedUsername(username);
    final profileLetter = _firstLetter(username);

    return Scaffold(
      backgroundColor: backgroundColour,
      appBar: AppBar(
        backgroundColor: backgroundColour,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: titleTextColour,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(
              profileLetter: profileLetter,
              displayUsername: displayUsername,
              email: email,
            ),
            const SizedBox(height: 26),
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleTextColour,
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(),
            const SizedBox(height: 24),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required String profileLetter,
    required String displayUsername,
    required String email,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColour,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: primaryColour.withValues(alpha: 0.15),
            child: Text(
              profileLetter,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: primaryColour,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayUsername,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleTextColour,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: subtitleTextColour,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: cardColour,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.notifications_none_rounded,
              color: primaryColour,
            ),
            title: const Text(
              'Notifications',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: titleTextColour,
              ),
            ),
            trailing: Switch(
              value: notificationsEnabled,
              activeThumbColor: primaryColour,
              activeTrackColor: primaryColour.withValues(alpha: 0.35),
              onChanged: (value) async {
                final oldValue = notificationsEnabled;

                setState(() {
                  notificationsEnabled = value;
                });

                try {
                  await _updateUserData({
                    'notificationsEnabled': value,
                  });
                } catch (error) {
                  if (!mounted) return;

                  setState(() {
                    notificationsEnabled = oldValue;
                  });

                  _showMessage('Unable to update notification setting');
                }
              },
            ),
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Change Username',
            onTap: _changeUsername,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            onTap: _changePassword,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.email_outlined,
            title: 'Change Email',
            onTap: _changeEmail,
          ),
          const Divider(height: 1),
          _buildSortingDropdown(),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: primaryColour,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: titleTextColour,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: subtitleTextColour,
      ),
    );
  }

  Widget _buildSortingDropdown() {
    return ListTile(
      leading: const Icon(
        Icons.sort_rounded,
        color: primaryColour,
      ),
      title: const Text(
        'Default Task Sorting',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleTextColour,
        ),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: defaultTaskSorting,
          borderRadius: BorderRadius.circular(12),
          items: sortingOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) async {
            if (value == null) {
              return;
            }

            final oldValue = defaultTaskSorting;

            setState(() {
              defaultTaskSorting = value;
            });

            try {
              await _updateUserData({
                'defaultTaskSorting': value,
              });
            } catch (error) {
              if (!mounted) return;

              setState(() {
                defaultTaskSorting = oldValue;
              });

              _showMessage('Unable to update default sorting');
            }
          },
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: redColour,
          side: const BorderSide(
            color: redColour,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}