import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import 'auth_wrapper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // MVC Controller instance
  final AuthController _authController = AuthController();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Timer? _usernameDebounceTimer;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCheckingUsername = false;
  bool _isUsernameTaken = false;

  @override
  void dispose() {
    _usernameDebounceTimer?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounceTimer?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameTaken = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _isUsernameTaken = false;
    });

    _usernameDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final isTaken = await _authController.isUsernameTaken(trimmed);
      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _isUsernameTaken = isTaken;
      });
    });
  }

  Future<void> _register() async {
    if (_isLoading) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (_isUsernameTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username is already taken.'),
        ),
      );
      return;
    }

    try {
      // Validate inputs using AuthController
      setState(() {
        _isLoading = true;
      });

      await _authController.register(
        username: username,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );

      // Sign out so the user logs in with their new credentials.
      await _authController.logout();

      if (!mounted) return;

      _showSuccessDialog();
    } on FormatException catch (error) {
      if (!mounted) return;
      if (error.message == 'Username is already taken.') {
        setState(() {
          _isUsernameTaken = true;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      String message;
      switch (error.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Please follow requirements.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password sign-up is not enabled.';
          break;
        default:
          message = error.message ?? 'Registration failed. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration failed. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    int countdown = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start the countdown timer.
            Future.delayed(
              const Duration(seconds: 1),
              () {
                if (!mounted) return;

                if (countdown > 1) {
                  setDialogState(() {
                    countdown--;
                  });
                } else {
                  _goToLogin(dialogContext);
                }
              },
            );

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),

                  // Success icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xff4F46E5).withValues(
                        alpha: 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xff4F46E5),
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Registration Successful!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Your account has been created.\n'
                    'Redirecting to login in $countdown seconds...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Go to Login button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => _goToLogin(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Go to Login Now',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _goToLogin(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthWrapper(),
      ),
      (route) => false,
    );
  }

  void _navigateToLogin() {
    Navigator.pop(context);
  }

  InputDecoration _inputDecoration(
    String hintText, {
    Widget? prefixIcon,
    Widget? suffixIcon,
    Color? customBorderColor,
  }) {
    final borderSide = customBorderColor != null
        ? BorderSide(color: customBorderColor, width: 1.5)
        : BorderSide(color: Colors.grey.shade300);

    final focusedSide = customBorderColor != null
        ? BorderSide(color: customBorderColor, width: 2.0)
        : const BorderSide(color: Color(0xff4F46E5), width: 1.5);

    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: borderSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: borderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: focusedSide,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildPasswordRequirement(String label, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: isMet ? const Color(0xff10B981) : Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isMet ? const Color(0xff065F46) : Colors.grey.shade600,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUsername = _usernameController.text.trim();
    final isUsernameNotEmpty = currentUsername.isNotEmpty;
    final isUsernameAvailable =
        isUsernameNotEmpty && !_isCheckingUsername && !_isUsernameTaken;

    Color? usernameBorderColor;
    if (_isUsernameTaken) {
      usernameBorderColor = Colors.red;
    } else if (isUsernameAvailable) {
      usernameBorderColor = const Color(0xff10B981);
    }

    final currentPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final hasMinLength = currentPassword.length >= 6;
    final hasCapital = currentPassword.contains(RegExp(r'[A-Z]'));
    final hasNumber = currentPassword.contains(RegExp(r'[0-9]'));
    final hasSpecial = currentPassword.contains(RegExp(r'[^a-zA-Z0-9]'));

    final isConfirmNotEmpty = confirmPassword.isNotEmpty;
    final isPasswordMismatch = isConfirmNotEmpty && confirmPassword != currentPassword;
    final isPasswordMatch = isConfirmNotEmpty && confirmPassword == currentPassword;

    Color? confirmBorderColor;
    if (isPasswordMismatch) {
      confirmBorderColor = Colors.red;
    } else if (isPasswordMatch) {
      confirmBorderColor = const Color(0xff10B981);
    }

    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xffF6F7FB),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xff4F46E5),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff4F46E5).withValues(
                            alpha: 0.30,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Sign up to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Register Form Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.05,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputLabel('Username'),
                        TextField(
                          controller: _usernameController,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.next,
                          onChanged: _onUsernameChanged,
                          decoration: _inputDecoration(
                            'Enter your username',
                            customBorderColor: usernameBorderColor,
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              color: _isUsernameTaken
                                  ? Colors.red
                                  : (isUsernameAvailable
                                      ? const Color(0xff10B981)
                                      : Colors.grey.shade500),
                              size: 20,
                            ),
                          ),
                        ),
                        if (_isCheckingUsername)
                          const Padding(
                            padding: EdgeInsets.only(top: 6, left: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xff4F46E5),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Checking username availability...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_isUsernameTaken)
                          const Padding(
                            padding: EdgeInsets.only(top: 6, left: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Username is already taken',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isUsernameAvailable)
                          const Padding(
                            padding: EdgeInsets.only(top: 6, left: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Color(0xff10B981),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Username is available',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff065F46),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        _inputLabel('Email'),
                        TextField(
                          controller: _emailController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            'Enter your email',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        _inputLabel('Password'),
                        TextField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: _inputDecoration(
                            'Enter your password',
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Password Requirements Card
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xffF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password Must Contain:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildPasswordRequirement('At least 6 characters', hasMinLength),
                              _buildPasswordRequirement('At least one capital letter (A-Z)', hasCapital),
                              _buildPasswordRequirement('At least one number (0-9)', hasNumber),
                              _buildPasswordRequirement('At least one special character (!@#\$% etc)', hasSpecial),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        _inputLabel('Confirm Password'),
                        TextField(
                          controller: _confirmPasswordController,
                          enabled: !_isLoading,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _register(),
                          decoration: _inputDecoration(
                            'Confirm your password',
                            customBorderColor: confirmBorderColor,
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: isPasswordMismatch
                                  ? Colors.red
                                  : (isPasswordMatch
                                      ? const Color(0xff10B981)
                                      : Colors.grey.shade500),
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                        ),

                        // Live Confirm Password Match Indicator
                        if (isPasswordMismatch)
                          const Padding(
                            padding: EdgeInsets.only(top: 6, left: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Passwords do not match',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (isPasswordMatch)
                          const Padding(
                            padding: EdgeInsets.only(top: 6, left: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Color(0xff10B981),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Passwords match',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff065F46),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff4F46E5),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xffA5A1F5),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Register',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isLoading ? null : _navigateToLogin,
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff4F46E5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}