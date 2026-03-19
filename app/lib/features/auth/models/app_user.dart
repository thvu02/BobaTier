import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@immutable
class AppUser {
  final String uid;
  final String displayName;
  final String username;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final UserStats stats;
  final NotificationPrefs notifications;

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.email,
    this.photoUrl,
    required this.createdAt,
    required this.stats,
    required this.notifications,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      displayName: d['displayName'] ?? '',
      username: d['username'] ?? '',
      email: d['email'] ?? '',
      photoUrl: d['photoUrl'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stats: UserStats(
        shopsRanked: d['stats']?['shopsRanked'] ?? 0,
        drinksRated: d['stats']?['drinksRated'] ?? 0,
        avgScore: (d['stats']?['avgScore'] ?? 0).toDouble(),
        mostCommonTier: d['stats']?['mostCommonTier'] ?? 'S',
      ),
      notifications: NotificationPrefs(
        friendActivity: d['notifications']?['friendActivity'] ?? true,
        wantToTryReminders: d['notifications']?['wantToTryReminders'] ?? true,
        newShopNearby: d['notifications']?['newShopNearby'] ?? false,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'displayName': displayName,
    'username': username,
    'email': email,
    'photoUrl': photoUrl,
    'createdAt': Timestamp.fromDate(createdAt),
    'stats': {
      'shopsRanked': stats.shopsRanked,
      'drinksRated': stats.drinksRated,
      'avgScore': stats.avgScore,
      'mostCommonTier': stats.mostCommonTier,
    },
    'notifications': {
      'friendActivity': notifications.friendActivity,
      'wantToTryReminders': notifications.wantToTryReminders,
      'newShopNearby': notifications.newShopNearby,
    },
  };

  String get initials {
    if (displayName.isEmpty) return '??';
    final parts = displayName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (displayName.length >= 2) return displayName.substring(0, 2).toUpperCase();
    return displayName[0].toUpperCase();
  }
}

@immutable
class UserStats {
  final int shopsRanked;
  final int drinksRated;
  final double avgScore;
  final String mostCommonTier;

  const UserStats({
    this.shopsRanked = 0,
    this.drinksRated = 0,
    this.avgScore = 0,
    this.mostCommonTier = 'S',
  });
}

@immutable
class NotificationPrefs {
  final bool friendActivity;
  final bool wantToTryReminders;
  final bool newShopNearby;

  const NotificationPrefs({
    this.friendActivity = true,
    this.wantToTryReminders = true,
    this.newShopNearby = false,
  });
}
