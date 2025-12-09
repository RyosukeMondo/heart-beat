import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_settings.dart';
import 'login_form.dart';
import 'register_form.dart';

/// Authentication page providing both login and registration functionality
/// 
/// Follows UI patterns from workout_config_page.dart:
/// - Tab-based navigation for different forms
/// - Consistent form validation and error handling
/// - Provider pattern for state management
/// - Material Design 3 styling with proper theming
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Heart Beat Gaming'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.login), text: 'Login'),
              Tab(icon: Icon(Icons.person_add), text: 'Register'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LoginForm(
              onGuestMode: _handleGuestMode,
              onForgotPassword: _showForgotPasswordDialog,
            ),
            RegisterForm(
              onSwitchToLogin: () {
                DefaultTabController.of(context).animateTo(0);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleGuestMode() {
    // Navigate back without authentication
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Continuing as guest. Sign in anytime to compete with others!'),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailCtl,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (emailCtl.text.isNotEmpty) {
                final authSettings = context.read<AuthSettings>();
                final success = await authSettings.requestPasswordReset(emailCtl.text.trim());
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success 
                            ? 'Password reset email sent!' 
                            : 'Failed to send reset email. Please try again.',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }
}
