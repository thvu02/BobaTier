import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/auth/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty) {
      _showError('Please enter your name.');
      return;
    }
    if (email.isEmpty) {
      _showError('Please enter your email.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).createAccount(name, email, password);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_authMessage(e.code));
    } catch (_) {
      if (mounted) _showError('Account creation failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _authMessage(String code) => switch (code) {
    'email-already-in-use' => 'An account with this email already exists.',
    'invalid-email' => 'Please enter a valid email address.',
    'weak-password' => 'Password is too weak. Use at least 6 characters.',
    'operation-not-allowed' => 'Email sign-up is currently disabled.',
    'network-request-failed' => 'No internet connection. Check your network and try again.',
    _ => 'Account creation failed. Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Create account', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('Join to start ranking boba shops',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 32),
              _label('Display name'),
              const SizedBox(height: 6),
              TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Joe Bruin'), inputFormatters: [LengthLimitingTextInputFormatter(50)]),
              const SizedBox(height: 16),
              _label('Email'),
              const SizedBox(height: 6),
              TextField(controller: _emailController, decoration: const InputDecoration(hintText: 'joe@bobafiend.com'), keyboardType: TextInputType.emailAddress, inputFormatters: [LengthLimitingTextInputFormatter(254)]),
              const SizedBox(height: 16),
              _label('Password'),
              const SizedBox(height: 6),
              TextField(controller: _passwordController, decoration: const InputDecoration(hintText: 'Password'), obscureText: true, inputFormatters: [LengthLimitingTextInputFormatter(128)]),
              const SizedBox(height: 16),
              _label('Confirm password'),
              const SizedBox(height: 6),
              TextField(controller: _confirmController, decoration: const InputDecoration(hintText: 'Confirm password'), obscureText: true, inputFormatters: [LengthLimitingTextInputFormatter(128)]),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createAccount,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create account'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'By creating an account you agree to our\nTerms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark),
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
