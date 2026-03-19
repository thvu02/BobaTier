import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/ranking/providers/ranking_provider.dart';
import 'package:bobatier/features/ranking/widgets/tier_badge.dart';

class TierListScreen extends ConsumerWidget {
  const TierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(myRankingsProvider);
    final byTier = ref.watch(rankingsByTierProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My ranks', style: Theme.of(context).textTheme.headlineMedium),
                  Text('${rankingsAsync.value?.length ?? 0} shops ranked',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                ],
              )),
            ),
            ...byTier.entries.expand((entry) => [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                sliver: SliverToBoxAdapter(child: Row(children: [
                  TierBadge(tier: entry.key, size: 22),
                  const SizedBox(width: 8),
                  Text('${entry.key} tier', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12)),
                ])),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final r = entry.value[i];
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
                  },
                  childCount: entry.value.length,
                )),
              ),
            ]),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}
