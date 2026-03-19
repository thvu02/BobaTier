import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/auth/providers/auth_provider.dart';
import 'package:bobatier/features/social/providers/social_provider.dart';
import 'package:bobatier/features/ranking/widgets/tier_badge.dart';
import 'package:bobatier/shared/avatar_widget.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late bool _friendActivity;
  late bool _wantToTryReminders;
  late bool _newShopNearby;
  bool _initialized = false;

  Future<void> _updatePref(String field, bool value) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'notifications.$field': value,
      });
    } catch (_) {
      if (mounted) {
        // Rollback the toggle to its previous value
        setState(() {
          switch (field) {
            case 'friendActivity': _friendActivity = !value;
            case 'wantToTryReminders': _wantToTryReminders = !value;
            case 'newShopNearby': _newShopNearby = !value;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update setting. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final liveStats = ref.watch(userStatsStreamProvider).value ?? user?.stats;
    final friendCount = ref.watch(friendsProvider).value?.length ?? 0;
    final wttCount = ref.watch(wantToTryProvider).value
        ?.where((w) => !w.isVisited).length ?? 0;

    if (user == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    if (!_initialized) {
      _friendActivity = user.notifications.friendActivity;
      _wantToTryReminders = user.notifications.wantToTryReminders;
      _newShopNearby = user.notifications.newShopNearby;
      _initialized = true;
    }

    final stats = liveStats ?? user.stats;

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AvatarWidget(photoUrl: user.photoUrl, initials: user.initials, size: 72),
            const SizedBox(height: 12),
            Text(user.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.dark)),
            Text('@${user.username}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Row(children: [
              _statCard('${stats.shopsRanked}', 'Shops', AppColors.primary),
              const SizedBox(width: 8),
              _statCard('${stats.drinksRated}', 'Drinks', AppColors.dark),
              const SizedBox(width: 8),
              _statCard(stats.avgScore.toStringAsFixed(1), 'Avg score', AppColors.dark),
              const SizedBox(width: 8),
              _statCard('$friendCount', 'Friends', AppColors.dark),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TierBadge(tier: stats.mostCommonTier, size: 24),
                  const SizedBox(width: 8),
                  const Text('Most given\ntier', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
              )),
              const SizedBox(width: 8),
              Expanded(child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$wttCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Text('Want\nto try', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
              )),
            ]),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('NOTIFICATIONS', style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                _toggleRow('Friend activity', _friendActivity, (v) {
                  setState(() => _friendActivity = v);
                  _updatePref('friendActivity', v);
                }),
                const Divider(height: 1, color: AppColors.border),
                _toggleRow('Want to try reminders', _wantToTryReminders, (v) {
                  setState(() => _wantToTryReminders = v);
                  _updatePref('wantToTryReminders', v);
                }),
                const Divider(height: 1, color: AppColors.border),
                _toggleRow('New shop nearby', _newShopNearby, (v) {
                  setState(() => _newShopNearby = v);
                  _updatePref('newShopNearby', v);
                }),
              ]),
            ),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: () {
                ref.read(authProvider.notifier).signOut();
                context.go('/login');
              },
              child: const Text('Sign out'),
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    ));
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Switch.adaptive(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
        ],
      ),
    );
  }
}
