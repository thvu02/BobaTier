import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/map/models/boba_shop.dart';
import 'package:bobatier/features/map/providers/shop_detail_provider.dart';
import 'package:bobatier/features/ranking/providers/ranking_provider.dart';
import 'package:bobatier/features/ranking/widgets/tier_badge.dart';
import 'package:bobatier/features/social/providers/social_provider.dart';
import 'package:bobatier/features/social/models/social_models.dart';
import 'package:bobatier/shared/avatar_widget.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  final String placeId;
  const ShopProfileScreen({super.key, required this.placeId});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  bool _savingTier = false;
  bool _isOnWantToTry = false;
  String? _wantToTryDocId;

  @override
  void initState() {
    super.initState();
    _checkWantToTry();
  }

  Future<void> _checkWantToTry() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance.collection('wantToTry')
        .where('users', arrayContains: uid)
        .where('placeId', isEqualTo: widget.placeId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty && mounted) {
      setState(() {
        _isOnWantToTry = true;
        _wantToTryDocId = snap.docs.first.id;
      });
    }
  }

  Future<void> _toggleWantToTry(BobaShop shop) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      if (_isOnWantToTry && _wantToTryDocId != null) {
        await FirebaseFirestore.instance.collection('wantToTry').doc(_wantToTryDocId).delete();
        if (mounted) setState(() { _isOnWantToTry = false; _wantToTryDocId = null; });
      } else {
        final friends = ref.read(friendsProvider).value ?? [];
        final selectedFriends = await _showFriendPicker(friends);
        if (selectedFriends == null) return; // user cancelled
        final userList = [uid, ...selectedFriends];
        final docRef = await FirebaseFirestore.instance.collection('wantToTry').add({
          'users': userList,
          'addedBy': uid,
          'placeId': widget.placeId,
          'shopName': shop.name,
          'shopAddress': shop.address,
          'googleRating': shop.googleRating,
          'shopPhotoUrl': shop.photoUrl,
          'status': 'active',
          'visitedBy': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() { _isOnWantToTry = true; _wantToTryDocId = docRef.id; });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update want to try list.')),
        );
      }
    }
  }

  Future<Set<String>?> _showFriendPicker(List<FriendProfile> friends) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FriendPickerSheet(friends: friends),
    );
  }

  Future<void> _setTier(String tier) async {
    setState(() => _savingTier = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final rankRef = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('rankings').doc(widget.placeId);
      final doc = await rankRef.get();

      if (doc.exists) {
        await rankRef.update({
          'tier': tier,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final shopDoc = await FirebaseFirestore.instance
            .collection('shops').doc(widget.placeId).get();
        final shopData = shopDoc.data() ?? {};
        await rankRef.set({
          'tier': tier,
          'shopName': shopData['name'] ?? '',
          'shopAddress': shopData['address'] ?? '',
          'googleRating': shopData['googleRating'] ?? 0,
          'shopPhotoUrl': shopData['photoUrl'],
          'coordinates': shopData['coordinates'] ?? {'lat': 0, 'lng': 0},
          'drinks': [],
          'avgDrinkScore': 0,
          'drinkCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save tier. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingTier = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopDetailProvider(widget.placeId));
    final ranking = ref.watch(shopRankingProvider(widget.placeId));

    return shopAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $e'))),
      data: (shop) {
        if (shop == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Shop not found')));
        }
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 160, pinned: true,
                foregroundColor: Colors.white,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const BackButton(color: Colors.white),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(_isOnWantToTry ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
                        onPressed: () => _toggleWantToTry(shop),
                        tooltip: _isOnWantToTry ? 'Remove from want to try' : 'Add to want to try',
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (shop.photoUrl != null)
                        CachedNetworkImage(
                          imageUrl: shop.photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: AppColors.primary),
                        )
                      else
                        Container(color: AppColors.primary),
                      Container(decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                      ))),
                      Positioned(bottom: 12, left: 16, child: Row(children: [
                        Text('★' * shop.googleRating.round(), style: const TextStyle(color: AppColors.amber, fontSize: 13)),
                        const SizedBox(width: 4),
                        Text('${shop.googleRating} · ${shop.reviewCount} reviews', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(shop.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.dark)),
                          const SizedBox(height: 2),
                          Text(
                            shop.isOpenNow ? 'Open' : 'Closed',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: shop.isOpenNow ? AppColors.green : AppColors.red),
                          ),
                        ])),
                        if (ranking != null) TierBadge(tier: ranking.tier, size: 36),
                      ]),
                      const SizedBox(height: 12),
                      _shopDetails(context, shop),
                      const SizedBox(height: 16),
                      const Text('Shop tier', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      const SizedBox(height: 8),
                      _savingTier
                          ? const Center(child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            ))
                          : TierSelector(
                              selected: ranking?.tier,
                              onSelected: _setTier,
                            ),
                      if (ranking?.tier != null) ...[
                        const SizedBox(height: 4),
                        Text('Your rank: ${ranking!.tier} tier',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary)),
                      ],
                      if (ranking != null && ranking.drinks.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('MY DRINK RATINGS', style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 8),
                        ...ranking.drinks.map((d) => _drinkCard(context, d, widget.placeId)),
                      ],
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(child: ElevatedButton.icon(
                          onPressed: () => context.push('/rate/${widget.placeId}'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Rate a drink'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${shop.coordinates.latitude},${shop.coordinates.longitude}&destination_place_id=${shop.placeId}'),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text('Directions'),
                        )),
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        onPressed: () => _toggleWantToTry(shop),
                        icon: Icon(_isOnWantToTry ? Icons.bookmark : Icons.bookmark_border, size: 18),
                        label: Text(_isOnWantToTry ? 'On your want to try list' : 'Want to try'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _isOnWantToTry ? AppColors.primary : AppColors.border),
                          foregroundColor: _isOnWantToTry ? AppColors.primary : AppColors.text,
                        ),
                      )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _drinkCard(BuildContext context, dynamic drink, String placeId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.border),
          clipBehavior: Clip.antiAlias,
          child: (drink.thumbnailUrl ?? drink.photoUrl) != null
              ? CachedNetworkImage(imageUrl: drink.thumbnailUrl ?? drink.photoUrl!, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.local_cafe, color: AppColors.textSecondary))
              : const Icon(Icons.local_cafe, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(drink.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            Text(drink.score.toStringAsFixed(1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: drink.score / 10, backgroundColor: AppColors.border, color: AppColors.primary, minHeight: 4),
            )),
          ]),
          if (drink.price != null) ...[
            const SizedBox(height: 2),
            Text(drink.price!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ])),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          onPressed: () => context.push('/rate/$placeId?drinkId=${drink.id}'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ]),
    );
  }

  Widget _shopDetails(BuildContext context, BobaShop shop) {
    return Column(
      children: [
        _detailRow(
          context,
          icon: Icons.location_on_outlined,
          text: shop.address,
          onTap: () {
            Clipboard.setData(ClipboardData(text: shop.address));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Address copied'), duration: Duration(seconds: 2)),
            );
          },
        ),
        if (shop.website != null)
          _detailRow(
            context,
            icon: Icons.language,
            text: shop.website!,
            isLink: true,
            onTap: () => launchUrl(Uri.parse(shop.website!), mode: LaunchMode.externalApplication),
          ),
        if (shop.phoneNumber != null)
          _detailRow(
            context,
            icon: Icons.phone_outlined,
            text: shop.phoneNumber!,
            onTap: () => launchUrl(Uri.parse('tel:${shop.phoneNumber}')),
          ),
        if (shop.weekdayText.isNotEmpty)
          _detailRow(
            context,
            icon: Icons.schedule,
            text: _todayHours(shop) ?? 'Hours unavailable',
          ),
      ],
    );
  }

  Widget _detailRow(BuildContext context, {required IconData icon, required String text, bool isLink = false, VoidCallback? onTap}) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isLink ? AppColors.primary : AppColors.text,
                decoration: isLink ? TextDecoration.underline : null,
                decorationColor: isLink ? AppColors.primary : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (onTap != null) return GestureDetector(onTap: onTap, child: child);
    return child;
  }

  String? _todayHours(BobaShop shop) {
    if (shop.weekdayText.isEmpty) return null;
    final dayIndex = DateTime.now().weekday % 7;
    final textIndex = (dayIndex == 0) ? 6 : dayIndex - 1;
    if (textIndex >= shop.weekdayText.length) return null;
    return shop.weekdayText[textIndex];
  }
}

class _FriendPickerSheet extends StatefulWidget {
  final List<FriendProfile> friends;
  const _FriendPickerSheet({required this.friends});

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppColors.border, borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(height: 12),
        const Text('Invite friends (optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (widget.friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Add friends to invite them to try shops together.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.friends.length,
              itemBuilder: (_, i) {
                final f = widget.friends[i];
                final selected = _selected.contains(f.uid);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: AvatarWidget(
                      photoUrl: f.photoUrl, initials: f.initials, size: 36),
                  title: Text(f.displayName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  onTap: () => setState(() {
                    if (selected) {
                      _selected.remove(f.uid);
                    } else {
                      _selected.add(f.uid);
                    }
                  }),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: Text(_selected.isEmpty
                ? 'Add to my list'
                : 'Add & invite ${_selected.length} friend${_selected.length > 1 ? 's' : ''}'),
          ),
        ),
      ]),
    );
  }
}
