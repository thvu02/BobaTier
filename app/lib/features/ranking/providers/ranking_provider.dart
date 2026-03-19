import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bobatier/features/ranking/models/ranking.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final myRankingsProvider = StreamProvider<List<Ranking>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users').doc(uid).collection('rankings')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Ranking.fromFirestore(d)).toList());
});

final rankingsByTierProvider = Provider<Map<String, List<Ranking>>>((ref) {
  final rankings = ref.watch(myRankingsProvider).value ?? [];
  final map = <String, List<Ranking>>{};
  for (final tier in ['S', 'A', 'B', 'C', 'D', 'F']) {
    final items = rankings.where((r) => r.tier == tier).toList();
    if (items.isNotEmpty) map[tier] = items;
  }
  return map;
});

final shopRankingProvider = Provider.family<Ranking?, String>((ref, placeId) {
  final rankings = ref.watch(myRankingsProvider).value ?? [];
  try {
    return rankings.firstWhere((r) => r.placeId == placeId);
  } catch (_) {
    return null;
  }
});

final selectedRankingProvider = StateProvider<Ranking?>((ref) => null);
