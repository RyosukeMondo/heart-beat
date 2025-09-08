import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_settings.dart';

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
  // Tab controller for switching between login/register
  int _currentTabIndex = 0;
  
  // Form keys for validation
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  
  // Login form controllers
  final _loginEmailCtl = TextEditingController();
  final _loginPasswordCtl = TextEditingController();
  bool _rememberMe = false;
  bool _showLoginPassword = false;
  
  // Registration form controllers  
  final _registerEmailCtl = TextEditingController();
  final _registerUsernameCtl = TextEditingController();
  final _registerPasswordCtl = TextEditingController();
  final _registerConfirmPasswordCtl = TextEditingController();
  final _displayNameCtl = TextEditingController();
  bool _showRegisterPassword = false;
  bool _showConfirmPassword = false;
  bool _acceptTerms = false;

  // Async validation states
  bool _isCheckingEmail = false;
  bool _isCheckingUsername = false;
  String? _emailAvailabilityMessage;
  String? _usernameAvailabilityMessage;

  @override
  void dispose() {
    // Dispose all controllers following the same pattern as workout_config_page.dart
    _loginEmailCtl.dispose();
    _loginPasswordCtl.dispose();
    _registerEmailCtl.dispose();
    _registerUsernameCtl.dispose();
    _registerPasswordCtl.dispose();
    _registerConfirmPasswordCtl.dispose();
    _displayNameCtl.dispose();
    super.dispose();
  }

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
            _buildLoginTab(),
            _buildRegisterTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    final authSettings = context.watch<AuthSettings>();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome header
            const SizedBox(height: 32),
            Icon(
              Icons.favorite,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome Back!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to compete with your heart rate',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Error message display (following workout_config_page.dart pattern)
            if (authSettings.lastError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authSettings.lastError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => authSettings.clearError(),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),

            // Email field (following workout_config_page.dart input patterns)
            TextFormField(
              controller: _loginEmailCtl,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !authSettings.isLoading,
              validator: (value) {
                final errors = authSettings.validateLogin(
                  email: value ?? '',
                  password: _loginPasswordCtl.text,
                );
                final emailErrors = errors.where((e) => e.toLowerCase().contains('email'));
                return emailErrors.isNotEmpty ? emailErrors.first : null;
              },
            ),
            const SizedBox(height: 16),

            // Password field
            TextFormField(
              controller: _loginPasswordCtl,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showLoginPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() {
                    _showLoginPassword = !_showLoginPassword;
                  }),
                ),
              ),
              obscureText: !_showLoginPassword,
              enabled: !authSettings.isLoading,
              validator: (value) {
                final errors = authSettings.validateLogin(
                  email: _loginEmailCtl.text,
                  password: value ?? '',
                );
                final passwordErrors = errors.where((e) => e.toLowerCase().contains('password'));
                return passwordErrors.isNotEmpty ? passwordErrors.first : null;
              },
            ),
            const SizedBox(height: 16),

            // Remember me checkbox (following workout_config_page.dart choice chip pattern)
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: authSettings.isLoading ? null : (value) {
                    setState(() => _rememberMe = value ?? false);
                  },
                ),
                const Text('Remember me'),
                const Spacer(),
                TextButton(
                  onPressed: authSettings.isLoading ? null : _showForgotPasswordDialog,
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Login button (following workout_config_page.dart button patterns)
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

            // Guest mode button
            OutlinedButton.icon(
              onPressed: authSettings.isLoading ? null : _handleGuestMode,
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

  Widget _buildRegisterTab() {
    final authSettings = context.watch<AuthSettings>();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Registration header
            const SizedBox(height: 16),
            Icon(
              Icons.favorite_border,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Join the Competition!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create an account to track your progress and compete with others',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Error message display
            if (authSettings.lastError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authSettings.lastError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => authSettings.clearError(),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),

            // Email field with availability check
            TextFormField(
              controller: _registerEmailCtl,
              decoration: InputDecoration(
                labelText: 'Email Address *',
                hintText: 'Enter your email',
                prefixIcon: const Icon(Icons.email),
                suffixIcon: _isCheckingEmail
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _emailAvailabilityMessage != null
                        ? Icon(
                            _emailAvailabilityMessage!.contains('available')
                                ? Icons.check_circle
                                : Icons.error,
                            color: _emailAvailabilityMessage!.contains('available')
                                ? Colors.green
                                : Colors.red,
                          )
                        : null,
                helperText: _emailAvailabilityMessage,
                helperStyle: TextStyle(
                  color: _emailAvailabilityMessage != null &&
                          _emailAvailabilityMessage!.contains('available')
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !authSettings.isLoading,
              onChanged: _checkEmailAvailability,
              validator: (value) {
                final errors = authSettings.validateRegistration(
                  email: value ?? '',
                  username: _registerUsernameCtl.text,
                  password: _registerPasswordCtl.text,
                );
                final emailErrors = errors.where((e) => e.toLowerCase().contains('email'));
                return emailErrors.isNotEmpty ? emailErrors.first : null;
              },
            ),
            const SizedBox(height: 16),

            // Username field with availability check
            TextFormField(
              controller: _registerUsernameCtl,
              decoration: InputDecoration(
                labelText: 'Username *',
                hintText: 'Choose a unique username',
                prefixIcon: const Icon(Icons.person),
                suffixIcon: _isCheckingUsername
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _usernameAvailabilityMessage != null
                        ? Icon(
                            _usernameAvailabilityMessage!.contains('available')
                                ? Icons.check_circle
                                : Icons.error,
                            color: _usernameAvailabilityMessage!.contains('available')
                                ? Colors.green
                                : Colors.red,
                          )
                        : null,
                helperText: _usernameAvailabilityMessage,
                helperStyle: TextStyle(
                  color: _usernameAvailabilityMessage != null &&
                          _usernameAvailabilityMessage!.contains('available')
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              enabled: !authSettings.isLoading,
              onChanged: _checkUsernameAvailability,
              validator: (value) {
                final errors = authSettings.validateRegistration(
                  email: _registerEmailCtl.text,
                  username: value ?? '',
                  password: _registerPasswordCtl.text,
                );
                final usernameErrors = errors.where((e) => e.toLowerCase().contains('username'));
                return usernameErrors.isNotEmpty ? usernameErrors.first : null;
              },
            ),
            const SizedBox(height: 16),

            // Display name field (optional)
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

            // Password fields in a row (following workout_config_page.dart dual field pattern)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _registerPasswordCtl,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      hintText: 'Create password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showRegisterPassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() {
                          _showRegisterPassword = !_showRegisterPassword;
                        }),
                      ),
                    ),
                    obscureText: !_showRegisterPassword,
                    enabled: !authSettings.isLoading,
                    validator: (value) {
                      final errors = authSettings.validateRegistration(
                        email: _registerEmailCtl.text,
                        username: _registerUsernameCtl.text,
                        password: value ?? '',
                      );
                      final passwordErrors = errors.where((e) => e.toLowerCase().contains('password'));
                      return passwordErrors.isNotEmpty ? passwordErrors.first : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _registerConfirmPasswordCtl,
                    decoration: InputDecoration(
                      labelText: 'Confirm *',
                      hintText: 'Repeat password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() {
                          _showConfirmPassword = !_showConfirmPassword;
                        }),
                      ),
                    ),
                    obscureText: !_showConfirmPassword,
                    enabled: !authSettings.isLoading,
                    validator: (value) {
                      if (value != _registerPasswordCtl.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Password requirements helper text
            Container(
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
            ),
            const SizedBox(height: 16),

            // Terms acceptance checkbox
            Row(
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: authSettings.isLoading ? null : (value) {
                    setState(() => _acceptTerms = value ?? false);
                  },
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
            ),
            const SizedBox(height: 24),

            // Register button
            FilledButton.icon(
              onPressed: (authSettings.isLoading || !_acceptTerms) ? null : _handleRegister,
              icon: authSettings.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add),
              label: Text(authSettings.isLoading ? 'Creating Account...' : 'Create Account'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Switch to login button
            OutlinedButton.icon(
              onPressed: authSettings.isLoading ? null : () {
                DefaultTabController.of(context).animateTo(0);
              },
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

  // Event handlers following workout_config_page.dart patterns

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final authSettings = context.read<AuthSettings>();
    final success = await authSettings.login(
      email: _loginEmailCtl.text.trim(),
      password: _loginPasswordCtl.text,
      rememberMe: _rememberMe,
    );

    if (success && mounted) {
      // Navigate back to main app or show success
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome back! You can now compete in heart rate games.'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
      // Navigate back to main app or show success
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! Welcome to competitive heart rate gaming!'),
          backgroundColor: Colors.green,
        ),
      );
    }
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

  // Async validation methods

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
      await Future.delayed(const Duration(milliseconds: 500)); // Debounce
      if (_registerEmailCtl.text != email) return; // User changed input

      final authSettings = context.read<AuthSettings>();
      final isRegistered = await authSettings.isEmailRegistered(email);
      
      if (mounted && _registerEmailCtl.text == email) {
        setState(() {
          _emailAvailabilityMessage = isRegistered 
              ? 'Email is already registered'
              : 'Email is available';
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
      await Future.delayed(const Duration(milliseconds: 500)); // Debounce
      if (_registerUsernameCtl.text != username) return; // User changed input

      final authSettings = context.read<AuthSettings>();
      final isAvailable = await authSettings.isUsernameAvailable(username);
      
      if (mounted && _registerUsernameCtl.text == username) {
        setState(() {
          _usernameAvailabilityMessage = isAvailable 
              ? 'Username is available'
              : 'Username is already taken';
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
                
                if (mounted) {
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