import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/loading_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import 'auth_shell.dart';
import 'auth_validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otp = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _otpSent = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _otp.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AuthShell(
      title: _otpSent ? 'Verify your email' : 'Create account',
      subtitle: _otpSent
          ? 'Enter OTP sent to your email.'
          : 'Join as a passenger today and offer rides whenever you want.',
      children: [
        if (!_otpSent)
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Driver + Passenger'), avatar: Icon(Icons.swap_horiz, size: 16)),
              Chip(label: Text('Quick Onboarding'), avatar: Icon(Icons.bolt, size: 16)),
            ],
          ),
        const SizedBox(height: 14),
        _otpSent ? _buildOtpStep(context, auth) : _buildRegistrationStep(context, auth),
      ],
    );
  }

  Widget _buildRegistrationStep(BuildContext context, AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
            validator: (value) => AuthValidators.requiredText(value, 'Full name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
            validator: AuthValidators.phone,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
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
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPassword,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
            validator: _confirmPasswordValidator,
          ),
          const SizedBox(height: 20),
          LoadingButton(
            isLoading: auth.isLoading,
            label: 'Send OTP',
            icon: Icons.mark_email_read_outlined,
            onPressed: () => _sendOtp(context),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: auth.isLoading ? null : () => context.go(AppRoutes.login),
            child: const Text('I already have an account'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(BuildContext context, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter OTP sent to your email',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(_email.text.trim(), style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        TextFormField(
          controller: _otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '6 digit OTP',
            prefixIcon: Icon(Icons.password_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        LoadingButton(
          isLoading: auth.isLoading,
          label: 'Verify & Create Account',
          icon: Icons.verified_user_outlined,
          onPressed: () => _verifyOtp(context),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: auth.isLoading || _resendSeconds > 0 ? null : () => _resendOtp(context),
          icon: const Icon(Icons.refresh),
          label: Text(_resendSeconds > 0 ? 'Resend OTP in ${_resendSeconds}s' : 'Resend OTP'),
        ),
        TextButton(
          onPressed: auth.isLoading
              ? null
              : () => setState(() {
                    _otpSent = false;
                    _otp.clear();
                  }),
          child: const Text('Back/Edit details'),
        ),
      ],
    );
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required';
    }

    if (value != _password.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  Future<void> _sendOtp(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final resendAt = await context.read<AuthProvider>().sendRegisterOtp(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phoneNumber: _phone.text.trim(),
            password: _password.text,
            confirmPassword: _confirmPassword.text,
          );
      if (!context.mounted) return;
      setState(() {
        _otpSent = true;
        _otp.clear();
      });
      _startResendTimer(resendAt);
      AppSnackBar.showSuccess(context, 'OTP sent to your email.');
    } on DioException catch (exception) {
      final error = exception.error;
      if (context.mounted) {
        AppSnackBar.showError(context, error is AppException ? error.message : 'Could not send OTP');
      }
    } catch (exception) {
      if (context.mounted) {
        AppSnackBar.showError(context, exception.toString());
      }
    }
  }

  Future<void> _resendOtp(BuildContext context) async {
    try {
      final resendAt = await context.read<AuthProvider>().sendRegisterOtp(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phoneNumber: _phone.text.trim(),
            password: _password.text,
            confirmPassword: _confirmPassword.text,
          );
      if (!context.mounted) return;
      _startResendTimer(resendAt);
      AppSnackBar.showSuccess(context, 'OTP sent to your email.');
    } on DioException catch (exception) {
      final error = exception.error;
      if (context.mounted) {
        AppSnackBar.showError(context, error is AppException ? error.message : 'Could not send OTP');
      }
    } catch (exception) {
      if (context.mounted) {
        AppSnackBar.showError(context, exception.toString());
      }
    }
  }

  Future<void> _verifyOtp(BuildContext context) async {
    final otp = _otp.text.trim();
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      AppSnackBar.showError(context, 'Invalid OTP');
      return;
    }

    try {
      await authProvider.verifyRegisterOtp(_email.text.trim(), otp);
      await profileProvider.loadProfile();
      final profile = profileProvider.profile;
      if (!context.mounted) return;
      if (profile != null) {
        authProvider.syncFromProfile(profile);
      }
      AppSnackBar.showSuccess(context, 'Account created successfully.');
      final seenOnboarding = await authProvider.hasSeenOnboarding();
      if (!context.mounted) return;
      context.go(seenOnboarding ? AppRoutes.dashboard : AppRoutes.onboarding);
    } on DioException catch (exception) {
      final error = exception.error;
      if (context.mounted) {
        AppSnackBar.showError(context, error is AppException ? error.message : 'Invalid OTP');
      }
    } catch (exception) {
      if (context.mounted) {
        AppSnackBar.showError(context, exception.toString());
      }
    }
  }

  void _startResendTimer(DateTime? resendAt) {
    _resendTimer?.cancel();
    final now = DateTime.now().toUtc();
    final seconds = resendAt == null ? 60 : resendAt.toUtc().difference(now).inSeconds;
    setState(() => _resendSeconds = seconds.clamp(0, 60).toInt());

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }

      setState(() => _resendSeconds--);
    });
  }
}
