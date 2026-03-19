import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/social/providers/social_provider.dart';
import 'package:bobatier/shared/avatar_widget.dart';

class MapsTab extends ConsumerWidget {
  const MapsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    final friends = friendsAsync.value ?? [];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: friends.length,
      itemBuilder: (context, i) {
        final f = friends[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: AvatarWidget(photoUrl: f.photoUrl, initials: f.initials, size: 40),
            title: Text(f.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('${f.shopsRanked} shops · ${f.drinksRated} drinks rated',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
            onTap: () => context.push('/friend-map/${f.uid}'),
          ),
        );
      },
    );
  }
}
