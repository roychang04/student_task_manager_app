import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // MVC Controller instance
  final AuthController _authController = AuthController();

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _identifierError = null;
      _passwordError = null;
    });

    if (identifier.isEmpty) {
      setState(() {
        _identifierError = 'Please enter your email or username.';
      });
      _passwordController.clear();
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Please enter your password.';
      });
      _passwordController.clear();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authController.login(
        identifier: identifier,
        password: password,
      );

      // AuthWrapper automatically shows DashboardScreen on auth state change.
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.message == 'EMPTY_IDENTIFIER') {
          _identifierError = 'Please enter your email or username.';
          _passwordController.clear();
        } else if (error.message == 'INVALID_EMAIL_FORMAT') {
          _identifierError = 'Please enter a valid email address.';
          _passwordController.clear();
        } else if (error.message == 'USER_NOT_FOUND') {
          _identifierError = 'No account found with this email or username.';
          _passwordController.clear();
        } else if (error.message == 'EMPTY_PASSWORD') {
          _passwordError = 'Please enter your password.';
          _passwordController.clear();
        } else if (error.message == 'WRONG_PASSWORD') {
          _passwordError = 'Incorrect password. Please try again.';
          _passwordController.clear();
        } else if (error.message == 'USER_DISABLED') {
          _identifierError = 'This account has been disabled.';
          _passwordController.clear();
        } else {
          _identifierError = error.message;
          _passwordController.clear();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _passwordError = 'Login failed. Please try again.';
        _passwordController.clear();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handles Forgot Password function
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _identifierController.text.contains('@')
          ? _identifierController.text.trim()
          : '',
    );
    bool isSending = false;
    String? dialogEmailError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon & Title Header
                    Center(
                      child: Column(
                        children: [
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
                              Icons.lock_reset_rounded,
                              color: Color(0xff4F46E5),
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your email address to receive a password reset link.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _inputLabel('Email Address'),
                    TextField(
                      controller: resetEmailController,
                      enabled: !isSending,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) {
                        if (dialogEmailError != null) {
                          setDialogState(() {
                            dialogEmailError = null;
                          });
                        }
                      },
                      decoration: _inputDecoration(
                        'Enter your email',
                        customBorderColor: dialogEmailError != null
                            ? Colors.red
                            : null,
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: dialogEmailError != null
                              ? Colors.red
                              : Colors.grey.shade500,
                          size: 20,
                        ),
                      ),
                    ),

                    if (dialogEmailError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 14,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                dialogEmailError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: isSending
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSending
                                  ? null
                                  : () async {
                                      final emailText =
                                          resetEmailController.text.trim();
                                      if (emailText.isEmpty) {
                                        setDialogState(() {
                                          dialogEmailError =
                                              'Please enter your email address.';
                                        });
                                        return;
                                      }

                                      setDialogState(() {
                                        isSending = true;
                                        dialogEmailError = null;
                                      });

                                      try {
                                        await _authController
                                            .sendPasswordResetEmail(emailText);
                                        if (!mounted) return;
                                        Navigator.of(dialogContext).pop();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            backgroundColor:
                                                const Color(0xff4F46E5),
                                            content: Text(
                                              'Password reset link sent to $emailText. Please check your inbox.',
                                            ),
                                          ),
                                        );
                                      } on FormatException catch (err) {
                                        setDialogState(() {
                                          dialogEmailError = err.message;
                                        });
                                      } on FirebaseAuthException catch (err) {
                                        setDialogState(() {
                                          if (err.code == 'user-not-found') {
                                            dialogEmailError =
                                                'No account found with this email.';
                                          } else if (err.code ==
                                              'invalid-email') {
                                            dialogEmailError =
                                                'Please enter a valid email address.';
                                          } else {
                                            dialogEmailError = err.message ??
                                                'Failed to send reset email.';
                                          }
                                        });
                                      } catch (err) {
                                        setDialogState(() {
                                          dialogEmailError =
                                              'Failed to send reset email. Try again.';
                                        });
                                      } finally {
                                        setDialogState(() {
                                          isSending = false;
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: isSending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Send Link',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

                // App Name
                const Text(
                  'Student Task Manager',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 36),

                // Login Form Card
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
                      _inputLabel('Email or Username'),
                      TextField(
                        controller: _identifierController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_identifierError != null) {
                            setState(() {
                              _identifierError = null;
                            });
                          }
                        },
                        decoration: _inputDecoration(
                          'Enter email or username',
                          customBorderColor:
                              _identifierError != null ? Colors.red : null,
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: _identifierError != null
                                ? Colors.red
                                : Colors.grey.shade500,
                            size: 20,
                          ),
                        ),
                      ),
                      if (_identifierError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 14,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _identifierError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      _inputLabel('Password'),
                      TextField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() {
                              _passwordError = null;
                            });
                          }
                        },
                        onSubmitted: (_) => _login(),
                        decoration: _inputDecoration(
                          'Enter your password',
                          customBorderColor:
                              _passwordError != null ? Colors.red : null,
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: _passwordError != null
                                ? Colors.red
                                : Colors.grey.shade500,
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
                      if (_passwordError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 14,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _passwordError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Forgot Password Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: TextButton(
                            onPressed:
                                _isLoading ? null : _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff4F46E5),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff4F46E5),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xffA5A1F5),
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
                                  'Log In',
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

                // Register Link with Hand Pointer Cursor
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _navigateToRegister,
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff4F46E5),
                          ),
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
    );
  }
}