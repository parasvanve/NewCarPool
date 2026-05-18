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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in to book rides, offer seats, and track trips in realtime.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: AuthValidators.password,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: auth.isLoading ? null : () => context.push(AppRoutes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              LoadingButton(
                isLoading: auth.isLoading,
                label: 'Sign in',
                icon: Icons.login,
                onPressed: () => _submit(context),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: auth.isLoading ? null : () => context.push(AppRoutes.register),
                child: const Text('Create account'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await context.read<AuthProvider>().login(_email.text.trim(), _password.text);
      if (context.mounted) {
        context.go(AppRoutes.dashboard);
      }
    } on DioException catch (exception) {
      final error = exception.error;
      if (context.mounted) {
        AppSnackBar.showError(context, error is AppException ? error.message : 'Sign in failed');
      }
    } catch (exception) {
      if (context.mounted) {
        AppSnackBar.showError(context, exception.toString());
      }
    }
  }
}
