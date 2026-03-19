import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/social/providers/social_provider.dart';
import 'package:bobatier/features/ranking/models/ranking.dart';
import 'package:bobatier/features/ranking/widgets/tier_badge.dart';
import 'package:bobatier/shared/avatar_widget.dart';

class FriendProfileScreen extends ConsumerStatefulWidget {
  final String friendUid;
  const FriendProfileScreen({super.key, required this.friendUid});

  @override
  ConsumerState<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  final Map<String, bool> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    final rankingsAsync = ref.watch(friendRankingsProvider(widget.friendUid));

    final friend = friendsAsync.value?.where((f) => f.uid == widget.friendUid).firstOrNull;
    final rankings = rankingsAsync.value ?? [];

    if (friend == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Group rankings by tier
    final byTier = <String, List<Ranking>>{};
    for (final t in ['S', 'A', 'B', 'C', 'D', 'F']) {
      final list = rankings.where((r) => r.tier == t).toList();
      if (list.isNotEmpty) byTier[t] = list;
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, size: 22),
            onPressed: () => context.push('/friend-map/${friend.uid}'),
            tooltip: 'View map',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Avatar + name ──
          AvatarWidget(photoUrl: friend.photoUrl, initials: friend.initials, size: 72),
          const SizedBox(height: 12),
          Text(friend.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.dark)),
          Text('@${friend.username}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // ── Stat cards ──
          Row(children: [
            _statCard('${friend.shopsRanked}', 'Shops', AppColors.primary),
            const SizedBox(width: 8),
            _statCard('${friend.drinksRated}', 'Drinks', AppColors.dark),
            const SizedBox(width: 8),
            _statCard(friend.avgScore.toStringAsFixed(1), 'Avg score', AppColors.dark),
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
                TierBadge(tier: friend.mostCommonTier, size: 24),
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
                Text(friend.lastActiveLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            )),
          ]),
          const SizedBox(height: 24),

          // ── Rank list by tier (collapsible) ──
          Align(
            alignment: Alignment.centerLeft,
            child: Text('RANKS', style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(height: 8),

          if (rankings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No shops ranked yet.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...byTier.entries.map((entry) => _tierSection(entry.key, entry.value)),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _tierSection(String tier, List<Ranking> rankings) {
    final expanded = _expanded[tier] ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded[tier] = !expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              TierBadge(tier: tier, size: 22),
              const SizedBox(width: 8),
              Text('$tier tier', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12)),
              const SizedBox(width: 6),
              Text('(${rankings.length})', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
              ),
            ]),
          ),
        ),
        if (expanded)
          ...rankings.map((r) => _rankCard(r)),
      ],
    );
  }

  Widget _rankCard(Ranking r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(width: 40, height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.border),
            clipBehavior: Clip.antiAlias,
            child: r.shopPhotoUrl != null
                ? CachedNetworkImage(imageUrl: r.shopPhotoUrl!, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.local_cafe, color: AppColors.textSecondary, size: 20))
                : const Icon(Icons.local_cafe, color: AppColors.textSecondary, size: 20)),
        title: Text(r.shopName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text('${r.shopAddress} · ${r.drinkCount} drinks · Avg ${r.avgDrinkScore.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Text('★ ${r.googleRating.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.amber, fontSize: 12)),
        onTap: () => context.push('/shop/${r.placeId}'),
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
}
