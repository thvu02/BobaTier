import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bobatier/core/theme/app_theme.dart';
import 'package:bobatier/core/constants/firestore_paths.dart';
import 'package:bobatier/features/social/providers/social_provider.dart';
import 'package:bobatier/shared/avatar_widget.dart';

class _SearchResult {
  final String uid;
  final String name;
  final String username;
  final String? photoUrl;
  final int shops;
  const _SearchResult({
    required this.uid, required this.name, required this.username,
    this.photoUrl, required this.shops,
  });
}

class AddFriendsScreen extends ConsumerStatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  ConsumerState<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends ConsumerState<AddFriendsScreen> {
  final _controller = TextEditingController();
  List<_SearchResult> _results = [];
  bool _searching = false;
  final _sentRequests = <String>{};

  Future<void> _search(String query) async {
    if (query.length < 3) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final db = FirebaseFirestore.instance;
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (myUid == null) return;

      final snap = await db.collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(10)
          .get();

      final results = <_SearchResult>[];
      for (final doc in snap.docs) {
        if (doc.id == myUid) continue;
        final data = doc.data();
        results.add(_SearchResult(
          uid: doc.id,
          name: data['displayName'] ?? '',
          username: data['username'] ?? '',
          photoUrl: data['photoUrl'],
          shops: data['stats']?['shopsRanked'] ?? 0,
        ));
      }
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed. Check your connection and try again.')),
        );
      }
    }
  }

  Future<void> _sendRequest(String targetUid) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final db = FirebaseFirestore.instance;
      final id = FirestorePaths.friendshipId(uid, targetUid);
      final myProfile = await db.collection('users').doc(uid).get();
      final my = myProfile.data();
      if (my == null) return;

      await db.collection('friendships').doc(id).set({
        'uid1': uid.compareTo(targetUid) < 0 ? uid : targetUid,
        'uid2': uid.compareTo(targetUid) < 0 ? targetUid : uid,
        'status': 'pending',
        'initiatedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'initiatorName': my['displayName'],
        'initiatorUsername': my['username'],
        'initiatorPhotoUrl': my['photoUrl'],
        'initiatorStats': my['stats'],
      });
      if (mounted) setState(() => _sentRequests.add(targetUid));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send friend request. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).value ?? [];
    final pending = ref.watch(pendingRequestsProvider).value ?? [];
    final friendUids = friends.map((f) => f.uid).toSet();
    final pendingUids = pending.map((p) => p.initiatedBy).toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Add friends'), leading: const BackButton()),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onChanged: _search,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              decoration: InputDecoration(
                hintText: 'Search by username',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searching
                    ? const Padding(padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            if (_controller.text.length >= 3) ...[
              const SizedBox(height: 8),
              Text('Results for "${_controller.text}"',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Expanded(child: ListView(
                children: _results.map((r) => _resultCard(r, friendUids, pendingUids)).toList(),
              )),
            ] else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(_SearchResult r, Set<String> friendUids, Set<String> pendingUids) {
    final isSent = _sentRequests.contains(r.uid);
    final alreadyFriends = friendUids.contains(r.uid);
    final isPending = pendingUids.contains(r.uid) || isSent;
    final showAdded = alreadyFriends || isPending;
    final label = alreadyFriends ? 'Friends' : isPending ? 'Pending' : 'Add';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: showAdded ? AppColors.card.withValues(alpha: 0.5) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        AvatarWidget(photoUrl: r.photoUrl, initials: r.name.length >= 2 ? r.name.substring(0, 2) : '?', size: 40),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('@${r.username} · ${r.shops} shops',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        if (showAdded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          )
        else
          ElevatedButton(
            onPressed: () => _sendRequest(r.uid),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
            child: const Text('Add', style: TextStyle(fontSize: 13)),
          ),
      ]),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
