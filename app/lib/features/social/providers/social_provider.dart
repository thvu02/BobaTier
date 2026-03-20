import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bobatier/features/auth/providers/auth_provider.dart';
import 'package:bobatier/features/social/models/social_models.dart';
import 'package:bobatier/features/ranking/models/ranking.dart';
import 'package:flutter_riverpod/legacy.dart';

final _db = FirebaseFirestore.instance;

// ── Friends list (accepted only) ──

final friendsProvider = StreamProvider<List<FriendProfile>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value([]);

  final col = _db.collection('friendships');
  final stream1 = col
      .where('uid1', isEqualTo: uid)
      .where('status', isEqualTo: 'accepted')
      .snapshots();
  final stream2 = col
      .where('uid2', isEqualTo: uid)
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  return StreamZip([stream1, stream2]).asyncMap((snaps) async {
    final friendUids = <String>{};
    for (final doc in snaps[0].docs) {
      friendUids.add(doc.data()['uid2'] as String);
    }
    for (final doc in snaps[1].docs) {
      friendUids.add(doc.data()['uid1'] as String);
    }
    final profiles = <FriendProfile>[];
    for (final fuid in friendUids) {
      final doc = await _db.collection('users').doc(fuid).get();
      if (doc.exists) profiles.add(FriendProfile.fromFirestore(doc));
    }
    return profiles;
  });
});

// ── Pending friend requests (incoming) ──

final pendingRequestsProvider = StreamProvider<List<Friendship>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value([]);

  final col = _db.collection('friendships');
  final stream1 = col
      .where('uid1', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots();
  final stream2 = col
      .where('uid2', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  return StreamZip([stream1, stream2]).map((snaps) {
    final all = [
      ...snaps[0].docs.map((d) => Friendship.fromFirestore(d)),
      ...snaps[1].docs.map((d) => Friendship.fromFirestore(d)),
    ];
    return all.where((f) => f.initiatedBy != uid).toList();
  });
});

// ── Activity feed (recent rankings from friends) ──

final activityFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final friends = ref.watch(friendsProvider).value ?? [];
  final items = <FeedItem>[];
  final uid = ref.watch(currentUserProvider)?.uid;

  for (final friend in friends.take(10)) {
    final snap = await _db
        .collection('users').doc(friend.uid).collection('rankings')
        .orderBy('updatedAt', descending: true).limit(5).get();

    for (final doc in snap.docs) {
      final r = Ranking.fromFirestore(doc);
      items.add(FeedItem(
        id: '${friend.uid}_${r.placeId}',
        userId: friend.uid,
        userName: friend.displayName,
        userPhotoUrl: friend.photoUrl,
        userInitials: friend.initials,
        type: r.drinks.isNotEmpty ? FeedType.drinkRated : FeedType.shopRanked,
        shopName: r.shopName,
        placeId: r.placeId,
        drinkName: r.drinks.isNotEmpty ? r.drinks.last.name : null,
        drinkScore: r.drinks.isNotEmpty ? r.drinks.last.score : null,
        tier: r.tier,
        photoUrl: r.drinks.isNotEmpty ? r.drinks.last.thumbnailUrl : null,
        createdAt: r.updatedAt,
      ));
    }
  }

  // Query want-to-try items added by friends
  if (uid != null && friends.isNotEmpty) {
    final friendUids = friends.map((f) => f.uid).toList();
    final friendNameMap = {for (final f in friends) f.uid: f};
    final wttSnap = await _db.collection('wantToTry')
        .where('addedBy', whereIn: friendUids.take(10).toList())
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    for (final doc in wttSnap.docs) {
      final data = doc.data();
      final addedBy = data['addedBy'] as String? ?? '';
      final friend = friendNameMap[addedBy];
      if (friend == null) continue;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      items.add(FeedItem(
        id: 'wtt_${doc.id}',
        userId: friend.uid,
        userName: friend.displayName,
        userPhotoUrl: friend.photoUrl,
        userInitials: friend.initials,
        type: FeedType.wantToTry,
        shopName: data['shopName'] ?? '',
        placeId: data['placeId'] as String?,
        createdAt: createdAt,
      ));
    }
  }

  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items.take(20).toList();
});

// ── Want to try ──

final wantToTryProvider = StreamProvider<List<WantToTryItem>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value([]);

  return _db.collection('wantToTry')
      .where('users', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .asyncMap((snap) async {
    final items = <WantToTryItem>[];
    // Cache user lookups to avoid duplicate reads
    final nameCache = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final userIds = List<String>.from(data['users'] ?? []);
      final friendNames = <String, String>{};
      for (final u in userIds) {
        if (u == uid) continue;
        if (nameCache.containsKey(u)) {
          friendNames[u] = nameCache[u]!;
        } else {
          final userDoc = await _db.collection('users').doc(u).get();
          final name = userDoc.data()?['displayName'] ?? 'Unknown';
          nameCache[u] = name;
          friendNames[u] = name;
        }
      }
      items.add(WantToTryItem.fromFirestore(doc, friendNames));
    }
    return items;
  });
});

// ── Friend rankings (for viewing a friend's map) ──

final friendRankingsProvider = StreamProvider.family<List<Ranking>, String>((ref, friendUid) {
  return _db.collection('users').doc(friendUid).collection('rankings')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Ranking.fromFirestore(d)).toList());
});

final socialTabProvider = StateProvider<int>((ref) => 0);
