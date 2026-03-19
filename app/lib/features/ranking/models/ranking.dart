import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@immutable
class Ranking {
  final String placeId;
  final String tier;
  final String shopName;
  final String shopAddress;
  final double googleRating;
  final String? shopPhotoUrl;
  final LatLng coordinates;
  final List<DrinkRating> drinks;
  final double avgDrinkScore;
  final int drinkCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Ranking({
    required this.placeId,
    required this.tier,
    required this.shopName,
    required this.shopAddress,
    required this.googleRating,
    this.shopPhotoUrl,
    required this.coordinates,
    required this.drinks,
    required this.avgDrinkScore,
    required this.drinkCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ranking.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return Ranking(
      placeId: doc.id,
      tier: d['tier'] ?? 'C',
      shopName: d['shopName'] ?? '',
      shopAddress: d['shopAddress'] ?? '',
      googleRating: (d['googleRating'] ?? 0).toDouble(),
      shopPhotoUrl: d['shopPhotoUrl'],
      coordinates: LatLng(
        (d['coordinates']?['lat'] ?? 0).toDouble(),
        (d['coordinates']?['lng'] ?? 0).toDouble(),
      ),
      drinks: (d['drinks'] as List<dynamic>? ?? [])
          .map((drink) => DrinkRating.fromMap(drink as Map<String, dynamic>))
          .toList(),
      avgDrinkScore: (d['avgDrinkScore'] ?? 0).toDouble(),
      drinkCount: d['drinkCount'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'tier': tier,
    'shopName': shopName,
    'shopAddress': shopAddress,
    'googleRating': googleRating,
    'shopPhotoUrl': shopPhotoUrl,
    'coordinates': {'lat': coordinates.latitude, 'lng': coordinates.longitude},
    'drinks': drinks.map((d) => d.toMap()).toList(),
    'avgDrinkScore': avgDrinkScore,
    'drinkCount': drinkCount,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

@immutable
class DrinkRating {
  final String id;
  final String name;
  final double score;
  final String? price;
  final String? photoUrl;
  final String? thumbnailUrl;
  final String? notes;
  final DateTime createdAt;

  const DrinkRating({
    required this.id,
    required this.name,
    required this.score,
    this.price,
    this.photoUrl,
    this.thumbnailUrl,
    this.notes,
    required this.createdAt,
  });

  factory DrinkRating.fromMap(Map<String, dynamic> d) => DrinkRating(
    id: d['id'] ?? '',
    name: d['name'] ?? '',
    score: (d['score'] ?? 0).toDouble(),
    price: d['price'],
    photoUrl: d['photoUrl'],
    thumbnailUrl: d['thumbnailUrl'],
    notes: d['notes'],
    createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'score': score,
    'price': price,
    'photoUrl': photoUrl,
    'thumbnailUrl': thumbnailUrl,
    'notes': notes,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
