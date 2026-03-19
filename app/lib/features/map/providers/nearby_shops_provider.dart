import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:bobatier/features/map/models/boba_shop.dart';

final mapCenterProvider = StateProvider<LatLng>(
      (ref) => const LatLng(37.7749, -122.4194),
);

final nearbyShopsProvider = FutureProvider<List<NearbyShopPin>>((ref) async {
  final center = ref.watch(mapCenterProvider);
  final geohash = GeoHasher().encode(center.longitude, center.latitude, precision: 6);
  final db = FirebaseFirestore.instance;

  if (kDebugMode) debugPrint('[nearbyShops] center=${center.latitude},${center.longitude} geohash=$geohash');

  try {
    final cacheDoc = await db.collection('nearbyCache').doc(geohash).get();
    if (cacheDoc.exists) {
      final data = cacheDoc.data()!;
      final fetchedAt = (data['fetchedAt'] as Timestamp?)?.toDate();
      if (fetchedAt != null && DateTime.now().difference(fetchedAt).inHours < 24) {
        final shops = (data['shops'] as List<dynamic>)
            .map((s) => NearbyShopPin.fromMap(s as Map<String, dynamic>))
            .toList();
        if (kDebugMode) debugPrint('[nearbyShops] cache hit: ${shops.length} shops');
        return shops;
      }
      if (kDebugMode) debugPrint('[nearbyShops] cache stale, calling cloud function');
    } else {
      if (kDebugMode) debugPrint('[nearbyShops] cache miss, calling cloud function');
    }

    final callable = FirebaseFunctions.instance.httpsCallable('onNearbySearch');
    final result = await callable.call({
      'latitude': center.latitude,
      'longitude': center.longitude,
    });
    final shops = (result.data['shops'] as List<dynamic>)
        .map((s) => NearbyShopPin.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList();
    if (kDebugMode) debugPrint('[nearbyShops] cloud function returned: ${shops.length} shops');
    return shops;
  } catch (e) {
    if (kDebugMode) debugPrint('[nearbyShops] error: $e');
    rethrow;
  }
});
