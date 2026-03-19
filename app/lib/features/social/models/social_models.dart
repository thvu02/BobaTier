import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@immutable
class Friendship {
  final String id;
  final String uid1;
  final String uid2;
  final String status; // 'pending' | 'accepted'
  final String initiatedBy;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String initiatorName;
  final String initiatorUsername;
  final String? initiatorPhotoUrl;
  final int initiatorShopsRanked;

  const Friendship({
    required this.id,
    required this.uid1,
    required this.uid2,
    required this.status,
    required this.initiatedBy,
    required this.createdAt,
    this.acceptedAt,
    required this.initiatorName,
    required this.initiatorUsername,
    this.initiatorPhotoUrl,
    required this.initiatorShopsRanked,
  });

  factory Friendship.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return Friendship(
      id: doc.id,
      uid1: d['uid1'] ?? '',
      uid2: d['uid2'] ?? '',
      status: d['status'] ?? 'pending',
      initiatedBy: d['initiatedBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (d['acceptedAt'] as Timestamp?)?.toDate(),
      initiatorName: d['initiatorName'] ?? '',
      initiatorUsername: d['initiatorUsername'] ?? '',
      initiatorPhotoUrl: d['initiatorPhotoUrl'],
      initiatorShopsRanked: d['initiatorStats']?['shopsRanked'] ?? 0,
    );
  }

  bool get isPending => status == 'pending';
}

@immutable
class FriendProfile {
  final String uid;
  final String displayName;
  final String username;
  final String? photoUrl;
  final int shopsRanked;
  final int drinksRated;
  final double avgScore;
  final String mostCommonTier;
  final DateTime lastActiveAt;

  const FriendProfile({
    required this.uid,
    required this.displayName,
    required this.username,
    this.photoUrl,
    required this.shopsRanked,
    required this.drinksRated,
    this.avgScore = 0,
    this.mostCommonTier = 'S',
    required this.lastActiveAt,
  });

  factory FriendProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return FriendProfile(
      uid: doc.id,
      displayName: d['displayName'] ?? '',
      username: d['username'] ?? '',
      photoUrl: d['photoUrl'],
      shopsRanked: d['stats']?['shopsRanked'] ?? 0,
      drinksRated: d['stats']?['drinksRated'] ?? 0,
      avgScore: (d['stats']?['avgScore'] ?? 0).toDouble(),
      mostCommonTier: d['stats']?['mostCommonTier'] ?? 'S',
      lastActiveAt: (d['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get initials {
    if (displayName.isEmpty) return '??';
    final parts = displayName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (displayName.length >= 2) return displayName.substring(0, 2).toUpperCase();
    return displayName[0].toUpperCase();
  }

  String get lastActiveLabel {
    final diff = DateTime.now().difference(lastActiveAt);
    if (diff.inHours < 24) return 'Active today';
    if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
    return 'Active ${(diff.inDays / 7).floor()}w ago';
  }
}

@immutable
class WantToTryItem {
  final String id;
  final List<String> users;
  final String addedBy;
  final String placeId;
  final String shopName;
  final String shopAddress;
  final double googleRating;
  final String? shopPhotoUrl;
  final String status; // 'active' | 'visited' (legacy)
  final List<String> visitedBy; // UIDs who marked visited
  final DateTime createdAt;
  final DateTime? visitedAt;
  final Map<String, String> friendNames; // uid -> displayName

  const WantToTryItem({
    required this.id,
    required this.users,
    required this.addedBy,
    required this.placeId,
    required this.shopName,
    required this.shopAddress,
    required this.googleRating,
    this.shopPhotoUrl,
    required this.status,
    this.visitedBy = const [],
    required this.createdAt,
    this.visitedAt,
    this.friendNames = const {},
  });

  factory WantToTryItem.fromFirestore(DocumentSnapshot doc, Map<String, String> friendNames) {
    final d = doc.data()! as Map<String, dynamic>;
    return WantToTryItem(
      id: doc.id,
      users: List<String>.from(d['users'] ?? []),
      addedBy: d['addedBy'] ?? '',
      placeId: d['placeId'] ?? '',
      shopName: d['shopName'] ?? '',
      shopAddress: d['shopAddress'] ?? '',
      googleRating: (d['googleRating'] ?? 0).toDouble(),
      shopPhotoUrl: d['shopPhotoUrl'],
      status: d['status'] ?? 'active',
      visitedBy: List<String>.from(d['visitedBy'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      visitedAt: (d['visitedAt'] as Timestamp?)?.toDate(),
      friendNames: friendNames,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'users': users,
    'addedBy': addedBy,
    'placeId': placeId,
    'shopName': shopName,
    'shopAddress': shopAddress,
    'googleRating': googleRating,
    'shopPhotoUrl': shopPhotoUrl,
    'status': status,
    'visitedBy': visitedBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'visitedAt': visitedAt != null ? Timestamp.fromDate(visitedAt!) : null,
  };

  bool isVisitedBy(String uid) => visitedBy.contains(uid);
  bool get isVisited => status == 'visited'; // legacy compat

  /// Other users on this item (excluding the given uid)
  List<String> otherUsers(String uid) => users.where((u) => u != uid).toList();

  /// Display name for the friend(s) on this item
  String friendLabel(String uid) {
    final others = otherUsers(uid);
    if (others.isEmpty) return 'just you';
    final names = others.map((u) => friendNames[u] ?? 'Unknown').toList();
    if (names.length == 1) return 'with ${names.first}';
    return 'with ${names.take(2).join(', ')}${names.length > 2 ? ' +${names.length - 2}' : ''}';
  }
}

@immutable
class FeedItem {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String userInitials;
  final Color? avatarColor;
  final FeedType type;
  final String shopName;
  final String? placeId;
  final String? drinkName;
  final double? drinkScore;
  final String? tier;
  final String? photoUrl;
  final DateTime createdAt;

  const FeedItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.userInitials,
    this.avatarColor,
    required this.type,
    required this.shopName,
    this.placeId,
    this.drinkName,
    this.drinkScore,
    this.tier,
    this.photoUrl,
    required this.createdAt,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

enum FeedType { drinkRated, shopRanked, wantToTry }
