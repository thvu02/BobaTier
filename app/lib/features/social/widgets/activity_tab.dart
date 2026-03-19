import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/social/providers/social_provider.dart';
import 'package:bobatier/features/social/models/social_models.dart';
import 'package:bobatier/features/ranking/widgets/tier_badge.dart';
import 'package:bobatier/shared/avatar_widget.dart';

class ActivityTab extends ConsumerStatefulWidget {
  const ActivityTab({super.key});

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<ActivityTab> {
  bool _pendingExpanded = false;
  bool _friendsExpanded = false;
  bool _activityExpanded = true;

  Future<void> _accept(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('friendships').doc(docId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      ref.invalidate(pendingRequestsProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(activityFeedProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept request. Please try again.')),
        );
      }
    }
  }

  Future<void> _decline(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('friendships').doc(docId).delete();
      ref.invalidate(pendingRequestsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not decline request. Please try again.')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(friendsProvider);
    ref.invalidate(activityFeedProvider);
    await ref.read(activityFeedProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).value ?? [];
    final pending = ref.watch(pendingRequestsProvider).value ?? [];
    final items = ref.watch(activityFeedProvider).value ?? [];

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Pending requests (collapsible) ──
          if (pending.isNotEmpty) ...[
            _sectionHeader(
              'PENDING',
              count: pending.length,
              expanded: _pendingExpanded,
              onTap: () => setState(() => _pendingExpanded = !_pendingExpanded),
            ),
            if (_pendingExpanded) ...[
              const SizedBox(height: 6),
              ...pending.map((p) => _pendingCard(p)),
            ],
            const SizedBox(height: 8),
          ],

          // ── Your friends (collapsible) ──
          if (friends.isNotEmpty) ...[
            _sectionHeader(
              'YOUR FRIENDS',
              count: friends.length,
              expanded: _friendsExpanded,
              onTap: () => setState(() => _friendsExpanded = !_friendsExpanded),
            ),
            if (_friendsExpanded) ...[
              const SizedBox(height: 4),
              ...friends.map((f) => _friendRow(f)),
            ],
            const SizedBox(height: 12),
          ],

          // ── Recent activity (collapsible) ──
          if (items.isNotEmpty) ...[
            _sectionHeader(
              'RECENT ACTIVITY',
              expanded: _activityExpanded,
              onTap: () => setState(() => _activityExpanded = !_activityExpanded),
            ),
            if (_activityExpanded) ...[
              const SizedBox(height: 8),
              ...items.map((item) => _feedItem(item)),
            ],
          ],

          // ── Empty state ──
          if (items.isEmpty && pending.isEmpty && friends.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Add friends to see their activity here.',
                  style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  // ── Collapsible section header ──
  Widget _sectionHeader(String title, {int? count, required bool expanded, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          if (count != null && !expanded) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
          const Spacer(),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          ),
        ]),
      ),
    );
  }

  // ── Pending request card ──
  Widget _pendingCard(Friendship req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12), bottomRight: Radius.circular(12),
          topLeft: Radius.circular(4), bottomLeft: Radius.circular(4),
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Row(children: [
          Container(width: 3, height: 44, decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          AvatarWidget(photoUrl: req.initiatorPhotoUrl, initials: req.initiatorName.length >= 2 ? req.initiatorName.substring(0, 2).toUpperCase() : '??', size: 32),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(req.initiatorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('${req.initiatorShopsRanked} shops ranked', style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: () => _accept(req.id),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Accept', style: TextStyle(fontSize: 13)),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () => _decline(req.id),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Decline', style: TextStyle(fontSize: 13)),
            ),
          )),
        ]),
      ]),
    );
  }

  // ── Friend row → tap navigates to friend map ──
  Widget _friendRow(FriendProfile friend) {
    return GestureDetector(
      onTap: () => context.push('/friend-profile/${friend.uid}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
        child: Row(children: [
          AvatarWidget(photoUrl: friend.photoUrl, initials: friend.initials, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('${friend.shopsRanked} shops · ${friend.lastActiveLabel}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  // ── Feed item → tap navigates to shop profile ──
  Widget _feedItem(FeedItem item) {
    return GestureDetector(
      onTap: () {
        if (item.placeId != null) context.push('/shop/${item.placeId}');
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AvatarWidget(photoUrl: item.userPhotoUrl, initials: item.userInitials, size: 36, backgroundColor: item.avatarColor),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _feedText(item),
            if (item.photoUrl != null) ...[
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: item.photoUrl!, height: 100, width: double.infinity, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(height: 100, color: AppColors.border))),
            ],
            const SizedBox(height: 4),
            Text(item.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
        ]),
      ),
    );
  }

  Widget _feedText(FeedItem item) {
    switch (item.type) {
      case FeedType.drinkRated:
        return RichText(text: TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
          children: [
            TextSpan(text: item.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const TextSpan(text: ' rated '),
            TextSpan(text: item.drinkName, style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: ' at ${item.shopName} '),
            TextSpan(text: item.drinkScore?.toStringAsFixed(1) ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ));
      case FeedType.shopRanked:
        return Row(children: [
          Expanded(child: RichText(text: TextSpan(
            style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
            children: [
              TextSpan(text: item.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const TextSpan(text: ' ranked '),
              TextSpan(text: item.shopName, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ))),
          if (item.tier != null) TierBadge(tier: item.tier!, size: 20),
        ]);
      case FeedType.wantToTry:
        return RichText(text: TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
          children: [
            TextSpan(text: item.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const TextSpan(text: ' added '),
            TextSpan(text: item.shopName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const TextSpan(text: ' to '),
            const TextSpan(text: 'want to try', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.amber)),
          ],
        ));
    }
  }
}
