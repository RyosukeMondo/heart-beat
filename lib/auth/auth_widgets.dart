import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_settings.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Icon(
          icon,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
}

class ErrorDisplay extends StatelessWidget {
  final String error;
  const ErrorDisplay({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final authSettings = context.read<AuthSettings>();
    return Container(
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
              error,
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
    );
  }
}

class EmailField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isChecking;
  final String? availabilityMessage;
  final ValueChanged<String>? onChanged;
  final TextEditingController? usernameController;
  final TextEditingController passwordController;
  final bool isRegistration;

  const EmailField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.passwordController,
    this.isChecking = false,
    this.availabilityMessage,
    this.onChanged,
    this.usernameController,
    this.isRegistration = false,
  });

  @override
  Widget build(BuildContext context) {
    final authSettings = context.read<AuthSettings>();
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Email Address${isRegistration ? ' *' : ''}',
        hintText: 'Enter your email',
        prefixIcon: const Icon(Icons.email),
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
      keyboardType: TextInputType.emailAddress,
      enabled: enabled,
      onChanged: onChanged,
      validator: (value) {
        List<String> errors;
        if (isRegistration) {
           errors = authSettings.validateRegistration(
            email: value ?? '',
            username: usernameController?.text ?? '',
            password: passwordController.text,
          );
        } else {
           errors = authSettings.validateLogin(
            email: value ?? '',
            password: passwordController.text,
          );
        }

        final emailErrors =
            errors.where((e) => e.toLowerCase().contains('email'));
        return emailErrors.isNotEmpty ? emailErrors.first : null;
      },
    );
  }
}

class PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController emailController;
  final TextEditingController? usernameController;
  final bool enabled;
  final bool showPassword;
  final VoidCallback onToggleVisibility;
  final bool isRegistration;

  const PasswordField({
    super.key,
    required this.controller,
    required this.emailController,
    required this.enabled,
    required this.showPassword,
    required this.onToggleVisibility,
    this.usernameController,
    this.isRegistration = false,
  });

  @override
  Widget build(BuildContext context) {
    final authSettings = context.read<AuthSettings>();
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Password${isRegistration ? ' *' : ''}',
        hintText: isRegistration ? 'Create password' : 'Enter your password',
        prefixIcon: const Icon(Icons.lock),
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
        List<String> errors;
        if (isRegistration) {
           errors = authSettings.validateRegistration(
            email: emailController.text,
            username: usernameController?.text ?? '',
            password: value ?? '',
          );
        } else {
           errors = authSettings.validateLogin(
            email: emailController.text,
            password: value ?? '',
          );
        }

        final passwordErrors =
            errors.where((e) => e.toLowerCase().contains('password'));
        return passwordErrors.isNotEmpty ? passwordErrors.first : null;
      },
    );
  }
}
