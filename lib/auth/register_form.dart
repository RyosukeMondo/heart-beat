import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_settings.dart';
import 'auth_widgets.dart';

class RegisterForm extends StatefulWidget {
  final VoidCallback onSwitchToLogin;

  const RegisterForm({super.key, required this.onSwitchToLogin});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _registerFormKey = GlobalKey<FormState>();
  final _registerEmailCtl = TextEditingController();
  final _registerUsernameCtl = TextEditingController();
  final _registerPasswordCtl = TextEditingController();
  final _registerConfirmPasswordCtl = TextEditingController();
  final _displayNameCtl = TextEditingController();
  bool _showRegisterPassword = false;
  bool _showConfirmPassword = false;
  bool _acceptTerms = false;
  bool _isCheckingEmail = false;
  bool _isCheckingUsername = false;
  String? _emailAvailabilityMessage;
  String? _usernameAvailabilityMessage;

  @override
  void dispose() {
    _registerEmailCtl.dispose();
    _registerUsernameCtl.dispose();
    _registerPasswordCtl.dispose();
    _registerConfirmPasswordCtl.dispose();
    _displayNameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authSettings = context.watch<AuthSettings>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Join the Competition!',
              subtitle: 'Create an account to track your progress and compete with others',
              icon: Icons.favorite_border,
            ),
            const SizedBox(height: 24),
            if (authSettings.lastError != null)
              ErrorDisplay(error: authSettings.lastError!),
            EmailField(
              controller: _registerEmailCtl,
              enabled: !authSettings.isLoading,
              isChecking: _isCheckingEmail,
              availabilityMessage: _emailAvailabilityMessage,
              onChanged: _checkEmailAvailability,
              usernameController: _registerUsernameCtl,
              passwordController: _registerPasswordCtl,
              isRegistration: true,
            ),
            const SizedBox(height: 16),
            _UsernameField(
              controller: _registerUsernameCtl,
              enabled: !authSettings.isLoading,
              isChecking: _isCheckingUsername,
              availabilityMessage: _usernameAvailabilityMessage,
              onChanged: _checkUsernameAvailability,
              emailController: _registerEmailCtl,
              passwordController: _registerPasswordCtl,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameCtl,
              decoration: const InputDecoration(
                labelText: 'Display Name (Optional)',
                hintText: 'How others will see you',
                prefixIcon: Icon(Icons.badge),
              ),
              enabled: !authSettings.isLoading,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PasswordField(
                    controller: _registerPasswordCtl,
                    emailController: _registerEmailCtl,
                    usernameController: _registerUsernameCtl,
                    enabled: !authSettings.isLoading,
                    showPassword: _showRegisterPassword,
                    onToggleVisibility: () => setState(
                        () => _showRegisterPassword = !_showRegisterPassword),
                    isRegistration: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ConfirmPasswordField(
                    controller: _registerConfirmPasswordCtl,
                    originalController: _registerPasswordCtl,
                    enabled: !authSettings.isLoading,
                    showPassword: _showConfirmPassword,
                    onToggleVisibility: () => setState(
                        () => _showConfirmPassword = !_showConfirmPassword),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _PasswordRequirements(),
            const SizedBox(height: 16),
            _TermsCheckbox(
              value: _acceptTerms,
              enabled: !authSettings.isLoading,
              onChanged: (v) => setState(() => _acceptTerms = v ?? false),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (authSettings.isLoading || !_acceptTerms)
                  ? null
                  : _handleRegister,
              icon: authSettings.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add),
              label: Text(authSettings.isLoading
                  ? 'Creating Account...'
                  : 'Create Account'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: authSettings.isLoading ? null : widget.onSwitchToLogin,
              icon: const Icon(Icons.login),
              label: const Text('Already have an account? Sign In'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final authSettings = context.read<AuthSettings>();
    final success = await authSettings.register(
      email: _registerEmailCtl.text.trim(),
      username: _registerUsernameCtl.text.trim(),
      password: _registerPasswordCtl.text,
      displayName: _displayNameCtl.text.trim().isNotEmpty
          ? _displayNameCtl.text.trim()
          : null,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Account created successfully! Welcome to competitive heart rate gaming!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _checkEmailAvailability(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _emailAvailabilityMessage = null;
        _isCheckingEmail = false;
      });
      return;
    }
    setState(() => _isCheckingEmail = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_registerEmailCtl.text != email) return;
      final authSettings = context.read<AuthSettings>();
      final isRegistered = await authSettings.isEmailRegistered(email);
      if (mounted && _registerEmailCtl.text == email) {
        setState(() {
          _emailAvailabilityMessage =
              isRegistered ? 'Email is already registered' : 'Email is available';
          _isCheckingEmail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailAvailabilityMessage = 'Unable to check email availability';
          _isCheckingEmail = false;
        });
      }
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.length < 3) {
      setState(() {
        _usernameAvailabilityMessage = null;
        _isCheckingUsername = false;
      });
      return;
    }
    setState(() => _isCheckingUsername = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_registerUsernameCtl.text != username) return;
      final authSettings = context.read<AuthSettings>();
      final isAvailable = await authSettings.isUsernameAvailable(username);
      if (mounted && _registerUsernameCtl.text == username) {
        setState(() {
          _usernameAvailabilityMessage =
              isAvailable ? 'Username is available' : 'Username is already taken';
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _usernameAvailabilityMessage = 'Unable to check username availability';
          _isCheckingUsername = false;
        });
      }
    }
  }
}

class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isChecking;
  final String? availabilityMessage;
  final ValueChanged<String> onChanged;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  const _UsernameField({
    required this.controller,
    required this.enabled,
    required this.isChecking,
    required this.availabilityMessage,
    required this.onChanged,
    required this.emailController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    final authSettings = context.read<AuthSettings>();
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Username *',
        hintText: 'Choose a unique username',
        prefixIcon: const Icon(Icons.person),
        suffixIcon: isChecking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : availabilityMessage != null
                ? Icon(
                    availabilityMessage!.contains('available')
                        ? Icons.check_circle
                        : Icons.error,
                    color: availabilityMessage!.contains('available')
                        ? Colors.green
                        : Colors.red,
                  )
                : null,
        helperText: availabilityMessage,
        helperStyle: TextStyle(
          color: availabilityMessage != null &&
                  availabilityMessage!.contains('available')
              ? Colors.green
              : Colors.red,
        ),
      ),
      enabled: enabled,
      onChanged: onChanged,
      validator: (value) {
        final errors = authSettings.validateRegistration(
          email: emailController.text,
          username: value ?? '',
          password: passwordController.text,
        );
        final usernameErrors =
            errors.where((e) => e.toLowerCase().contains('username'));
        return usernameErrors.isNotEmpty ? usernameErrors.first : null;
      },
    );
  }
}

class _ConfirmPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController originalController;
  final bool enabled;
  final bool showPassword;
  final VoidCallback onToggleVisibility;

  const _ConfirmPasswordField({
    required this.controller,
    required this.originalController,
    required this.enabled,
    required this.showPassword,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Confirm *',
        hintText: 'Repeat password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
      obscureText: !showPassword,
      enabled: enabled,
      validator: (value) {
        if (value != originalController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '• At least 8 characters\n• One uppercase letter\n• One lowercase letter\n• One number',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  const _TermsCheckbox({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
