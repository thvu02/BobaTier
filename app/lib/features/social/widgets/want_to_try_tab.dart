import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/features/social/providers/social_provider.dart';
import 'package:bobatier/features/social/models/social_models.dart';
import 'package:bobatier/shared/avatar_widget.dart';

class WantToTryTab extends ConsumerStatefulWidget {
  const WantToTryTab({super.key});

  @override
  ConsumerState<WantToTryTab> createState() => _WantToTryTabState();
}

class _WantToTryTabState extends ConsumerState<WantToTryTab> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _toggleVisited(WantToTryItem item) async {
    final visited = item.isVisitedBy(_uid);
    try {
      await FirebaseFirestore.instance.collection('wantToTry').doc(item.id).update({
        'visitedBy': visited
            ? FieldValue.arrayRemove([_uid])
            : FieldValue.arrayUnion([_uid]),
      });
      ref.invalidate(wantToTryProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update. Please try again.')),
        );
      }
    }
  }

  Future<void> _removeFromMyList(String docId, List<String> users) async {
    try {
      if (users.length <= 1) {
        // Last user — delete the doc entirely
        await FirebaseFirestore.instance.collection('wantToTry').doc(docId).delete();
      } else {
        // Remove only this user from the array
        await FirebaseFirestore.instance.collection('wantToTry').doc(docId).update({
          'users': FieldValue.arrayRemove([_uid]),
          'visitedBy': FieldValue.arrayRemove([_uid]),
        });
      }
      ref.invalidate(wantToTryProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove. Please try again.')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(wantToTryProvider);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _showAddShopModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddShopSheet(
        onAdded: () => ref.invalidate(wantToTryProvider),
        friends: ref.read(friendsProvider).value ?? [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(wantToTryProvider).value ?? [];
    final active = items.where((i) => !i.isVisitedBy(_uid)).toList();
    final visited = items.where((i) => i.isVisitedBy(_uid)).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...active.map((item) => _itemCard(item)),
          if (visited.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('VISITED', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            ...visited.map((item) => _itemCard(item)),
          ],
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No places on your want to try list yet.',
                  style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _showAddShopModal,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add a shop'),
          )),
        ],
      ),
    );
  }

  Widget _itemCard(WantToTryItem item) {
    final visited = item.isVisitedBy(_uid);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove from list?'),
            content: Text(item.users.length > 1
                ? 'This will only remove it from your list. Others will still see it.'
                : 'This will delete the item.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _removeFromMyList(item.id, item.users),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.red),
      ),
      child: GestureDetector(
        onTap: () => context.push('/shop/${item.placeId}'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: visited ? AppColors.card.withValues(alpha: 0.5) : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.border),
              clipBehavior: Clip.antiAlias,
              child: item.shopPhotoUrl != null
                  ? CachedNetworkImage(imageUrl: item.shopPhotoUrl!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.local_cafe, color: AppColors.textSecondary, size: 24))
                  : const Icon(Icons.local_cafe, color: AppColors.textSecondary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.shopName, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark,
                decoration: visited ? TextDecoration.lineThrough : null,
              )),
              const SizedBox(height: 2),
              Text('★ ${item.googleRating} · ${item.shopAddress.split(",").first}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(
                item.friendLabel(_uid),
                style: const TextStyle(fontSize: 11, color: AppColors.primary),
              ),
            ])),
            GestureDetector(
              onTap: () => _toggleVisited(item),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visited ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: visited ? AppColors.primary : AppColors.border, width: 1.5),
                ),
                child: visited ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Add shop search + friend picker bottom sheet ──

class _AddShopSheet extends StatefulWidget {
  final VoidCallback onAdded;
  final List<FriendProfile> friends;
  const _AddShopSheet({required this.onAdded, required this.friends});

  @override
  State<_AddShopSheet> createState() => _AddShopSheetState();
}

class _AddShopSheetState extends State<_AddShopSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _allShops = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  // Selected shop and friend picker state
  Map<String, dynamic>? _selectedShop;
  final Set<String> _selectedFriends = {};

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('shops')
          .orderBy('name')
          .limit(100)
          .get();
      setState(() {
        _allShops = snap.docs.map((d) {
          final data = d.data();
          data['placeId'] = d.id;
          return data;
        }).toList();
        _filtered = _allShops;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterShops(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = _allShops);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filtered = _allShops.where((s) =>
          (s['name'] as String? ?? '').toLowerCase().contains(q) ||
          (s['address'] as String? ?? '').toLowerCase().contains(q)
      ).toList();
    });
  }

  Future<void> _addShop() async {
    final shop = _selectedShop;
    if (shop == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userList = [uid, ..._selectedFriends];
      await FirebaseFirestore.instance.collection('wantToTry').add({
        'users': userList,
        'addedBy': uid,
        'placeId': shop['placeId'],
        'shopName': shop['name'] ?? '',
        'shopAddress': shop['address'] ?? '',
        'googleRating': shop['googleRating'] ?? 0,
        'shopPhotoUrl': shop['photoUrl'],
        'status': 'active',
        'visitedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add shop. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.border, borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(height: 12),
          Text(
            _selectedShop == null ? 'Add a shop' : 'Invite friends',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // ── Step 1: Shop search ──
          if (_selectedShop == null) ...[
            TextField(
              controller: _controller,
              onChanged: _filterShops,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by shop name',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
            else
              Expanded(child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final shop = _filtered[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Container(width: 40, height: 40,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.border),
                        child: const Icon(Icons.local_cafe, color: AppColors.textSecondary, size: 20)),
                    title: Text(shop['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('★ ${shop['googleRating'] ?? 0} · ${(shop['address'] ?? '').toString().split(',').first}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                    onTap: () => setState(() => _selectedShop = shop),
                  );
                },
              )),
          ],

          // ── Step 2: Friend picker ──
          if (_selectedShop != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.card, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Row(children: [
                const Icon(Icons.local_cafe, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_selectedShop!['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                GestureDetector(
                  onTap: () => setState(() { _selectedShop = null; _selectedFriends.clear(); }),
                  child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Invite friends (optional)', style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(height: 6),
            Expanded(child: widget.friends.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Add friends to invite them to try shops together.',
                      style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: widget.friends.length,
                  itemBuilder: (_, i) {
                    final f = widget.friends[i];
                    final selected = _selectedFriends.contains(f.uid);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: AvatarWidget(photoUrl: f.photoUrl, initials: f.initials, size: 36),
                      title: Text(f.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      trailing: Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                      onTap: () => setState(() {
                        if (selected) { _selectedFriends.remove(f.uid); }
                        else { _selectedFriends.add(f.uid); }
                      }),
                    );
                  },
                ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
              child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: _addShop,
                child: Text(_selectedFriends.isEmpty ? 'Add to my list' : 'Add & invite ${_selectedFriends.length} friend${_selectedFriends.length > 1 ? 's' : ''}'),
              )),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
