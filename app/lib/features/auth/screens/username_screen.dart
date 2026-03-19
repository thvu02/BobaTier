import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/auth/providers/auth_provider.dart';

class UsernameScreen extends ConsumerStatefulWidget {
  const UsernameScreen({super.key});

  @override
  ConsumerState<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends ConsumerState<UsernameScreen> {
  final _controller = TextEditingController();
  bool _available = false;
  bool _checking = false;
  bool _reserving = false;

  List<String> _generateSuggestions(String displayName) {
    if (displayName.isEmpty) return [];

    final parts = displayName.trim().toLowerCase().split(RegExp(r'\s+'));
    final first = parts.first.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final last = parts.length > 1
        ? parts.last.replaceAll(RegExp(r'[^a-z0-9]'), '')
        : '';

    if (first.isEmpty) return [];

    final suggestions = <String>[];

    final prefix = first.length > 4 ? first.substring(0, 4) : first;
    suggestions.add('${prefix}_boba');

    if (last.isNotEmpty) {
      suggestions.add('${first}_$last');
      final abbrev = first + last;
      if (abbrev != '${first}_$last'.replaceAll('_', '')) {
        suggestions.add(abbrev);
      }
    }

    return suggestions.where((s) => s.length >= 3 && s.length <= 20).toList();
  }

  void _checkAvailability(String value) async {
    if (value.length < 3 || !RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
      setState(() => _available = false);
      return;
    }
    setState(() => _checking = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('usernames').doc(value).get();
      if (mounted) {
        setState(() {
          _checking = false;
          _available = !doc.exists;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _selectSuggestion(String suggestion) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.collapsed(offset: suggestion.length);
    _checkAvailability(suggestion);
  }

  Future<void> _reserve() async {
    setState(() => _reserving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (kDebugMode) debugPrint('Reserve: currentUser uid=${user?.uid}');
      if (user != null) {
        final idToken = await user.getIdToken();
        if (kDebugMode) debugPrint('Reserve: idToken present=${idToken != null}, length=${idToken?.length}');
      }

      final callable = FirebaseFunctions.instance.httpsCallable('onUsernameReserve');
      await callable.call({'username': _controller.text});
      if (mounted) {
        context.go('/location');
        ref.read(authProvider.notifier).refreshProfile();
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) debugPrint('Username reserve failed: code=${e.code}, message=${e.message}, details=${e.details}');
      if (mounted) {
        final message = switch (e.code) {
          'already-exists' => 'This username was just taken. Try another one.',
          'invalid-argument' => e.message ?? 'Invalid username format.',
          _ => 'Could not reserve username. Please try again.',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        if (e.code == 'already-exists') {
          setState(() => _available = false);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Username reserve unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reserve username. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reserving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = ref.watch(currentUserProvider)?.displayName ?? '';
    final suggestions = _generateSuggestions(displayName);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text('Choose your username',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('This is how friends find and add you',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                onChanged: _checkAvailability,
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                decoration: InputDecoration(
                  prefixText: '@ ',
                  prefixStyle: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 16,
                  ),
                  suffixIcon: _checking
                      ? const Padding(padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : _controller.text.length >= 3
                      ? Icon(_available ? Icons.check_circle : Icons.cancel,
                      color: _available ? AppColors.green : AppColors.red)
                      : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _controller.text.length < 3
                          ? AppColors.border
                          : _available ? AppColors.green : AppColors.red,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              if (_available && !_checking && _controller.text.length >= 3)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.greenBg, borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check, size: 14, color: AppColors.green),
                    const SizedBox(width: 4),
                    Text('@${_controller.text} is available',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F6E56), fontWeight: FontWeight.w500)),
                  ]),
                ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.map((s) => ActionChip(
                    label: Text('@$s'),
                    onPressed: () => _selectSuggestion(s),
                    backgroundColor: AppColors.card,
                    side: const BorderSide(color: AppColors.border),
                    labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary,
                    ),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Lowercase letters, numbers, and underscores only. 3\u201320 characters.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _available && !_reserving ? _reserve : null,
                  child: _reserving
                      ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
