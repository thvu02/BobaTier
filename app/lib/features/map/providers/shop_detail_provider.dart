import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bobatier/features/map/models/boba_shop.dart';

final shopDetailProvider = StreamProvider.family<BobaShop?, String>((ref, placeId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(placeId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return BobaShop.fromFirestore(doc);
  });
});
