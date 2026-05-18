import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/loading_button.dart';
import '../../providers/auth_provider.dart';
import 'auth_shell.dart';
import 'auth_validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _resetToken = TextEditingController();
  final _newPassword = TextEditingController();
  bool _tokenRequested = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _resetToken.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final resetToken = auth.lastResetToken;
    return AuthShell(
      title: 'Reset password',
      subtitle: _tokenRequested ? 'Enter the reset token and choose a new password.' : 'We will generate a reset token for your account.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: AuthValidators.email,
              ),
              if (_tokenRequested) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _resetToken,
                  decoration: const InputDecoration(labelText: 'Reset token', prefixIcon: Icon(Icons.key_outlined)),
                  validator: (value) => AuthValidators.requiredText(value, 'Reset token'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newPassword,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: AuthValidators.password,
                ),
              ],
              if (resetToken != null && resetToken.isNotEmpty) ...[
                const SizedBox(height: 14),
                SelectableText('Development reset token: $resetToken'),
              ],
              const SizedBox(height: 20),
              LoadingButton(
                isLoading: auth.isLoading,
                label: _tokenRequested ? 'Reset password' : 'Get reset token',
                icon: _tokenRequested ? Icons.lock_reset : Icons.mark_email_read_outlined,
                onPressed: () => _tokenRequested ? _resetPassword(context) : _requestToken(context),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: auth.isLoading ? null : () => context.go(AppRoutes.login),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _requestToken(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await context.read<AuthProvider>().forgotPassword(_email.text.trim());
      if (context.mounted) {
        setState(() => _tokenRequested = true);
        AppSnackBar.showSuccess(context, 'Reset token generated.');
      }
    } on DioException catch (exception) {
      final error = exception.error;
      if (context.mounted) {
        AppSnackBar.showError(context, error is AppException ? error.message : 'Could not generate reset token');
      }
    }
  }

  Future<void> _resetPassword(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await context.read<AuthProvider>().resetPassword(
            _email.text.trim(),
            _resetToken.text.trim(),
            _newPassword.text,
          );
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Password reset successfully.');
        context.go(AppRoutes.login);
      }
    } on DioException catch (exception) {
      final error = exception.error;
      if (context.mounted) {
        AppSnackBar.showError(context, error is AppException ? error.message : 'Could not reset password');
      }
    }
  }
}
