import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_settings.dart';
import 'auth_widgets.dart';

class LoginForm extends StatefulWidget {
  final VoidCallback onGuestMode;
  final VoidCallback onForgotPassword;

  const LoginForm({
    super.key,
    required this.onGuestMode,
    required this.onForgotPassword,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailCtl = TextEditingController();
  final _loginPasswordCtl = TextEditingController();
  bool _rememberMe = false;
  bool _showLoginPassword = false;

  @override
  void dispose() {
    _loginEmailCtl.dispose();
    _loginPasswordCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authSettings = context.watch<AuthSettings>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Welcome Back!',
              subtitle: 'Sign in to compete with your heart rate',
              icon: Icons.favorite,
            ),
            const SizedBox(height: 32),
            if (authSettings.lastError != null)
              ErrorDisplay(error: authSettings.lastError!),
            EmailField(
              controller: _loginEmailCtl,
              enabled: !authSettings.isLoading,
              passwordController: _loginPasswordCtl,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _loginPasswordCtl,
              emailController: _loginEmailCtl,
              enabled: !authSettings.isLoading,
              showPassword: _showLoginPassword,
              onToggleVisibility: () {
                setState(() => _showLoginPassword = !_showLoginPassword);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: authSettings.isLoading
                      ? null
                      : (value) => setState(() => _rememberMe = value ?? false),
                ),
                const Text('Remember me'),
                const Spacer(),
                TextButton(
                  onPressed:
                      authSettings.isLoading ? null : widget.onForgotPassword,
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: authSettings.isLoading ? null : _handleLogin,
              icon: authSettings.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(authSettings.isLoading ? 'Signing In...' : 'Sign In'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: authSettings.isLoading ? null : widget.onGuestMode,
              icon: const Icon(Icons.person_outline),
              label: const Text('Continue as Guest'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final authSettings = context.read<AuthSettings>();
    final success = await authSettings.login(
      email: _loginEmailCtl.text.trim(),
      password: _loginPasswordCtl.text,
      rememberMe: _rememberMe,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome back! You can now compete in heart rate games.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
